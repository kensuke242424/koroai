// 期限の色温度。残日数 → 色の純粋関数で一元管理する（赤は使わない・OKLCH で生成）。

import SwiftUI
import Foundation

// MARK: - Color(oklch:) 拡張

extension Color {
    /// OKLCH（L: 0...1, C: chroma, H: degrees）から sRGB の Color を生成する。
    /// 変換は Björn Ottosson の OKLab 標準行列をそのまま用いる。
    init(oklchLightness L: Double, chroma C: Double, hue H: Double, opacity: Double = 1) {
        // 1. LCh -> Lab
        let hRad = H * .pi / 180
        let a = C * cos(hRad)
        let b = C * sin(hRad)

        // 2. OKLab -> 線形 sRGB（共通ヘルパーに委譲。ColorMix と同一系を使う）
        let lin = OKLab.toLinearSRGB(L: L, a: a, b: b)

        // 3. ガンマ補正 + clamp -> sRGB Color
        self.init(.sRGB,
                  red: OKLab.toGamma(lin.r),
                  green: OKLab.toGamma(lin.g),
                  blue: OKLab.toGamma(lin.bb),
                  opacity: opacity)
    }
}

// MARK: - UrgencyColors

/// 残日数から導いた1セット分の色温度トークン。
struct UrgencyColors {
    let hue: Double
    let pillBg: Color
    let pillFg: Color
    let solid: Color
    let glow: Color
    let track: Color
}

// MARK: - Urgency

/// 残日数 → 色温度。セージグリーン（余裕）→アンバー→テラコッタ（要消費）。赤は使わない。
enum Urgency {
    /// hue = 34 + clamp(daysLeft, 0...7)/7 × (150 − 34)
    static func hue(daysLeft: Int) -> Double {
        let clamped = Double(min(max(daysLeft, 0), 7))
        return 34 + clamped / 7 * (150 - 34)
    }

    /// 残日数とダーク判定から色一式を生成する純粋関数。
    static func colors(daysLeft: Int, isDark: Bool) -> UrgencyColors {
        let h = hue(daysLeft: daysLeft)
        if isDark {
            return UrgencyColors(
                hue: h,
                pillBg: Color(oklchLightness: 0.43, chroma: 0.06, hue: h),
                pillFg: Color(oklchLightness: 0.90, chroma: 0.085, hue: h),
                solid: Color(oklchLightness: 0.72, chroma: 0.115, hue: h),
                glow: Color(oklchLightness: 0.72, chroma: 0.115, hue: h, opacity: 0.28),
                track: Color(oklchLightness: 0.48, chroma: 0.07, hue: h)
            )
        } else {
            return UrgencyColors(
                hue: h,
                pillBg: Color(oklchLightness: 0.935, chroma: 0.045, hue: h),
                pillFg: Color(oklchLightness: 0.46, chroma: 0.105, hue: h),
                solid: Color(oklchLightness: 0.69, chroma: 0.135, hue: h),
                glow: Color(oklchLightness: 0.69, chroma: 0.135, hue: h, opacity: 0.28),
                track: Color(oklchLightness: 0.89, chroma: 0.06, hue: h)
            )
        }
    }

    /// 残日数の段階。0:今日以下 1:明日 2:≤3日 3:≤6日 4:7日以上
    static func tier(daysLeft: Int) -> Int {
        if daysLeft <= 0 { return 0 }
        if daysLeft == 1 { return 1 }
        if daysLeft <= 3 { return 2 }
        if daysLeft <= 6 { return 3 }
        return 4
    }
}
