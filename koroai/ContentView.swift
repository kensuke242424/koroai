// ルート View。テーマを解決してトークンを Environment に流し込み、ホームを出すだけの薄い層。
//
// AppStore.themeMode × OS の colorScheme から ResolvedTheme / DesignTokens を解決する。
// パレットは AppStore.palette（既定 hinoki）。トースト中枢はここで生成して配る。

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.modelContext) private var context
    @State private var toastCenter = ToastCenter()

    private var resolvedTheme: ResolvedTheme {
        store.themeMode.resolved(with: systemColorScheme)
    }

    private var tokens: DesignTokens {
        DesignTokens.resolve(palette: store.palette, theme: resolvedTheme)
    }

    /// 設定「使い方ガイド」からの再表示。onboarded 済みでも一時的にオンボーディングを出す。
    @State private var guideReplay = false

    var body: some View {
        Group {
            if !store.onboarded || guideReplay {
                OnboardingScreen { catIds in
                    OnboardingActions.seedSelected(catIds, context: context)
                    store.onboarded = true
                    guideReplay = false
                }
            } else {
                HomeView(onReplayGuide: { guideReplay = true })
            }
        }
        .environment(\.tokens, tokens)
        .environment(\.resolvedTheme, resolvedTheme)
        .environment(toastCenter)
        .background(tokens.bg.ignoresSafeArea())
        #if DEBUG
        .onAppear {
            let args = CommandLine.arguments
            // スクショ用: -openOnboarding でオンボーディングを必ず表示する。
            if args.contains("-openOnboarding") {
                store.onboarded = false
            }
            // 復帰／月替わりリザルトのスクショはホーム（onboarded 済み）が前提。
            if args.contains("-openReturn") || args.contains("-openMonthResult") {
                store.onboarded = true
            }
        }
        #endif
    }
}

#Preview {
    let store = AppStore()
    store.onboarded = true
    return ContentView()
        .environment(store)
        .modelContainer(PreviewData.container)
}
