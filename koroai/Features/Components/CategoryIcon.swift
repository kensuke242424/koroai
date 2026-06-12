// カテゴリアイコン。色付き円＋漢字1字グリフ（絵文字不使用）。プロトタイプ FKIcon の移植。
//
// bg = cat.color opacity 0.22（dark 0.30）/ リング inset 1.5pt = cat.color opacity 0.30（dark 0.40）/
// グリフ色 = mixOKLab(cat.color, ink/cream, 0.78 or 0.58)。
// 元の CSS は color-mix(in oklab, color p%, transparent) ＝ color.opacity(p)（ColorMix の特別扱い）。

import SwiftUI

struct CategoryIcon: View {
    let category: FoodCategory
    var size: CGFloat = 46

    @Environment(\.resolvedTheme) private var theme

    // グリフ混色の相手色（プロトタイプの裸の hex。出典: fk-ui.jsx FKIcon glyphColor）。
    private static let glyphInk = Color(hex: 0x4a3f2c)   // light: ダーク寄りインク
    private static let glyphCream = Color(hex: 0xfbf3e3) // dark: クリーム寄り

    private var isDark: Bool { theme.isDark }

    private var bg: Color {
        // color-mix(color 22%/30%, transparent) ＝ opacity
        mixWithTransparent(category.color, fractionOfFirst: isDark ? 0.30 : 0.22)
    }

    private var ring: Color {
        mixWithTransparent(category.color, fractionOfFirst: isDark ? 0.40 : 0.30)
    }

    private var glyphColor: Color {
        isDark
            ? mixOKLab(category.color, Self.glyphCream, fractionOfFirst: 0.58)
            : mixOKLab(category.color, Self.glyphInk, fractionOfFirst: 0.78)
    }

    var body: some View {
        Text(category.glyph)
            .font(AppFont.rounded(size: size * 0.42, weight: .heavy))
            .foregroundStyle(glyphColor)
            .frame(width: size, height: size)
            .background(bg, in: Circle())
            .overlay(Circle().strokeBorder(ring, lineWidth: 1.5))
            // 漢字1字グリフだけでは意味が伝わりにくいため、カテゴリ名を読み上げる。
            .accessibilityElement()
            .accessibilityLabel(category.name)
    }
}
