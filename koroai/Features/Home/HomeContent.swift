// 案C ホーム本体。プロトタイプ fk-home.jsx FKHomeC の構成を移植。
//
// urgent があれば HeroCard、なければ「急ぎなし」カード（hero はあるが urgent が空）。
// hero 全体が0件なら FKEmpty 相当。calm があれば「今週の食材」リスト。最後に PlentySection。

import SwiftUI

struct HomeContent: View {
    let split: HomeSplit
    var onAte: (FoodItem) -> Void
    var onToss: (FoodItem) -> Void
    var onEdit: (FoodItem) -> Void
    var onRecipe: () -> Void

    @Environment(\.tokens) private var tokens

    var body: some View {
        VStack(spacing: 0) {
            if !split.hasHero {
                // hero（生鮮で食べ頃近い）が0件 → FKEmpty 相当
                NoUrgentEmpty()
            } else if !split.urgent.isEmpty {
                HeroCard(
                    urgent: split.urgent,
                    onAte: onAte,
                    onToss: onToss,
                    onEdit: onEdit,
                    onRecipe: onRecipe
                )
            } else {
                NoUrgentCard()
            }

            if !split.calm.isEmpty {
                calmSection
                    .padding(.top, 28)
            }

            PlentySection(items: split.plenty, onAte: onAte, onToss: onToss, onEdit: onEdit)
        }
    }

    // MARK: - 今週の食材

    private var calmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(HomeCopy.calmLabel)
                .font(AppFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(tokens.textSec)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(split.calm.enumerated()), id: \.element.id) { index, item in
                    SwipeableRow(
                        onAte: { onAte(item) },
                        onToss: { onToss(item) },
                        onTap: { onEdit(item) }
                    ) {
                        ItemRow(item: item, iconSize: 38)
                            .overlay(alignment: .top) {
                                if index > 0 {
                                    Rectangle().fill(tokens.hair).frame(height: 1)
                                }
                            }
                    }
                }
            }
            .background(tokens.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: tokens.shadow, radius: 2, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 今週の食材リストの1行

struct ItemRow: View {
    let item: FoodItem
    var iconSize: CGFloat = 38

    @Environment(\.tokens) private var tokens

    var body: some View {
        HStack(spacing: 12) {
            if let cat = item.category {
                CategoryIcon(category: cat, size: iconSize)
            }
            Text(item.name)
                .font(AppFont.rounded(size: 15.5, weight: .bold))
                .foregroundStyle(tokens.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            AmountIndicator(item: item, size: 34)
            DayPill(daysLeft: item.daysLeft(), size: .sm)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(tokens.surface)
        .contentShape(Rectangle())
    }
}

// MARK: - 急ぎなしカード（hero あり / urgent なし）

struct NoUrgentCard: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tokens.brand)
                .frame(width: 46, height: 46)
                .background(tokens.surface, in: Circle())
                // 隣のテキストで意味が伝わる装飾アイコン。
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(HomeCopy.noUrgentTitle)
                    .font(AppFont.rounded(size: 17, weight: .heavy))
                    .foregroundStyle(tokens.brandInk)
                Text(HomeCopy.noUrgentSub)
                    .font(AppFont.rounded(size: 13, weight: .bold))
                    .foregroundStyle(tokens.textSec)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(tokens.brandSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - FKEmpty 相当（hero 全体が0件）

struct NoUrgentEmpty: View {
    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tokens.brand)
                .frame(width: 56, height: 56)
                .background(tokens.brandSoft, in: Circle())
                // 隣のテキストで意味が伝わる装飾アイコン。
                .accessibilityHidden(true)
            Text(store.tone.copy.empty)
                .font(AppFont.rounded(size: 15.5, weight: .bold))
                .foregroundStyle(tokens.textSec)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 20)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
