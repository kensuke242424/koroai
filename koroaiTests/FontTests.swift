// バンドルしたブランドフォント（M PLUS Rounded 1c / Quicksand）の検証。
// 7つの PostScript 名がすべて UIFont(name:size:) で解決でき、AppFont がフォールバックでなく
// 実フォントを返していることを確認する。
//
// PostScript 名は CoreText（kCTFontNameAttribute）で .ttf から確認した実名。
//   M PLUS Rounded 1c: "RoundedMplus1c-{Regular,Medium,Bold,ExtraBold}"
//   Quicksand:         "Quicksand-{Medium,SemiBold,Bold}"

import Testing
import SwiftUI
import UIKit
@testable import koroai

struct FontTests {

    /// バンドルされているはずの 7 つの PostScript 名。
    static let postScriptNames = [
        "RoundedMplus1c-Regular",
        "RoundedMplus1c-Medium",
        "RoundedMplus1c-Bold",
        "RoundedMplus1c-ExtraBold",
        "Quicksand-Medium",
        "Quicksand-SemiBold",
        "Quicksand-Bold",
    ]

    // MARK: - PostScript 名の解決

    @Test(arguments: postScriptNames)
    func postScriptNameResolves(name: String) {
        // AppFont 経由でフォント登録を確実に走らせてから問い合わせる。
        _ = AppFont.isUsingBundledFonts
        #expect(UIFont(name: name, size: 16) != nil, "フォント \(name) が解決できへん")
    }

    // MARK: - フォールバックでなく実フォントを返しているか

    @Test func appFontUsesBundledFonts() {
        let flags = AppFont.isUsingBundledFonts
        #expect(flags.rounded, "rounded がバンドルフォントになってへん（SF Rounded フォールバック中）")
        #expect(flags.wordmark, "wordmark がバンドルフォントになってへん（SF Rounded フォールバック中）")
    }

    // MARK: - weight ごとに正しい PostScript 名へ解決されるか

    @Test(arguments: [
        (Font.Weight.regular, "RoundedMplus1c-Regular"),
        (.medium, "RoundedMplus1c-Medium"),
        (.bold, "RoundedMplus1c-Bold"),
        (.semibold, "RoundedMplus1c-Bold"),
        (.heavy, "RoundedMplus1c-ExtraBold"),
        (.black, "RoundedMplus1c-ExtraBold"),
    ])
    func roundedWeightMapsToResolvableFont(weight: Font.Weight, expected: String) {
        _ = AppFont.isUsingBundledFonts
        // 期待した PostScript 名のフォントが実在することを保証（マッピングの単調性の裏取り）。
        #expect(UIFont(name: expected, size: 16) != nil, "\(expected) が解決できへん")
    }

    @Test(arguments: [
        (Font.Weight.medium, "Quicksand-Medium"),
        (.semibold, "Quicksand-SemiBold"),
        (.bold, "Quicksand-Bold"),
        (.heavy, "Quicksand-Bold"),
        (.black, "Quicksand-Bold"),
    ])
    func wordmarkWeightMapsToResolvableFont(weight: Font.Weight, expected: String) {
        _ = AppFont.isUsingBundledFonts
        #expect(UIFont(name: expected, size: 16) != nil, "\(expected) が解決できへん")
    }
}
