// フォント。和文 M PLUS Rounded 1c / 欧文 Quicksand をバンドル時に使い、未バンドルなら SF Rounded にフォールバック。
//
// TODO(フォントバンドル時): Fonts/ に .otf/.ttf を置き、Info.plist の UIAppFonts に
//   ファイル名を列挙して登録する。PostScript 名が一致すれば下の判定が自動で true になり差し替わる。

import SwiftUI
import UIKit

enum AppFont {
    // MARK: - バンドル有無の判定（起動時に1度だけ評価してキャッシュ）

    /// M PLUS Rounded 1c（和文・全体用）がバンドル済みか。
    private static let hasRounded: Bool =
        UIFont(name: "MPLUSRounded1c-Regular", size: 12) != nil

    /// Quicksand（欧文ワードマーク用）がバンドル済みか。
    private static let hasWordmark: Bool =
        UIFont(name: "Quicksand-Medium", size: 12) != nil

    // MARK: - PostScript 名マッピング

    /// M PLUS Rounded 1c の weight → PostScript 名（保有ウェイト 400/500/700/800 に丸める）。
    private static func roundedPostScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .heavy, .black:
            return "MPLUSRounded1c-ExtraBold"
        case .semibold, .bold:
            return "MPLUSRounded1c-Bold"
        case .medium:
            return "MPLUSRounded1c-Medium"
        default:
            return "MPLUSRounded1c-Regular"
        }
    }

    /// Quicksand の weight → PostScript 名。
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
}
