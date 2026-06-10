// テーマモード（OS設定/ライト/ナイト）と、OS の ColorScheme を加味した解決ロジック。

import SwiftUI

/// ユーザーが選べるテーマモード。既定は system。
/// 注意: ダーク（`ResolvedTheme.dark`）は UI からは選ばせない。OS がダークのときは「ナイト」を当てる。
enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "OS設定"
        case .light: return "ライト"
        case .night: return "ナイト"
        }
    }

    /// OS の ColorScheme を加味してテーマを解決する（仕様確定・ブレ禁止）。
    /// - .light → .light
    /// - .night → .night
    /// - .system → OS がダークなら .night、それ以外は .light（OSダーク時は dark ではなく night を当てる）
    func resolved(with systemColorScheme: ColorScheme) -> ResolvedTheme {
        switch self {
        case .light:
            return .light
        case .night:
            return .night
        case .system:
            return systemColorScheme == .dark ? .night : .light
        }
    }
}

extension ResolvedTheme {
    /// urgency のダークバリアント判定などに使う。dark のときだけ true。
    /// （night は明るい紙テイストの暗所モードなので light 系として扱う）
    var isDark: Bool {
        self == .dark
    }
}
