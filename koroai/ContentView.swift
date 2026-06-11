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
                // ふりかえり等の push 遷移用に NavigationStack を張る（ホーム自身はナビバー非表示）。
                NavigationStack {
                    HomeView(onReplayGuide: { guideReplay = true })
                }
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
            // ホーム前提のスクショ用フックは onboarded 済みにしてから出す。
            let homeBasedHooks = [
                "-openReturn", "-openMonthResult", "-openEditFirst", "-openAddSheet",
                "-openAddConfirm", "-openSettings", "-openReview",
                "-openDigest", "-scrollHome", "-autoAddOne",
            ]
            if homeBasedHooks.contains(where: args.contains) {
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
