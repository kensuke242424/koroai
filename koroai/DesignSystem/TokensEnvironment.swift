// 解決済みトークン／テーマを Environment 経由で配る。
//
// ルート（ContentView）で AppStore.themeMode × OS の colorScheme から ResolvedTheme を解決し、
// DesignTokens を一度だけ計算して流し込む。各 View は @Environment(\.tokens) で参照するだけにし、
// パレット解決を画面側に散らさない（CLAUDE.md: トークンは DesignSystem に一元化）。

import SwiftUI

private struct TokensKey: EnvironmentKey {
    // 既定は hinoki/light（プレビュー・未注入時のフォールバック）。
    static let defaultValue: DesignTokens = .resolve(palette: .hinoki, theme: .light)
}

private struct ResolvedThemeKey: EnvironmentKey {
    static let defaultValue: ResolvedTheme = .light
}

extension EnvironmentValues {
    var tokens: DesignTokens {
        get { self[TokensKey.self] }
        set { self[TokensKey.self] = newValue }
    }

    var resolvedTheme: ResolvedTheme {
        get { self[ResolvedThemeKey.self] }
        set { self[ResolvedThemeKey.self] = newValue }
    }
}
