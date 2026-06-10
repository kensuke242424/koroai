// Urgency（残日数 → 色温度）の純粋関数テスト。
// hue 曲線・tier 境界・OKLCH→sRGB 変換・色トークンのスモークを検証する。

import Testing
import SwiftUI
@testable import koroai

struct UrgencyTests {

    // MARK: - hue

    @Test func hueAtZeroIs34() {
        #expect(Urgency.hue(daysLeft: 0) == 34)
    }

    @Test func hueAtSevenIs150() {
        #expect(Urgency.hue(daysLeft: 7) == 150)
    }

    @Test func hueClampsAboveSeven() {
        #expect(Urgency.hue(daysLeft: 10) == 150)
    }

    @Test func hueClampsBelowZero() {
        #expect(Urgency.hue(daysLeft: -1) == 34)
    }

    @Test func hueAtThreeFollowsLinearFormula() {
        let expected = 34 + 3.0 / 7.0 * 116.0   // ≈ 83.714
        #expect(abs(Urgency.hue(daysLeft: 3) - expected) < 0.001)
    }

    // MARK: - tier

    @Test(arguments: [
        (0, 0), (1, 1), (2, 2), (3, 2), (4, 3), (6, 3), (7, 4), (-1, 0),
    ])
    func tierBoundaries(daysLeft: Int, expected: Int) {
        #expect(Urgency.tier(daysLeft: daysLeft) == expected)
    }

    // MARK: - OKLCH → sRGB 既知ペア（純赤）

    @Test func oklchPureRedMatchesSRGB() {
        let color = Color(oklchLightness: 0.6280, chroma: 0.2577, hue: 29.234)
        let (r, g, b, _) = Self.rgba(of: color)
        #expect(abs(r - 1.0) < 0.01)
        #expect(abs(g - 0.0) < 0.01)
        #expect(abs(b - 0.0) < 0.01)
    }

    // MARK: - 色トークンのスモーク

    @Test func tokenColorsAreInRangeAcrossDaysAndScheme() {
        for daysLeft in 0...7 {
            for isDark in [false, true] {
                let c = Urgency.colors(daysLeft: daysLeft, isDark: isDark)
                for color in [c.pillBg, c.pillFg, c.solid, c.track] {
                    let (r, g, b, _) = Self.rgba(of: color)
                    for comp in [r, g, b] {
                        #expect(comp >= 0.0 && comp <= 1.0)
                    }
                }
            }
        }
    }

    @Test func lightPillBgIsBright() {
        for daysLeft in 0...7 {
            let c = Urgency.colors(daysLeft: daysLeft, isDark: false)
            let (r, g, b, _) = Self.rgba(of: c.pillBg)
            #expect(r > 0.7)
            #expect(g > 0.7)
            #expect(b > 0.7)
        }
    }

    // MARK: - ヘルパー

    /// SwiftUI Color を UIColor 経由で sRGB RGBA に展開する。
    static func rgba(of color: Color) -> (Double, Double, Double, Double) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
