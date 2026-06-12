// ヒーローカード（案C デッキ）。プロトタイプ fk-home.jsx FKHomeC のヒーロー部分の移植。
//
// urgent（残2日以下の生鮮）を id 順序の @State で管理し、集合変化時は既存順序維持＋新規末尾。
// circular next/prev。canCycle 時は背後に2枚の重なり。
// カード本体: 160° グラデ（mixOKLab(urgency.solid, surface, 0.16)→surface）radius26・強シャドウ。
// FKIcon 62 / DayPill md / 名前 fs24 w800 / AmountIndicator 40 / heroVerb（pillFg fs15 w700）。
// deck 2枚以上なら「急ぎはほかにN品・スワイプで切替」。
// ボタン行（食べた=accent 塗り flex・チェック / レシピ=中立背景）。「食べた」は EatBurst 後に確定。
// SwipeableRow（横=食べた/処分、縦=循環、タップ=編集プレースホルダー）。

import SwiftUI

struct HeroCard: View {
    let urgent: [FoodItem]
    var onAte: (FoodItem) -> Void
    var onToss: (FoodItem) -> Void
    var onEdit: (FoodItem) -> Void
    var onRecipe: () -> Void

    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store

    // デッキの id 順序。集合変化時に既存順序を維持しつつ新規を末尾へ。
    @State private var order: [UUID] = []
    @State private var bursting = false

    /// デッキの実効順序。@State の order に未反映の urgent があっても落とさないよう、
    /// order に無い urgent は末尾に補って必ず全件を返す（初回レンダーで空にならないようにする）。
    private var deck: [FoodItem] {
        let ordered = order.compactMap { id in urgent.first { $0.id == id } }
        let missing = urgent.filter { item in !order.contains(item.id) }
        return ordered + missing
    }

    private var top: FoodItem? { deck.first }
    private var canCycle: Bool { deck.count > 1 }

    var body: some View {
        Group {
            if let top {
                ZStack {
                    if canCycle {
                        backgroundDeck
                    }
                    SwipeableRow(
                        onAte: { animateAteThenConfirm(top) },
                        onToss: { onToss(top) },
                        onTap: { onEdit(top) },
                        onCycleNext: canCycle ? cycleNext : nil,
                        onCyclePrev: canCycle ? cyclePrev : nil
                    ) {
                        card(top)
                    }
                }
                .padding(.bottom, canCycle ? 10 : 0)
            }
        }
        .onAppear { syncOrder() }
        .onChange(of: urgent.map(\.id)) { _, _ in syncOrder() }
    }

    // MARK: - 順序同期

    private func syncOrder() {
        let ids = urgent.map(\.id)
        let kept = order.filter { ids.contains($0) }
        let added = ids.filter { !kept.contains($0) }
        order = kept + added
    }

    private func cycleNext() {
        guard order.count > 1 else { return }
        order = Array(order.dropFirst()) + [order[0]]
    }

    private func cyclePrev() {
        guard order.count > 1 else { return }
        order = [order[order.count - 1]] + order.dropLast()
    }

    // MARK: - 食べた演出 → 確定

    private func animateAteThenConfirm(_ item: FoodItem) {
        guard !bursting else { return }
        bursting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            bursting = false
            onAte(item)
        }
    }

    // MARK: - 背後の重なり（2枚）

    private var backgroundDeck: some View {
        ZStack {
            // 奥（opacity 0.45）
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tokens.surface)
                .opacity(0.45)
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .offset(y: 18)
                .shadow(color: tokens.shadow, radius: 6, x: 0, y: 4)
            // 手前（opacity 0.7）
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(tokens.surface)
                .opacity(0.7)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .offset(y: 9)
                .shadow(color: tokens.shadow, radius: 6, x: 0, y: 4)
        }
    }

    // MARK: - カード本体

    private func card(_ item: FoodItem) -> some View {
        let d = item.daysLeft()
        let u = Urgency.colors(daysLeft: d, isDark: theme.isDark)
        let cat = item.category
        let moreUrgent = deck.count - 1

        return VStack(alignment: .leading, spacing: 0) {
            // 上段: アイコン + （ピル/名前/残量）
            HStack(alignment: .center, spacing: 14) {
                if let cat {
                    CategoryIcon(category: cat, size: 62)
                }
                VStack(alignment: .leading, spacing: 8) {
                    DayPill(daysLeft: d, size: .md)
                    Text(item.name)
                        .font(AppFont.rounded(size: 24, weight: .heavy))
                        .foregroundStyle(tokens.text)
                        .lineLimit(1)
                    AmountIndicator(item: item, size: 40)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)

            // verb + デッキ補足
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(HomeCopy.heroVerb(tone: store.tone, daysLeft: d))
                    .font(AppFont.rounded(size: 15, weight: .bold))
                    .foregroundStyle(u.pillFg)
                if moreUrgent > 0 {
                    Text(HomeCopy.moreUrgent(moreUrgent))
                        .font(AppFont.rounded(size: 13, weight: .bold))
                        .foregroundStyle(tokens.textTer)
                }
            }
            .padding(.bottom, 14)

            // ボタン行
            HStack(spacing: 10) {
                Button {
                    animateAteThenConfirm(item)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19))
                        Text("食べた")
                            .font(AppFont.rounded(size: 15.5, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Layout.minTapTarget)
                    .background(tokens.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onRecipe()
                } label: {
                    Text("レシピ")
                        .font(AppFont.rounded(size: 15.5, weight: .bold))
                        .foregroundStyle(tokens.text)
                        .frame(minHeight: Layout.minTapTarget)
                        .padding(.horizontal, 18)
                        .background(neutralBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(heroGradient(solid: u.solid), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: tokens.shadow, radius: 11, x: 0, y: 6)
        .overlay {
            if bursting {
                EatBurst()
            }
        }
        // ヒーローカードは AX サイズで文言切れ・FAB 被りが起きるため xxxLarge でキャップする
        //（拡大時のみ効く。large の見た目は不変）。
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var neutralBg: Color {
        ControlColors.neutral(isDark: tokens.colorSchemeIsDark)
    }

    /// 160° グラデ: mixOKLab(solid, surface, 0.16) → surface。
    private func heroGradient(solid: Color) -> LinearGradient {
        let tinted = mixOKLab(solid, tokens.surface, fractionOfFirst: 0.16)
        // CSS 160deg ≈ 左上やや上 → 右下やや下。SwiftUI の角度系へ近似。
        return LinearGradient(
            gradient: Gradient(colors: [tinted, tokens.surface]),
            startPoint: UnitPoint(x: 0.18, y: 0),
            endPoint: UnitPoint(x: 0.82, y: 1)
        )
    }
}
