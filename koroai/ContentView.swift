// ルート View。テーマを解決してトークンを Environment に流し込み、ホームを出すだけの薄い層。
//
// AppStore.themeMode × OS の colorScheme から ResolvedTheme / DesignTokens を解決する。
// パレットは AppStore.palette（既定 hinoki）。トースト中枢はここで生成して配る。

import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var toastCenter = ToastCenter()

    private var resolvedTheme: ResolvedTheme {
        store.themeMode.resolved(with: systemColorScheme)
    }

    private var tokens: DesignTokens {
        DesignTokens.resolve(palette: store.palette, theme: resolvedTheme)
    }

    var body: some View {
        HomeView()
            .environment(\.tokens, tokens)
            .environment(\.resolvedTheme, resolvedTheme)
            .environment(toastCenter)
            .background(tokens.bg.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
        .modelContainer(PreviewData.container)
}
