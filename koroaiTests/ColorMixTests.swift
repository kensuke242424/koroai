// ColorMix（OKLab 色混合・fillColor）のテスト。
// sRGB→OKLab→sRGB 往復の誤差・OKLab 中点 L・fillColor の3分岐を検証する。

import Testing
import SwiftUI
import UIKit
@testable import koroai

struct ColorMixTests {

    // MARK: - 往復誤差

    @Test func srgbRoundTripWithinTolerance() {
        let samples: [Color] = [
            Color(.sRGB, red: 0.10, green: 0.45, blue: 0.80),
            Color(.sRGB, red: 0.72, green: 0.38, blue: 0.29),  // テラコッタ寄り
            Color(.sRGB, red: 0.44, green: 0.56, blue: 0.42),  // セージ寄り
            Color(.sRGB, red: 0.95, green: 0.92, blue: 0.86),  // クリーム
        ]
        for c in samples {
            let rgba = Self.rgba(of: c)
            let lin = (
                OKLab.toLinear(rgba.0),
                OKLab.toLinear(rgba.1),
                OKLab.toLinear(rgba.2)
            )
            let lab = OKLab.fromLinearSRGB(r: lin.0, g: lin.1, b: lin.2)
            let back = OKLab.toLinearSRGB(L: lab.L, a: lab.a, b: lab.bb)
            let r = OKLab.toGamma(back.r)
            let g = OKLab.toGamma(back.g)
            let b = OKLab.toGamma(back.bb)
            #expect(abs(r - rgba.0) < 0.002)
            #expect(abs(g - rgba.1) < 0.002)
            #expect(abs(b - rgba.2) < 0.002)
        }
    }

    // MARK: - 中点 L

    @Test func midpointOfWhiteBlackHasHalfLightness() {
        let mid = mixOKLab(.white, .black, fractionOfFirst: 0.5)
        let rgba = Self.rgba(of: mid)
        let lin = OKLab.fromLinearSRGB(
            r: OKLab.toLinear(rgba.0),
            g: OKLab.toLinear(rgba.1),
            b: OKLab.toLinear(rgba.2)
        )
        // white の L=1, black の L=0 → 中点は 0.5
        #expect(abs(lin.L - 0.5) < 0.01)
    }

    @Test func fractionExtremesReturnEndpoints() {
        let x = Color(.sRGB, red: 0.80, green: 0.20, blue: 0.15)
        let y = Color(.sRGB, red: 0.15, green: 0.30, blue: 0.75)
        let all = mixOKLab(x, y, fractionOfFirst: 1.0)
        let none = mixOKLab(x, y, fractionOfFirst: 0.0)
        let xc = Self.rgba(of: x)
        let yc = Self.rgba(of: y)
        let allC = Self.rgba(of: all)
        let noneC = Self.rgba(of: none)
        #expect(abs(allC.0 - xc.0) < 0.01 && abs(allC.1 - xc.1) < 0.01 && abs(allC.2 - xc.2) < 0.01)
        #expect(abs(noneC.0 - yc.0) < 0.01 && abs(noneC.1 - yc.1) < 0.01 && abs(noneC.2 - yc.2) < 0.01)
    }

    // MARK: - mixWithTransparent

    @Test func mixWithTransparentEqualsOpacity() {
        let c = mixWithTransparent(.red, fractionOfFirst: 0.3)
        let a = Self.rgba(of: c).3
        #expect(abs(a - 0.3) < 0.01)
    }

    // MARK: - fillColor の3分岐

    @Test func fillColorBranches() {
        let tokens = DesignTokens.resolve(palette: .hinoki, theme: .light)
        let low = Color.fillColor(fraction: 0.10, tokens: tokens)   // accent
        let mid = Color.fillColor(fraction: 0.35, tokens: tokens)   // mix
        let high = Color.fillColor(fraction: 0.80, tokens: tokens)  // brand

        let accent = Self.rgba(of: tokens.accent)
        let brand = Self.rgba(of: tokens.brand)
        let lowC = Self.rgba(of: low)
        let highC = Self.rgba(of: high)
        let midC = Self.rgba(of: mid)

        // 低残量は accent と一致
        #expect(abs(lowC.0 - accent.0) < 0.01 && abs(lowC.1 - accent.1) < 0.01 && abs(lowC.2 - accent.2) < 0.01)
        // 高残量は brand と一致
        #expect(abs(highC.0 - brand.0) < 0.01 && abs(highC.1 - brand.1) < 0.01 && abs(highC.2 - brand.2) < 0.01)
        // 中残量は accent でも brand でもない（混色）
        let isAccent = abs(midC.0 - accent.0) < 0.01 && abs(midC.1 - accent.1) < 0.01 && abs(midC.2 - accent.2) < 0.01
        let isBrand = abs(midC.0 - brand.0) < 0.01 && abs(midC.1 - brand.1) < 0.01 && abs(midC.2 - brand.2) < 0.01
        #expect(!isAccent && !isBrand)
    }

    @Test func fillColorBoundaries() {
        let tokens = DesignTokens.resolve(palette: .hinoki, theme: .light)
        let accent = Self.rgba(of: tokens.accent)
        let brand = Self.rgba(of: tokens.brand)
        // f == 0.22 はちょうど accent（<=0.22）
        let at22 = Self.rgba(of: Color.fillColor(fraction: 0.22, tokens: tokens))
        #expect(abs(at22.0 - accent.0) < 0.01)
        // f == 0.46 は brand（>0.45）
        let at46 = Self.rgba(of: Color.fillColor(fraction: 0.46, tokens: tokens))
        #expect(abs(at46.0 - brand.0) < 0.01)
    }

    // MARK: - ヘルパー

    static func rgba(of color: Color) -> (Double, Double, Double, Double) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
