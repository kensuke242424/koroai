// カテゴリ選択タイル（選択モード＝チェックバッジ）。プロトタイプ fk-flows.jsx FKCatTile の汎用版。
//
// 追加シート（AddSheet.categoryTile）はかご個数バッジの addMode で独自に持つ。こちらは
// オンボーディング・入れ直しシートで使う「複数選択（チェックバッジ）」専用の軽量タイル。
// 見た目（角丸20・surface・active 時は cat.color 14% mix 塗り＋2pt 枠・右上チェック）はプロトタイプ準拠。

import SwiftUI

struct CatTile: View {
    let category: FoodCategory
    let selected: Bool
    let action: () -> Void

    @Environment(\.tokens) private var tokens

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                CategoryIcon(category: category, size: 52)
                Text(category.name)
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
                selected
                    ? mixOKLab(category.color, tokens.surface, fractionOfFirst: 0.14)
                    : tokens.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? category.color : .clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(category.color)
                        .background(Circle().fill(.white).padding(2))
                        .padding(7)
                }
            }
            .shadow(color: tokens.shadow, radius: 1.5, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
