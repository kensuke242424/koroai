// 今日の冷蔵庫（ホーム・確定形＝案C）。プロトタイプ fk-app.jsx ホーム部分 + fk-home.jsx FKHomeC の移植。
//
// 構成（上→下）: コンパクトナビバー（キッカー⇄小タイトルのクロスフェード＋設定）/ ラージタイトル /
//   sticky メタ行（日付・N品 + 今朝のまとめチップ）/ 達成カード / HomeContent（ヒーロー or 急ぎなし or 空）/
//   今週の食材リスト / ゆとりありセクション / FAB。
//
// 食べた/捨てた処理は本 View に集約: SwiftData 操作 + ToastCenter + praise 再抽選（達成数はクエリ導出）。
// 未実装画面（設定・まとめ・ふりかえり・追加・編集）は UI を作り、タップで「準備中です」トースト。

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.modelContext) private var context

    @Query private var items: [FoodItem]
    @Query private var logs: [ConsumptionLog]

    @State private var scrollY: CGFloat = 0
    @State private var praiseTemplate: String = HomeCopy.pickPraise(avoiding: nil)
    @State private var addFlowPresented = false

    /// 設定・まとめ・ふりかえり・追加・編集など未実装画面の動線。
    /// closure 注入で後から差し替えやすくしておく（既定は「準備中です」トースト）。
    /// TODO(Step 4〜7): 各 closure を実画面の表示に差し替える。
    var onOpenSettings: (() -> Void)? = nil
    var onOpenDigest: (() -> Void)? = nil
    var onOpenReview: (() -> Void)? = nil
    var onAdd: (() -> Void)? = nil
    var onEditItem: ((FoodItem) -> Void)? = nil

    private var split: HomeSplit { HomeSplitter.split(items: items) }
    private var monthlyAte: Int { Stats.monthlyAteCount(logs: logs) }

    // クロスフェード進行: clamp((y-26)/34)。出典: fk-app.jsx titleP。
    private var titleProgress: CGFloat { clamp01((scrollY - 26) / 34) }

    var body: some View {
        ZStack(alignment: .bottom) {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                scrollBody
            }

            fab
            ToastOverlay()

            // 追加シート（FAB より上に重ねる）。自作 SheetContainer（native .sheet は使わない）。
            AddSheet(isPresented: $addFlowPresented)
        }
        #if DEBUG
        .onAppear { applyAddFlowLaunchHooks() }
        #endif
    }

    #if DEBUG
    /// スクショ用 DEBUG フック。-openAddSheet で追加シートを初期表示、
    /// -openAddDetail <catId> でそのカテゴリの詳細入力まで開く。
    private func applyAddFlowLaunchHooks() {
        let args = CommandLine.arguments
        if args.contains("-openAddSheet") || args.contains("-openAddDetail") {
            addFlowPresented = true
        }
    }
    #endif

    // MARK: - コンパクトナビバー（常設）

    private var navBar: some View {
        HStack(alignment: .center, spacing: 10) {
            // キッカー ⇄ 小タイトルのクロスフェード
            ZStack(alignment: .leading) {
                Text(store.tone.copy.homeKicker)
                    .font(AppFont.rounded(size: 14, weight: .bold))
                    .foregroundStyle(tokens.textSec)
                    .opacity(Double(clamp01(1 - titleProgress * 1.4)))
                    .offset(y: titleProgress * -6)
                Text(headline)
                    .font(AppFont.rounded(size: 17, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .lineLimit(1)
                    .opacity(Double(titleProgress))
                    .offset(y: (1 - titleProgress) * 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 設定ボタン（34pt 円・surface2・太陽風・タップ領域44）
            Button {
                fire(onOpenSettings) // TODO(Step 7): 設定画面へ
            } label: {
                Image(systemName: "sun.max")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tokens.textSec)
                    .frame(width: 34, height: 34)
                    .background(tokens.surface2, in: Circle())
                    .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定")
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(tokens.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(titleProgress > 0.6 ? tokens.hair : .clear)
                .frame(height: 1)
        }
        .zIndex(50)
    }

    // MARK: - スクロール本体

    private var scrollBody: some View {
        ScrollView {
            // スクロール量をオフセットで取得（iOS 17 互換 PreferenceKey）
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: -geo.frame(in: .named("homeScroll")).minY
                )
            }
            .frame(height: 0)

            // sticky にするため LazyVStack(pinnedViews: .sectionHeaders) を使う。
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // ラージタイトル（スクロールでフェード＋微縮小）
                Text(headline)
                    .font(AppFont.rounded(size: 28, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .opacity(Double(clamp01(1 - titleProgress * 1.15)))
                    .scaleEffect(1 - titleProgress * 0.04, anchor: .topLeading)

                Section {
                    contentArea
                } header: {
                    metaRow
                }
            }
        }
        .coordinateSpace(name: "homeScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { y in
            if abs(scrollY - y) > 1 { scrollY = y }
        }
    }

    // ScrollView 内で sticky にするため LazyVStack(pinnedViews) を使う構成へ。
    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                EmptyFridgeView(tone: store.tone) { openAdd() }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            } else {
                VStack(spacing: 0) {
                    if store.showAchievementCard && split.hasHero {
                        achievementCard
                            .padding(.bottom, 16)
                    }
                    HomeContent(
                        split: split,
                        onAte: ate(_:),
                        onToss: toss(_:),
                        // TODO(Step 5): 編集シートへ
                        onEdit: { item in
                            if let onEditItem {
                                onEditItem(item)
                            } else {
                                toast.show(.toss, "準備中です")
                            }
                        },
                        onRecipe: { toast.show(.toss, "準備中です") } // ユーザー決定: レシピは準備中
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }

            // FAB に被らないための余白
            Color.clear.frame(height: 130)
        }
    }

    // MARK: - メタ行（sticky）

    private var metaRow: some View {
        HStack {
            Text("\(HomeCopy.dateLabel(date: .now))・冷蔵庫に\(split.totalCount)品")
                .font(AppFont.rounded(size: 13, weight: .bold))
                .foregroundStyle(tokens.textTer)
            Spacer()
            digestChip
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(tokens.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(scrollY > 64 ? tokens.hair : .clear)
                .frame(height: 1)
        }
    }

    private var digestChip: some View {
        Button {
            fire(onOpenDigest) // TODO(Step 6): 今朝のまとめへ
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 12))
                    if split.hasDueToday {
                        Circle()
                            .fill(tokens.accent)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(tokens.brandSoft, lineWidth: 1.5))
                            .offset(x: 3, y: -3)
                    }
                }
                Text("今朝のまとめ")
                    .font(AppFont.rounded(size: 12.5, weight: .heavy))
            }
            .foregroundStyle(tokens.brandInk)
            .padding(.vertical, 5)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(minHeight: Layout.minTapTarget)
            .background(tokens.brandSoft, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 達成カード

    private var achievementCard: some View {
        Button {
            fire(onOpenReview) // TODO(Step 6): ふりかえりへ
        } label: {
            HStack(spacing: 15) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    CountUpNumber(value: monthlyAte)
                        .font(AppFont.rounded(size: 38, weight: .heavy))
                    Text("品")
                        .font(AppFont.rounded(size: 16, weight: .heavy))
                }
                .foregroundStyle(tokens.brandInk)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(HomeCopy.renderPraise(praiseTemplate, count: monthlyAte))
                            .font(AppFont.rounded(size: 15.5, weight: .heavy))
                            .foregroundStyle(tokens.text)
                            .lineLimit(2)
                            .id(praiseTemplate) // 入替時にフェードイン
                            .transition(.opacity)
                        LeafBadge()
                    }
                    Text(HomeCopy.achievementSub)
                        .font(AppFont.rounded(size: 12.5, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tokens.brandInk)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(achievementGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tokens.hair, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// brandSoft → surface の 150° グラデ。
    private var achievementGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [tokens.brandSoft, tokens.surface]),
            startPoint: UnitPoint(x: 0.1, y: 0),
            endPoint: UnitPoint(x: 0.9, y: 1)
        )
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            openAdd()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(tokens.accent, in: Circle())
                .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.45), radius: 11, x: 0, y: 8)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 30)
        .accessibilityLabel("追加")
    }

    // MARK: - 派生コピー

    private var headline: String {
        HomeCopy.dailyHeadline(date: .now)
    }

    // MARK: - 食べた / 捨てた

    private func ate(_ item: FoodItem) {
        let catId = item.catId
        context.delete(item)
        context.insert(ConsumptionLog(catId: catId, action: .ate))
        try? context.save()
        // 処理後の当月件数（クエリ導出と同じになるよう再計算）
        let n = Stats.monthlyAteCount(logs: ((try? context.fetch(FetchDescriptor<ConsumptionLog>())) ?? []))
        // praise 再抽選（直前と重複回避）
        withAnimation(.easeIn(duration: 0.32)) {
            praiseTemplate = HomeCopy.pickPraise(avoiding: praiseTemplate)
        }
        toast.show(.ate, ateMessage(count: n))
    }

    private func toss(_ item: FoodItem) {
        let catId = item.catId
        context.delete(item)
        context.insert(ConsumptionLog(catId: catId, action: .tossed))
        try? context.save()
        toast.show(.toss, store.tone.copy.tossed)
    }

    /// 「食べた」トースト文言。N は処理後の当月件数。出典: fk-app.jsx onAte msgs。
    private func ateMessage(count n: Int) -> String {
        let ate = store.tone.copy.ate
        switch store.tone {
        case .gentle: return "\(ate) 今月 \(n) 品を使いきれました"
        case .simple: return "\(ate)（今月 \(n)）"
        case .cheer: return "\(ate) 今月\(n)品め、その調子！"
        }
    }

    // MARK: - ヘルパー

    /// 追加動線。onAdd 注入があればそれを優先、なければ自作の追加シートを開く。
    private func openAdd() {
        if let onAdd {
            onAdd()
        } else {
            addFlowPresented = true
        }
    }

    /// 未実装動線: closure があれば呼ぶ、なければ「準備中です」トースト。
    private func fire(_ action: (() -> Void)?) {
        if let action {
            action()
        } else {
            toast.show(.toss, "準備中です")
        }
    }

    private func fire(_ action: () -> Void) {
        action()
    }

    private func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }
}

// MARK: - スクロールオフセット PreferenceKey（iOS 17 互換）

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 葉アイコン

struct LeafBadge: View {
    var size: CGFloat = 16
    @Environment(\.tokens) private var tokens
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: size * 0.9))
            .foregroundStyle(tokens.brand)
    }
}

// MARK: - カウントアップ数字（FKCountUp 風・増加時ポップ）

struct CountUpNumber: View {
    let value: Int
    @State private var pop: CGFloat = 1

    var body: some View {
        Text("\(value)")
            .scaleEffect(pop)
            .onChange(of: value) { old, new in
                guard new > old else { return }
                pop = 1.25
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { pop = 1 }
            }
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
        .modelContainer(PreviewData.container)
}
