// レイアウトの定数。間隔（8基調）・角丸・影・最小タップ領域。

import SwiftUI

/// 間隔スケール。仕様の 6/7/8/10/12/14/18/22/26 に対応。
/// 7 は命名せず、使用箇所が出たら直値（7）とコメントで対応する。
enum Spacing {
    static let xs: CGFloat = 6
    static let s: CGFloat = 8
    static let sm: CGFloat = 10
    static let m: CGFloat = 12
    static let ml: CGFloat = 14
    static let l: CGFloat = 18
    static let xl: CGFloat = 22
    static let xxl: CGFloat = 26
}

/// 角丸。
enum Radius {
    static let cardCompact: CGFloat = 12
    static let card: CGFloat = 14
    static let button: CGFloat = 14
    static let buttonSmall: CGFloat = 13
    static let sheet: CGFloat = 22
    static let tile: CGFloat = 20
}

/// 影。`.shadow(color:radius:x:y:)` にそのまま展開できるタプル。
enum Shadows {
    /// カード影。CSS の `0 6px 18px rgba(40,30,12,0.08)` 相当。
    static let card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        color: Color(.sRGB, red: 40 / 255, green: 30 / 255, blue: 12 / 255, opacity: 0.08),
        radius: 9,
        x: 0,
        y: 6
    )

    /// シート影。カードより強め。
    static let sheet: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        color: Color(.sRGB, red: 40 / 255, green: 30 / 255, blue: 12 / 255, opacity: 0.16),
        radius: 16,
        x: 0,
        y: 10
    )
}

/// 最低タップ領域（44pt）。
enum Layout {
    static let minTapTarget: CGFloat = 44
}
