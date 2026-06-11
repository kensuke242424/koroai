// 追加シート（刷新版・2ステップ）。プロトタイプ FKAddSheet の移植。
//
// native .sheet は使わず SheetContainer(0.88・extendContentUnderHomeIndicator) 内に組む。
// 幅 2倍の HStack トラックを offset x で 0 ⇄ −画面幅 にずらして「選ぶ」⇄「確認・編集」を横プッシュする。
// 閉じる確認は全画面に重ねるトップモーダル。文言はプロトタイプ / ADD_FLOW.md から一字一句転記。
//
// セクション分け（確定仕様）は AddGroups。グループ外カテゴリは自動で「その他」。

import SwiftUI
import SwiftData

// MARK: - 追加フローのカテゴリセクション

/// 追加フローのカテゴリセクション。出典: fk-flows.jsx FK_ADD_GROUPS。
struct AddGroup: Identifiable {
    let key: String
    let label: String
    let ids: [String]
    var id: String { key }
}

enum AddGroups {
    static let base: [AddGroup] = [
        AddGroup(key: "meat", label: "肉・魚介", ids: ["fish", "chicken", "meat"]),
        AddGroup(key: "veg", label: "野菜・きのこ", ids: ["leafy", "veg", "mush"]),
        AddGroup(key: "fruit", label: "果物・乳製品", ids: ["fruit", "dairy"]),
        AddGroup(key: "soy", label: "大豆製品・卵", ids: ["tofu", "egg"]),
        AddGroup(key: "staple", label: "主食・惣菜", ids: ["bread", "deli"]),
    ]

    /// 全カテゴリのうちグループ外があれば「その他」を末尾に補う。
    static var resolved: [AddGroup] {
        let grouped = Set(base.flatMap(\.ids))
        let extras = FoodCategory.all.map(\.id).filter { !grouped.contains($0) }
        if extras.isEmpty { return base }
        return base + [AddGroup(key: "other", label: "その他", ids: extras)]
    }
}

// MARK: - AddSheet

