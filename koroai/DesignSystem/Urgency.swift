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

        // 2. Lab -> LMS'（立方根空間）
        let lp = L + 0.3963377774 * a + 0.2158037573 * b
        let mp = L - 0.1055613458 * a - 0.0638541728 * b
        let sp = L - 0.0894841775 * a - 1.2914855480 * b

        // 3. 立方
        let l = lp * lp * lp
        let m = mp * mp * mp
        let s = sp * sp * sp

        // 4. LMS -> 線形 sRGB
        let rLin = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let gLin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bLin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        // 5. ガンマ補正 + clamp
        func gamma(_ c: Double) -> Double {
            let v = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055
            return min(max(v, 0), 1)
        }

        // 6. sRGB Color
        self.init(.sRGB,
                  red: gamma(rLin),
                  green: gamma(gLin),
                  blue: gamma(bLin),
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
