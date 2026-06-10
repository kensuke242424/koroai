// ゆとりありセクション（折りたたみ）。プロトタイプ fk-home.jsx FKPlenty の移植。
//
// ヘッダー: copy.plenty fs15 w700 textSec + 件数バッジ + copy.plentyNote fs12.5 textTer + 回転チェブロン。
// 展開で行（surface radius16 opacity0.82、icon34、名前 fs15 w600、AmountIndicator、
//   右に「あとN日」or daysLeft>13 は「当分OK」）。
// プロトタイプの行はスワイプ対応していないが、本実装でも食べた/処分/編集を有効化（共通の SwipeableRow を使う）。

import SwiftUI

struct PlentySection: View {
    let items: [FoodItem]
    var onAte: (FoodItem) -> Void
    var onToss: (FoodItem) -> Void
    var onEdit: (FoodItem) -> Void

    @State private var open = false
    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 8) {
                header
                if open {
                    ForEach(items, id: \.id) { item in
                        SwipeableRow(
                            onAte: { onAte(item) },
                            onToss: { onToss(item) },
                            onTap: { onEdit(item) }
                        ) {
                            row(item)
                        }
                    }
                }
            }
            .padding(.top, 26)
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(store.tone.copy.plenty)
                    .font(AppFont.rounded(size: 15, weight: .bold))
                    .foregroundStyle(tokens.textSec)
                Text("\(items.count)")
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                    .foregroundStyle(tokens.textTer)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(plentyBadgeBg, in: Capsule())
                Text(store.tone.copy.plentyNote)
                    .font(AppFont.rounded(size: 12.5, weight: .regular))
                    .foregroundStyle(tokens.textTer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tokens.textTer)
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .frame(minHeight: Layout.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 件数バッジ背景。出典: fk-home.jsx FKPlenty rgba(70,55,30,0.06) / dark rgba(255,255,255,0.06)
    private var plentyBadgeBg: Color {
        tokens.colorSchemeIsDark
            ? Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.06)
            : Color(.sRGB, red: 70 / 255, green: 55 / 255, blue: 30 / 255, opacity: 0.06)
    }

    private func row(_ item: FoodItem) -> some View {
        HStack(spacing: 12) {
            if let cat = item.category {
                CategoryIcon(category: cat, size: 34)
            }
            Text(item.name)
                .font(AppFont.rounded(size: 15, weight: .semibold))
                .foregroundStyle(tokens.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            AmountIndicator(item: item, size: 34)
            Text(item.daysLeft() > 13 ? HomeCopy.plentyLongLabel : "あと\(item.daysLeft())日")
                .font(AppFont.rounded(size: 13, weight: .semibold))
                .foregroundStyle(tokens.textTer)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tokens.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}