struct AddSheet: View {
    @Binding var isPresented: Bool

    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.modelContext) private var context

    @State private var model = AddFlowModel()
    /// シートの detent（中⇄大）。初期は中、確認画面へ進むと自動で大（参照HTML準拠）。
    @State private var detent: SheetDetent = .medium
    /// チップ行の段階出現用。CTA エリアのせり出し完了後に true にする（ユーザー指定の順序）。
    @State private var chipRowShown = false

    private var copy: ToneCopy { store.tone.copy }

    var body: some View {
        ZStack {
            SheetContainer(
                isPresented: $isPresented,
                detentFractions: (medium: 0.68, large: 1.0), // 中68%⇄大は最大（セーフエリア上端）まで
                detent: $detent,
                extendContentUnderHomeIndicator: true, // 下部トレイを画面下端まで敷く（デザイン準拠）
                onDismissRequest: { handleDismiss() }
            ) {
                track
            }

            // 閉じる確認は「トップモーダル」なので、シートの内側ではなく全画面に重ねる。
            confirmCloseOverlay
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                initPresentation()
            } else {
                didInitPresentation = false
                chipRowShown = false
            }
        }
        .onChange(of: model.cartCount) { old, new in
            if old == 0, new > 0 {
                // CTA エリアのせり出し（トレイ挿入アニメ）が終わってからチップ行を出す（ユーザー指定の順序）。
                chipRowShown = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        chipRowShown = true
                    }
                }
            } else if new == 0 {
                chipRowShown = false
            }
        }
        .onChange(of: model.screen) { _, screen in
            // 確認画面へ進むと自動で大 detent（参照HTML準拠）。
            if screen == .confirm {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    detent = .large
                }
            }
        }
        .onAppear {
            if isPresented { initPresentation() }
        }
    }

    /// 表示開始時の初期化。onAppear と onChange の両方から呼ばれうるため
    /// didInitPresentation で1回にガードする（reset の二重実行でカゴが消えるのを防ぐ）。
    @State private var didInitPresentation = false
    @State private var selectScrollY: CGFloat = 0

    private func initPresentation() {
        guard !didInitPresentation else { return }
        didInitPresentation = true
        model.reset(store: store)
        detent = .medium
        chipRowShown = false
        selectScrollY = 0
        #if DEBUG
        applyLaunchHook()
        #endif
    }

    #if DEBUG
    /// -openAddConfirm で fish×2・dairy×1 をカゴに積んで確認画面を初期表示する（スクショ用）。
    /// -autoAddOne <catId> は表示 1.2 秒後にタイルタップと同じ経路（addOneAnimated）で
    /// 1件追加する（トレイ出現アニメーションの録画検証用）。
    /// 二重実行は initPresentation 側でガード済み。
    private func applyLaunchHook() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-autoAddOne"), i + 1 < args.count,
           let cat = FoodCategory.find(args[i + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                addOneAnimated(cat)
            }
        }
        if args.contains("-openAddConfirm") {
            if let fish = FoodCategory.find("fish") {
                model.addOne(category: fish, store: store)
                model.addOne(category: fish, store: store)
            }
            if let dairy = FoodCategory.find("dairy") {
                model.addOne(category: dairy, store: store)
            }
            model.screen = .confirm
        }
        if args.contains("-openCloseConfirm") {
            if let fish = FoodCategory.find("fish") {
                model.addOne(category: fish, store: store)
                model.addOne(category: fish, store: store)
            }
            if let dairy = FoodCategory.find("dairy") {
                model.addOne(category: dairy, store: store)
            }
            model.confirmClose = true
        }
    }
    #endif

    // MARK: - 横プッシュトラック

    /// 幅 2倍の HStack を offset x でずらして 2画面を横プッシュする。
    private var track: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                selectScreen
                    .frame(width: w)
                confirmScreen
                    .frame(width: w)
            }
            .frame(width: w * 2, alignment: .leading)
            .offset(x: model.screen == .confirm ? -w : 0)
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: model.screen)
        }
    }

    // MARK: - 画面1：選ぶ

    private var selectScreen: some View {
        VStack(spacing: 0) {
            categoryGrid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // タイトル＋説明が両方スクロールで隠れたら、インラインタイトルをフェードイン
        // （確認画面のナビと同じ見た目。表示領域を最大化するため常設バーにしない）。
        .overlay(alignment: .top) {
            selectInlineBar
        }
        // 下部トレイ（チップ＋CTA）は1品以上選択されたときだけ、下からせり出す（ユーザー指定）。
        .overlay(alignment: .bottom) {
            if model.cartCount > 0 {
                selectTray
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// タイトル＋説明。スクロール内容に含めて、上にスクロールすると隠れる。
    private var selectHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(copy.addTitle)
                .font(AppFont.rounded(size: 22, weight: .heavy))
                .foregroundStyle(tokens.text)
            Text("カテゴリを選んでカゴへ。最後にまとめて確認します。")
                .font(AppFont.rounded(size: 13.5, weight: .semibold))
                .foregroundStyle(tokens.textSec)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // ヘッダー（タイトル＋説明 ≈70pt）が隠れきるあたりでインラインタイトルを入れる。
    private var inlineTitleProgress: CGFloat { clamp01((selectScrollY - 56) / 22) }

    private var selectInlineBar: some View {
        Text("たべものを追加")
            .font(AppFont.rounded(size: 16, weight: .heavy))
            .foregroundStyle(tokens.text)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background {
                tokens.bg2
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(tokens.hair).frame(height: 1)
                    }
            }
            .opacity(Double(inlineTitleProgress))
            .allowsHitTesting(false)
    }

    private var categoryGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // スクロール量をオフセットで取得（iOS 17 互換 PreferenceKey）
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geo.frame(in: .named("addSelectScroll")).minY
                    )
                }
                .frame(height: 0)

                VStack(spacing: 0) {
                    selectHeader
                    VStack(spacing: 0) {
                        ForEach(AddGroups.resolved) { g in
                            sectionHeader(g.label)
                            tileGrid(g.ids)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
                    .id("addSelectScrollTarget") // -scrollAddSelect 検証フックのスクロール先
                }
                // 下部トレイに隠れない余白（チップ行＋CTA 分）。
                .padding(.bottom, 132)
            }
            .coordinateSpace(name: "addSelectScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { y in
                // iOS 17 用フォールバック。iOS 18+ は onScrollGeometryChange（下の modifier）で取得する。
                if #unavailable(iOS 18.0) {
                    if abs(selectScrollY - y) > 1 { selectScrollY = y }
                }
            }
            .modifier(ScrollOffsetObserver(scrollY: $selectScrollY))
            .frame(maxHeight: .infinity)
            #if DEBUG
            .onAppear {
                // スクショ用: -scrollAddSelect でタイトル＋説明が隠れるまでスクロールした状態にする。
                guard CommandLine.arguments.contains("-scrollAddSelect") else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { proxy.scrollTo("addSelectScrollTarget", anchor: .top) }
                }
            }
            #endif
        }
    }

    private func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }

    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppFont.rounded(size: 12.5, weight: .heavy))
                .foregroundStyle(tokens.brandInk)
            Rectangle()
                .fill(tokens.hair)
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
        .padding(.top, 14)
        .padding(.bottom, 9)
    }

    private func tileGrid(_ ids: [String]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 11), count: 3)
        return LazyVGrid(columns: columns, spacing: 11) {
            ForEach(ids, id: \.self) { id in
                if let cat = FoodCategory.find(id) {
                    categoryTile(cat)
                }
            }
        }
    }

    /// タイルタップでカゴに1件追加する。トレイの出現・チップ挿入・バッジ変化が
    /// すべてアニメーションするよう、変異は必ず withAnimation で包む
    /// （.animation(value:) 直付けだけではトレイ高さの変化を取りこぼす）。
    private func addOneAnimated(_ cat: FoodCategory) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            model.addOne(category: cat, store: store)
        }
    }

    private func categoryTile(_ cat: FoodCategory) -> some View {
        let count = model.countOf(catId: cat.id)
        let active = count > 0
        return Button {
            addOneAnimated(cat)
        } label: {
            VStack(spacing: 9) {
                CategoryIcon(category: cat, size: 52)
                Text(cat.name)
                    .font(AppFont.rounded(size: 14, weight: .bold))
                    .foregroundStyle(tokens.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.horizontal, 8)
            .padding(.bottom, 13)
            .background(
                active
                    ? mixOKLab(cat.color, tokens.surface, fractionOfFirst: 0.14)
                    : tokens.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(active ? cat.color : .clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                tileBadge(cat: cat, count: count)
                    .padding(7)
            }
            .shadow(color: tokens.shadow, radius: 1.5, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tileBadge(cat: FoodCategory, count: Int) -> some View {
        if count > 0 {
            Text("\(count)")
                .font(AppFont.rounded(size: 12.5, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 21, minHeight: 21)
                .background(cat.color, in: Capsule())
                // count 変化でポップ。
                .id(count)
                .transition(.scale.combined(with: .opacity))
        } else {
            Text("＋")
                .font(AppFont.rounded(size: 16, weight: .bold))
                .foregroundStyle(tokens.textTer)
                .frame(width: 21, height: 21)
                .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.07), in: Circle())
        }
    }

    // MARK: - 選ぶ画面・下部トレイ（チップ行＋CTA）

    private var selectTray: some View {
        let groups = model.grouped
        let n = model.cartCount
        let showChips = chipRowShown && !groups.isEmpty
        return VStack(spacing: 0) {
            if showChips {
                chipRow(groups)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            // 「確認する（N品）」CTA。
            Button {
                if n > 0 {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        model.screen = .confirm
                    }
                }
            } label: {
                Text(n > 0 ? "確認する（\(n)品）" : "確認する")
                    .font(AppFont.rounded(size: 16, weight: .heavy))
                    .foregroundStyle(n > 0 ? .white : tokens.textTer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(n > 0 ? tokens.accent : tokens.surface2,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: n > 0 ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.35) : .clear,
                            radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(n == 0)
            .padding(.horizontal, 18)
            .padding(.top, showChips ? 0 : 12)
        }
        // 押しやすさのため、下部に適度な余白を確保する（ユーザー指定）。
        .padding(.bottom, 26)
        // チップ行の出現/消滅でトレイ高さが滑らかに変わるように。
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: showChips)
        .background {
            // surface2 地・上角丸18・上 hairline・上向き淡影（0 -3 14 rgba(80,65,40,0.07)）。
            UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 18,
                style: .continuous
            )
            .fill(tokens.surface2)
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.07),
                    radius: 7, x: 0, y: -3)
            .background(alignment: .bottom) {
                // 競り上がりバウンドのオーバーシュート中に下へ隙間が見えないよう、
                // トレイ下端のさらに下へ surface2 を 120pt 余分に敷いておく（ブリード）。
                Rectangle()
                    .fill(tokens.surface2)
                    .frame(height: 120)
                    .offset(y: 120)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(tokens.hair).frame(height: 1)
        }
    }

    private func chipRow(_ groups: [AddFlowModel.CartGroup]) -> some View {
        HStack(spacing: 8) {
            // 🧺 の代用: SF "basket"（絵文字禁止）。左に固定。
            Image(systemName: "basket")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tokens.textSec)
                .frame(width: 24, height: 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(groups) { g in
                        chip(g)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        // チップ出現はポップイン（最新が先頭＝追加順降順）。
        .animation(.spring(response: 0.36, dampingFraction: 0.7), value: model.cartCount)
    }

    @ViewBuilder
    private func chip(_ g: AddFlowModel.CartGroup) -> some View {
        if let cat = FoodCategory.find(g.catId) {
            HStack(spacing: 5) {
                // カテゴリ色丸カウント 17pt 白字 fs10.5 w800（count 変化でポップ）。
                Text("\(g.count)")
                    .font(AppFont.rounded(size: 10.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 17, minHeight: 17)
                    .background(cat.color, in: Circle())
                    .id(g.count)
                    .transition(.scale.combined(with: .opacity))
                Text(cat.name)
                    .font(AppFont.rounded(size: 12, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .fixedSize()
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) {
                        model.removeLastOfCategory(g.catId)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                        .frame(width: 17, height: 17)
                        .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(cat.name) を1つ取り消し")
            }
            .padding(.leading, 5)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(tokens.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(mixWithTransparent(cat.color, fractionOfFirst: 0.33), lineWidth: 1)
            )
            .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.10),
                    radius: 1, x: 0, y: 1)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - 画面2：確認・編集

    private var confirmScreen: some View {
        VStack(spacing: 0) {
            confirmHeader
            confirmSub
            confirmList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            confirmTray
        }
    }

    private var confirmHeader: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    model.screen = .select
                }
            } label: {
                Text("‹ 選び直す")
                    .font(AppFont.rounded(size: 14.5, weight: .heavy))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(tokens.accent)
                    .frame(minHeight: Layout.minTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 78, alignment: .leading)

            Spacer(minLength: 0)
            Text("内容を確認")
                .font(AppFont.rounded(size: 16, weight: .heavy))
                .foregroundStyle(tokens.text)
            Spacer(minLength: 0)

            // 右に同幅スペーサ（中央寄せ用）。
            Color.clear.frame(width: 78, height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var confirmSub: some View {
        Text("名前・もち日数・残量を確認して追加できます。")
            .font(AppFont.rounded(size: 12.5, weight: .semibold))
            .foregroundStyle(tokens.textSec)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }

    private var confirmList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(AddGroups.resolved) { g in
                    confirmSection(g)
                }
                // 末尾「＋ 食べものを選び直す」（破線・選ぶへ戻る）。
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        model.screen = .select
                    }
                } label: {
                    Text("＋ 食べものを選び直す")
                        .font(AppFont.rounded(size: 13.5, weight: .heavy))
                        .foregroundStyle(tokens.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .foregroundStyle(tokens.hair)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            // 下部トレイに隠れない余白。
            .padding(.bottom, 100)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func confirmSection(_ g: AddGroup) -> some View {
        // このセクションに属するかご内アイテム（追加順）。
        let items = model.grouped
            .filter { g.ids.contains($0.catId) }
            .sorted { $0.lastOrder > $1.lastOrder }
            .flatMap(\.items)
        if !items.isEmpty {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(g.label)
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundStyle(tokens.brandInk)
                    Rectangle()
                        .fill(tokens.hair)
                        .frame(height: 1)
                }
                .padding(.horizontal, 2)
                .padding(.top, 10)
                .padding(.bottom, 9)

                ForEach(items) { it in
                    ConfirmItemCard(item: it, model: model)
                }
            }
        }
    }

    private var confirmTray: some View {
        let n = model.cartCount
        return Button {
            model.commit(context: context, toastCenter: toast)
            isPresented = false
        } label: {
            Text("冷蔵庫に追加（\(n)品）")
                .font(AppFont.rounded(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        // 押しやすさのため、下部に適度な余白を確保する（ユーザー指定）。
        .padding(.bottom, 26)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 18,
                style: .continuous
            )
            .fill(tokens.surface2)
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.07),
                    radius: 7, x: 0, y: -3)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(tokens.hair).frame(height: 1)
        }
    }

    // MARK: - 閉じる確認オーバーレイ

    /// 閉じる確認のトップモーダル（常設 ZStack に if ＋ transition、.animation を直接付与）。
    private var confirmCloseOverlay: some View {
        ZStack(alignment: .bottom) {
            if model.confirmClose {
                let n = model.cartCount
                Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { model.confirmClose = false }
                VStack(alignment: .leading, spacing: 0) {
                    Text("かごに \(n)品 残っています")
                        .font(AppFont.rounded(size: 17, weight: .heavy))
                        .foregroundStyle(tokens.text)
                    Text("このまま閉じると、選んだ内容はクリアされます。")
                        .font(AppFont.rounded(size: 13.5, weight: .semibold))
                        .foregroundStyle(tokens.textSec)
                        .lineSpacing(3)
                        .padding(.top, 4)
                    VStack(spacing: 9) {
                        Button {
                            model.reset(store: store)
                            isPresented = false
                        } label: {
                            Text("かごを空にして閉じる")
                                .font(AppFont.rounded(size: 15.5, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        Button {
                            // 選ぶ画面にとどまる
                            model.confirmClose = false
                        } label: {
                            Text("キャンセル")
                                .font(AppFont.rounded(size: 14.5, weight: .bold))
                                .foregroundStyle(tokens.textSec)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 22,
                        style: .continuous
                    )
                    .fill(tokens.bg2)
                    .ignoresSafeArea(edges: .bottom)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: model.confirmClose)
        .allowsHitTesting(model.confirmClose)
    }

    // MARK: - 閉じる制御

    private func handleDismiss() {
        // 確認画面でスクリムタップ → 選ぶへ戻すのではなく、かご非空なら閉じ確認を出す
        // （プロトタイプ FKSheet onClose=requestClose と同じ。画面に関わらずかご基準で判断）。
        if model.requestClose() {
            isPresented = false
        }
    }
}
