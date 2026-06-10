// OKLab 色混合。プロトタイプの `color-mix(in oklab, X p%, Y)` を SwiftUI で再現する。
//
// プロトタイプは CSS の color-mix を多用する（FKIcon の bg/ring/glyph・ヒーローのグラデ・残量色など）。
// それらを忠実に再現するため、sRGB ⇄ OKLab の正準変換（Björn Ottosson 行列）を1箇所に集約し、
// OKLab 空間での線形補間として混合を実装する。Urgency.swift の OKLCH→sRGB も同じ系を使うよう共通化する。

import SwiftUI
import UIKit
import Foundation

// MARK: - OKLab 変換ヘルパー（sRGB ⇄ 線形sRGB ⇄ OKLab）

/// sRGB と OKLab を相互変換する内部ヘルパー。Urgency / ColorMix の両方から使う。
enum OKLab {

    // MARK: ガンマ（sRGB エンコード ⇄ 線形）

    /// sRGB 成分 → 線形 sRGB（逆ガンマ）。
    static func toLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// 線形 sRGB → sRGB 成分（ガンマ）＋ 0...1 クランプ。
    static func toGamma(_ c: Double) -> Double {
        let v = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055
        return min(max(v, 0), 1)
    }

    // MARK: 線形 sRGB ⇄ OKLab

    /// 線形 sRGB (r,g,b) → OKLab (L,a,b)。タスク指定の行列をそのまま使う。
    static func fromLinearSRGB(r: Double, g: Double, b: Double) -> (L: Double, a: Double, bb: Double) {
        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let lp = cbrt(l)
        let mp = cbrt(m)
        let sp = cbrt(s)

        let L = 0.2104542553 * lp + 0.7936177850 * mp - 0.0040720468 * sp
        // NOTE: タスク指定の a 第3係数 0.3963617737 は転記ミス（toLinearSRGB の逆行列にならず往復が破綻する）。
        //   Björn Ottosson の正準値 0.4505937099 を採用し、Urgency の OKLCH 逆変換と厳密に対になるようにした。
        let a = 1.9779984951 * lp - 2.4285922050 * mp + 0.4505937099 * sp
        let bb = 0.0259040371 * lp + 0.7827717662 * mp - 0.8086757660 * sp
        return (L, a, bb)
    }

    /// OKLab (L,a,b) → 線形 sRGB (r,g,b)。Urgency の OKLCH イニシャライザと同一系（逆行列）。
    static func toLinearSRGB(L: Double, a: Double, b: Double) -> (r: Double, g: Double, bb: Double) {
        // Lab -> LMS'（立方根空間）
        let lp = L + 0.3963377774 * a + 0.2158037573 * b
        let mp = L - 0.1055613458 * a - 0.0638541728 * b
        let sp = L - 0.0894841775 * a - 1.2914855480 * b

        // 立方
        let l = lp * lp * lp
        let m = mp * mp * mp
        let s = sp * sp * sp

        // LMS -> 線形 sRGB
        let rLin = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let gLin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bLin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return (rLin, gLin, bLin)
    }

    // MARK: Color ⇄ sRGB RGBA

    /// SwiftUI Color を UIColor 経由で sRGB の RGBA に展開する。
    static func rgba(of color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r), Double(g), Double(b), Double(a))
        }
        // sRGB に変換できないカラースペース（パターン等）は中間グレーにフォールバック。
        var white: CGFloat = 0
        if ui.getWhite(&white, alpha: &a) {
            return (Double(white), Double(white), Double(white), Double(a))
        }
        return (0, 0, 0, 1)
    }
}

// MARK: - color-mix 相当 API

/// OKLab 空間で2色を線形補間する。CSS の `color-mix(in oklab, x f%, y)` 相当。
/// - fractionOfFirst: x の比率（0...1）。CSS の「x f%」の f/100 に対応。
/// - opacity: 結果の不透明度（既定 1）。アルファも OKLab 補間に含めたい場合は呼び出し側で調整する。
func mixOKLab(_ x: Color, _ y: Color, fractionOfFirst: Double, opacity: Double = 1) -> Color {
    let f = min(max(fractionOfFirst, 0), 1)
    let cx = OKLab.rgba(of: x)
    let cy = OKLab.rgba(of: y)

    // 線形 sRGB へ
    let lx = OKLab.fromLinearSRGB(r: OKLab.toLinear(cx.r), g: OKLab.toLinear(cx.g), b: OKLab.toLinear(cx.b))
    let ly = OKLab.fromLinearSRGB(r: OKLab.toLinear(cy.r), g: OKLab.toLinear(cy.g), b: OKLab.toLinear(cy.b))

    // OKLab で線形補間（first を f、second を 1-f）
    let L = lx.L * f + ly.L * (1 - f)
    let a = lx.a * f + ly.a * (1 - f)
    let b = lx.bb * f + ly.bb * (1 - f)

    let lin = OKLab.toLinearSRGB(L: L, a: a, b: b)
    return Color(.sRGB,
                 red: OKLab.toGamma(lin.r),
                 green: OKLab.toGamma(lin.g),
                 blue: OKLab.toGamma(lin.bb),
                 opacity: opacity)
}

/// `color-mix(in oklab, x f%, transparent)` の特別扱い。x.opacity(f) に等しい。
/// 透明色との混合は OKLab 補間ではなく単なる不透明度になるため、専用 API として提供する。
func mixWithTransparent(_ x: Color, fractionOfFirst: Double) -> Color {
    x.opacity(min(max(fractionOfFirst, 0), 1))
}

// MARK: - 残量の塗り色（fkFillColor 移植）

extension Color {
    /// 残量比率 → 塗り色。プロトタイプ fkFillColor の移植。
    /// f≤0.22 → accent / f≤0.45 → mix(accent 55%, brand) / それ以外 → brand。
    /// 残量表示（AmountIndicator・残量スライダー等）の共通色。
    static func fillColor(fraction: Double, tokens: DesignTokens) -> Color {
        if fraction <= 0.22 { return tokens.accent }
        if fraction <= 0.45 { return mixOKLab(tokens.accent, tokens.brand, fractionOfFirst: 0.55) }
        return tokens.brand
    }
}
