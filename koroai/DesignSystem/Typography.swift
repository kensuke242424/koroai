// フォント。和文 M PLUS Rounded 1c / 欧文 Quicksand をバンドルから使い、未バンドルなら SF Rounded にフォールバック。
//
// 登録方式: Info.plist の UIAppFonts は使わず、起動時に1度だけ CTFontManagerRegisterFontsForURLs で
//   プログラム登録する（アプリ・ユニットテスト・SwiftUI Preview のどれでも効くように）。
//   登録は fontsRegistered を hasRounded/hasWordmark の判定より前に必ず評価することで保証する。
//
// PostScript 名は CoreText（kCTFontNameAttribute）で実機の .ttf から確認した実名を使う。
//   M PLUS Rounded 1c の実ファミリーは "Rounded Mplus 1c"、PostScript 名は "RoundedMplus1c-*"。
//   Quicksand は可変フォントを Medium/SemiBold/Bold へ静的インスタンス化したもの。

import SwiftUI
import UIKit

enum AppFont {
    // MARK: - フォント登録（起動時に1度だけ・最初のフォント問い合わせより前に必ず走る）

    /// バンドル内の .ttf をすべてプロセスに登録する。値の評価自体が登録のトリガ。
    /// hasRounded/hasWordmark の closure 先頭で `_ = fontsRegistered` を呼ぶことで、
    /// どの実行コンテキスト（アプリ / テスト / Preview）でも判定前に登録が完了する。
    private static let fontsRegistered: Bool = {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil),
              !urls.isEmpty else {
            return false
        }
        CTFontManagerRegisterFontsForURLs(urls as CFArray, .process, nil)
        return true
    }()

    // MARK: - バンドル有無の判定（起動時に1度だけ評価してキャッシュ）

    /// M PLUS Rounded 1c（和文・全体用）がバンドル済みで解決できるか。
    private static let hasRounded: Bool = {
        _ = fontsRegistered
        return UIFont(name: roundedPostScriptName(for: .regular), size: 12) != nil
    }()

    /// Quicksand（欧文ワードマーク用）がバンドル済みで解決できるか。
    private static let hasWordmark: Bool = {
        _ = fontsRegistered
        return UIFont(name: wordmarkPostScriptName(for: .medium), size: 12) != nil
    }()

    // MARK: - PostScript 名マッピング

    /// M PLUS Rounded 1c の weight → PostScript 名（保有ウェイト 400/500/700/800 に丸める）。
    private static func roundedPostScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .heavy, .black:
            return "RoundedMplus1c-ExtraBold"
        case .semibold, .bold:
            return "RoundedMplus1c-Bold"
        case .medium:
            return "RoundedMplus1c-Medium"
        default:
            return "RoundedMplus1c-Regular"
        }
    }

    /// Quicksand の weight → PostScript 名（保有ウェイト Medium/SemiBold/Bold）。
    private static func wordmarkPostScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            return "Quicksand-Bold"
        case .semibold:
            return "Quicksand-SemiBold"
        default:
            return "Quicksand-Medium"
        }
    }

    // MARK: - 公開 API

    /// 和文・全体用フォント。バンドル済みなら M PLUS Rounded 1c、なければ SF Rounded。
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if hasRounded {
            return .custom(roundedPostScriptName(for: weight), size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    /// 欧文ワードマーク用フォント。バンドル済みなら Quicksand、なければ SF Rounded。
    static func wordmark(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if hasWordmark {
            return .custom(wordmarkPostScriptName(for: weight), size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - 検証用フラグ（テスト・診断用）

    /// バンドルフォント（フォールバックでない実フォント）を使っているか。
    static var isUsingBundledFonts: (rounded: Bool, wordmark: Bool) {
        (hasRounded, hasWordmark)
    }
}
