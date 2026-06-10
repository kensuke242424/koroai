// 追加シート（カテゴリ選択＋かご → 詳細入力）。プロトタイプ FKAddSheet の移植。
//
// native .sheet は使わず SheetContainer(84%) 内に組む。グリッド層の上に詳細オーバーレイ層を重ね、
// その上に閉じる確認オーバーレイを重ねる。文言はプロトタイプから一字一句転記。
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
    /// かごバーの遅延競り上がり用。シート本体より一拍遅れて「ひょこっ」と出す。
    @State private var ctaBarVisible = false

    private var copy: ToneCopy { store.tone.copy }

    var body: some View {
        ZStack {
            SheetContainer(
                isPresented: $isPresented,
                heightFraction: 0.84,
                extendContentUnderHomeIndicator: true, // かごバーを画面下端まで敷く（デザイン準拠）
                onDismissRequest: { handleDismiss() }
            ) {
                gridLayer
            }

            // 詳細入力／閉じる確認は「トップモーダル」なので、シートの内側ではなく
            // 全画面に重ねる（背後＝ホーム＋カテゴリ選択シートの全体をスクリムでマスクする）。
            detailOverlay
            confirmCloseOverlay
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                model.reset()
                popInCtaBar()
                #if DEBUG
                applyDetailLaunchHook()
                #endif
            } else {
                ctaBarVisible = false
            }
        }
        #if DEBUG
        .onAppear {
            if isPresented {
                model.reset()
                popInCtaBar()
                applyDetailLaunchHook()
            }
        }
        #endif
    }

    /// かごバーをシート本体より一拍（0.22秒）遅らせて競り上げる。
    private func popInCtaBar() {
        ctaBarVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                ctaBarVisible = true
            }
        }
    }

    #if DEBUG
    /// -openAddDetail <catId> が渡されたら、そのカテゴリの詳細入力まで開く（スクショ用）。
    /// -openAddDetailDelayed <catId> は初回描画の後に開く（タイルタップと同じ
    /// 「表示後の state 変更」経路を再現するための検証フック）。
    private func applyDetailLaunchHook() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-openAddDetail"), i + 1 < args.count,
           let cat = FoodCategory.find(args[i + 1]) {
            model.openAdd(category: cat, store: store)
            return
        }
        if let i = args.firstIndex(of: "-openAddDetailDelayed"), i + 1 < args.count,
           let cat = FoodCategory.find(args[i + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                model.openAdd(category: cat, store: store)
            }
        }
    }
    #endif

    // MARK: - グリッド層

    private var gridLayer: some View {
        VStack(spacing: 0) {
            header
            cartBar
            categoryGrid
            ctaBar
        }
    }

    // ヘッダー
    // 説明サブ文言（タイルを選ぶと登録画面へ…）はユーザー判断で削除（表示幅を優先）。
    private var header: some View {
        Text(copy.addTitle)
            .font(AppFont.rounded(size: 22, weight: .heavy))
            .foregroundStyle(tokens.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    // かごバー（0品から表示）
    private var cartBar: some View {
        let n = model.cartCount
        return VStack(spacing: 7) {
            Button {
                if n > 0 { model.cartExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    LeafBadge(size: 15)
                    Text("かごに \(n)品")
                        .font(AppFont.rounded(size: 13.5, weight: .heavy))
                    Spacer(minLength: 0)
                    if n > 0 {
                        HStack(spacing: 4) {
                            Text(model.cartExpanded ? "折りたたむ" : "一覧")
                                .font(AppFont.rounded(size: 12, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(model.cartExpanded ? 90 : 0))
                        }
                    } else {
                        Text("タイルを選んで追加")
                            .font(AppFont.rounded(size: 12, weight: .bold))
                            .opacity(0.6)
                    }
                }
                .foregroundStyle(tokens.brandInk)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(tokens.brandSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if model.cartExpanded {
                cartList
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var cartList: some View {
        ScrollView {
            VStack(spacing: 7) {
                ForEach(model.cart) { it in
                    cartRow(it)
                }
            }
        }
        .frame(maxHeight: 168)
    }

    private func cartRow(_ it: DraftItem) -> some View {
        let cat = FoodCategory.find(it.catId)
        let u = Urgency.colors(daysLeft: it.days, isDark: theme.isDark)
        return Button {
            model.openEdit(draftId: it.id, store: store)
        } label: {
            HStack(spacing: 9) {
                if let cat {
                    miniGlyph(cat)
                }
                Text(it.name)
                    .font(AppFont.rounded(size: 14.5, weight: .bold))
                    .foregroundStyle(tokens.text)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(it.days <= 0 ? "今日" : "あと\(it.days)日")
                    .font(AppFont.rounded(size: 12.5, weight: .heavy))
                    .foregroundStyle(u.pillFg)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(u.pillBg, in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tokens.textTer)
                    .opacity(0.5)
                Button {
                    model.removeFromCart(id: it.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                        .frame(width: 24, height: 24)
                        .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.07), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取り消し")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(tokens.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 26pt ミニグリフ円（CategoryIcon の小型）。出典: fk-flows.jsx かご行。
    private func miniGlyph(_ cat: FoodCategory) -> some View {
        Text(cat.glyph)
            .font(AppFont.rounded(size: 12, weight: .heavy))
            .foregroundStyle(mixOKLab(cat.color, Color(hex: 0x4a3f2c), fractionOfFirst: 0.78))
            .frame(width: 26, height: 26)
            .background(mixWithTransparent(cat.color, fractionOfFirst: 0.22), in: Circle())
    }

    // カテゴリグリッド
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
            .padding(.bottom, 18)
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
            model.openAdd(category: cat, store: store)
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
        } else {
            Text("＋")
                .font(AppFont.rounded(size: 16, weight: .bold))
                .foregroundStyle(tokens.textTer)
                .frame(width: 21, height: 21)
                .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.07), in: Circle())
        }
    }

    // 下部 CTA バー
    private var ctaBar: some View {
        let n = model.cartCount
        return HStack(spacing: 12) {
            Button {
                if n > 0 { model.cartExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("\(n)")
                        .font(AppFont.rounded(size: 13, weight: .bold))
                        .foregroundStyle(n > 0 ? .white : tokens.textTer)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 25, minHeight: 25)
                        .background(n > 0 ? tokens.brand : tokens.surface2, in: Capsule())
                    Text("かごの中")
                        .font(AppFont.rounded(size: 14.5, weight: .heavy))
                        .foregroundStyle(tokens.text)
                    if n > 0 {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(tokens.textSec)
                            .rotationEffect(.degrees(model.cartExpanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(n == 0)

            Spacer(minLength: 0)

            Button {
                model.commit(context: context, toastCenter: toast)
                isPresented = false
            } label: {
                Text(n > 0 ? "まとめて登録" : "カゴは空")
                    .font(AppFont.rounded(size: 15, weight: .heavy))
                    .foregroundStyle(n > 0 ? .white : tokens.textTer)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 20)
                    .background(n > 0 ? tokens.accent : tokens.surface2,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: n > 0 ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.35) : .clear,
                            radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(n == 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 11)
        // デザイン準拠のタイトな下余白（バー自体が物理下端まで届くので 13pt のみ。
        // ホームインジケータは surface の上に浮く＝プロトタイプの見た目）。
        .padding(.bottom, 13)
        .background(tokens.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(tokens.hair).frame(height: 1)
        }
        // シート本体より一拍遅れて下から「ひょこっ」と競り上がる（ユーザー指定の演出）。
        .offset(y: ctaBarVisible ? 0 : 140)
    }

    // MARK: - 詳細オーバーレイ

    /// 詳細入力のトップモーダル。
    /// SheetContainer と同じ構造（常設 ZStack に if ＋ transition、.animation を直接付与）に
    /// しないと insertion/removal がフェードに化けるので注意。
    private var detailOverlay: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if model.view == .detail {
                    // スクリム（タップで grid へ戻る）。トップモーダルとして背後の全 View
                    // （ホーム＋カテゴリ選択シート）を画面全体でマスクする。
                    Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.30)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { model.view = .grid }
                    detailPanel(maxHeight: geo.size.height * 0.94)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: model.view)
        }
        .allowsHitTesting(model.view == .detail)
    }

    /// パネル高さは内容にフィットさせる（maxHeight 94% まで。プロトタイプの maxHeight: '94%' 相当）。
    /// 高さ計測（PreferenceKey）は新しい OS で発火しないことがあるため、
    /// ViewThatFits で「収まるなら素のフォーム（内容フィット）／溢れたらスクロール」に切り替える。
    private func detailPanel(maxHeight: CGFloat) -> some View {
        // 注意: ここで .frame(maxHeight:) を使ってはいけない。
        // frame(max〜:) は「上限まで広がる」挙動（maxWidth: .infinity と同じ規則）のため、
        // 中身が小さくてもパネルが上限高に膨らみ、中身が上下センタリングされて
        // 大きな余白ができる。上限はスクロール枝にだけ固定高で持たせる。
        ViewThatFits(in: .vertical) {
            // 収まるなら素のフォーム（内容フィット）
            DetailForm(model: model, isEditing: model.editingId != nil)
            // 溢れたら（カレンダー展開時等）スクロールに切替（高さは 94% 固定）
            ScrollView {
                DetailForm(model: model, isEditing: model.editingId != nil)
            }
            .frame(height: maxHeight)
        }
        .background {
            // 背景はホームインジケータ領域まで延長（SheetContainer と同じ扱い）。
            UnevenRoundedRectangle(
                topLeadingRadius: 24, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 24,
                style: .continuous
            )
            .fill(tokens.bg2)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - 閉じる確認オーバーレイ

    /// 閉じる確認のトップモーダル（detailOverlay と同じ常設 ZStack 構造）。
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
                            model.reset()
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
                    // 背景はホームインジケータ領域まで延長（SheetContainer と同じ扱い）。
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
        if model.view == .detail {
            model.view = .grid
            return
        }
        if model.requestClose() {
            isPresented = false
        }
    }
}
