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
    /// 下部トレイの遅延競り上がり用。シート本体より一拍遅れて「ひょこっ」と出す。
    @State private var ctaBarVisible = false

    private var copy: ToneCopy { store.tone.copy }

    var body: some View {
        ZStack {
            SheetContainer(
                isPresented: $isPresented,
                heightFraction: 0.88,
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
                model.reset(store: store)
                popInCtaBar()
                #if DEBUG
                applyLaunchHook()
                #endif
            } else {
                ctaBarVisible = false
            }
        }
        #if DEBUG
        .onAppear {
            if isPresented {
                model.reset(store: store)
                popInCtaBar()
                applyLaunchHook()
            }
        }
        #endif
    }

    /// 下部トレイをシート本体より一拍（0.22秒）遅らせて競り上げる（ユーザー指定の「ひょこっ」演出）。
    private func popInCtaBar() {
        ctaBarVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                ctaBarVisible = true
            }
        }
    }

    #if DEBUG
    /// -openAddConfirm で fish×2・dairy×1 をカゴに積んで確認画面を初期表示する（スクショ用）。
    private func applyLaunchHook() {
        let args = CommandLine.arguments
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
            selectHeader
            categoryGrid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 下部トレイ（チップ＋CTA）をオーバーレイで底に敷く。
        .overlay(alignment: .bottom) {
            selectTray
                .offset(y: ctaBarVisible ? 0 : 160)
        }
    }

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

    private var categoryGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(AddGroups.resolved) { g in
                    sectionHeader(g.label)
                    tileGrid(g.ids)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 2)
            // 下部トレイに隠れない余白（チップ行＋CTA 分）。
            .padding(.bottom, 132)
        }
        .frame(maxHeight: .infinity)
    }

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

    private func categoryTile(_ cat: FoodCategory) -> some View {
        let count = model.countOf(catId: cat.id)
        let active = count > 0
        return Button {
            model.addOne(category: cat, store: store)
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
        return VStack(spacing: 0) {
            if !groups.isEmpty {
                chipRow(groups)
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
            .padding(.top, groups.isEmpty ? 12 : 0)
        }
        .padding(.bottom, 13)
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
        .background(tokens.bg2)
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
        .padding(.bottom, 13)
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
                    Text("登録するとホームに追加されます。どうしますか？")
                        .font(AppFont.rounded(size: 13.5, weight: .semibold))
                        .foregroundStyle(tokens.textSec)
                        .lineSpacing(3)
                        .padding(.top, 4)
                    VStack(spacing: 9) {
                        Button {
                            model.commit(context: context, toastCenter: toast)
                            isPresented = false
                        } label: {
                            Text("\(n)品を登録して閉じる")
                                .font(AppFont.rounded(size: 15.5, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        Button {
                            // かごを空にして閉じる
                            model.reset(store: store)
                            isPresented = false
                        } label: {
                            Text("かごを空にして閉じる")
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
