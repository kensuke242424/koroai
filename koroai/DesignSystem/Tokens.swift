// カラーパレット定義とテーマ別トークン解決。色は sRGB 16進から生成し、パレット×テーマで一覧化する。

import SwiftUI

// MARK: - Color(hex:) 拡張

extension Color {
    /// sRGB の 24bit 16進（例: 0xB8604A）から Color を生成する。
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Palette

/// パレット（配色テーマ）。既定は hinoki。
enum Palette: String, CaseIterable, Identifiable {
    case hinoki
    case clay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hinoki: return "ナチュラル"
        case .clay: return "あたたか"
        }
    }
}

// MARK: - ResolvedTheme

/// 解決済みテーマ。`dark` は設定 UI からは選べないが、トークン定義として保持する（Theme.swift 参照）。
enum ResolvedTheme {
    case light
    case dark
    case night
}

// MARK: - DesignTokens

/// 1テーマ分の色トークン一式。`DesignTokens.resolve(palette:theme:)` で取得する。
struct DesignTokens {
    let bg: Color
    let bg2: Color
    let surface: Color
    let surface2: Color
    let text: Color
    let textSec: Color
    let textTer: Color
    let hair: Color
    let shadow: Color
    let brand: Color
    let brandInk: Color
    let brandSoft: Color
    let accent: Color

    /// パレットとテーマからトークンを解決する。
    static func resolve(palette: Palette, theme: ResolvedTheme) -> DesignTokens {
        switch (palette, theme) {
        case (.hinoki, .light): return hinokiLight
        case (.hinoki, .dark): return hinokiDark
        case (.hinoki, .night): return hinokiNight
        case (.clay, .light): return clayLight
        case (.clay, .dark): return clayDark
        case (.clay, .night): return clayNight
        }
    }
}

// MARK: - hinoki

private extension DesignTokens {
    static let hinokiLight = DesignTokens(
        bg: Color(hex: 0xf3ede2),
        bg2: Color(hex: 0xfbf7f0),
        surface: Color(hex: 0xfffdf8),
        surface2: Color(hex: 0xf1ebdf),
        text: Color(hex: 0x3a342b),
        textSec: Color(hex: 0x8c8273),
        textTer: Color(hex: 0xb3aa98),
        hair: Color(hex: 0x46371e, opacity: 0.09),
        shadow: Color(hex: 0x504128, opacity: 0.10),
        brand: Color(hex: 0x6f8f6a),
        brandInk: Color(hex: 0x41614a),
        brandSoft: Color(hex: 0xe7eedd),
        accent: Color(hex: 0xb8604a)
    )

    static let hinokiDark = DesignTokens(
        bg: Color(hex: 0x2b251c),
        bg2: Color(hex: 0x332c22),
        surface: Color(hex: 0x3c352b),
        surface2: Color(hex: 0x473f33),
        text: Color(hex: 0xf3ede2),
        textSec: Color(hex: 0xc2b69b),
        textTer: Color(hex: 0x948871),
        hair: Color(hex: 0xfff3d8, opacity: 0.12),
        shadow: Color(hex: 0x000000, opacity: 0.24),
        brand: Color(hex: 0xa4c098),
        brandInk: Color(hex: 0xdfebd5),
        brandSoft: Color(hex: 0x3a442d),
        accent: Color(hex: 0xe69a7c)
    )

    static let hinokiNight = DesignTokens(
        bg: Color(hex: 0xddc9a6),
        bg2: Color(hex: 0xe5d3b3),
        surface: Color(hex: 0xefe1c7),
        surface2: Color(hex: 0xe3d2b0),
        text: Color(hex: 0x3a342b),
        textSec: Color(hex: 0x7b7059),
        textTer: Color(hex: 0xa4977e),
        hair: Color(hex: 0x46371e, opacity: 0.13),
        shadow: Color(hex: 0x504128, opacity: 0.16),
        brand: Color(hex: 0x5e7c4e),
        brandInk: Color(hex: 0x3c5a40),
        brandSoft: Color(hex: 0xd6dcb2),
        accent: Color(hex: 0xbd5e36)
    )
}

// MARK: - clay

private extension DesignTokens {
    static let clayLight = DesignTokens(
        bg: Color(hex: 0xf4ece2),
        bg2: Color(hex: 0xfbf6ee),
        surface: Color(hex: 0xfffcf6),
        surface2: Color(hex: 0xf1e8da),
        text: Color(hex: 0x3c332a),
        textSec: Color(hex: 0x8e8273),
        textTer: Color(hex: 0xb6aa97),
        hair: Color(hex: 0x503219, opacity: 0.10),
        shadow: Color(hex: 0x5a3c23, opacity: 0.11),
        brand: Color(hex: 0x7a9a64),
        brandInk: Color(hex: 0x4a6440),
        brandSoft: Color(hex: 0xe9efdc),
        accent: Color(hex: 0xc06a3f)
    )

    static let clayDark = DesignTokens(
        bg: Color(hex: 0x2c251a),
        bg2: Color(hex: 0x342d21),
        surface: Color(hex: 0x3d352a),
        surface2: Color(hex: 0x484033),
        text: Color(hex: 0xf4eddf),
        textSec: Color(hex: 0xc3b79a),
        textTer: Color(hex: 0x95896f),
        hair: Color(hex: 0xfff0d2, opacity: 0.12),
        shadow: Color(hex: 0x000000, opacity: 0.24),
        brand: Color(hex: 0xaec894),
        brandInk: Color(hex: 0xe2edd3),
        brandSoft: Color(hex: 0x3c4529),
        accent: Color(hex: 0xec9e6f)
    )

    static let clayNight = DesignTokens(
        bg: Color(hex: 0xddc8a2),
        bg2: Color(hex: 0xe5d2af),
        surface: Color(hex: 0xf0e1c4),
        surface2: Color(hex: 0xe4d1ab),
        text: Color(hex: 0x3c332a),
        textSec: Color(hex: 0x7d7159),
        textTer: Color(hex: 0xa6987d),
        hair: Color(hex: 0x503219, opacity: 0.14),
        shadow: Color(hex: 0x5a3c23, opacity: 0.16),
        brand: Color(hex: 0x66834e),
        brandInk: Color(hex: 0x46603c),
        brandSoft: Color(hex: 0xd8dcaf),
        accent: Color(hex: 0xc2602f)
    )
}
