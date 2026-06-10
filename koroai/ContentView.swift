// Step 1 のトークン動作確認用スモークテスト画面。
// Step 3 で確定版ホーム（ヒーローカード＋今週の食材リスト）に置き換える予定。

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var systemColorScheme

    private let palette: Palette = .hinoki
    private let tone: Tone = .gentle

    private var theme: ResolvedTheme {
        ThemeMode.system.resolved(with: systemColorScheme)
    }

    private var tokens: DesignTokens {
        DesignTokens.resolve(palette: palette, theme: theme)
    }

    var body: some View {
        let t = tokens
        return VStack(alignment: .leading, spacing: Spacing.l) {
            Text("ころあい")
                .font(AppFont.rounded(size: 32, weight: .bold))
                .foregroundStyle(t.text)

            Text(tone.copy.eatThisWeek)
                .font(AppFont.rounded(size: 16, weight: .medium))
                .foregroundStyle(t.textSec)

            VStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(0...7, id: \.self) { days in
                    dayPill(daysLeft: days)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.xl)
        .background(t.bg)
    }

    /// urgency の色＋トーン別ラベルを確認するためのカプセル。
    private func dayPill(daysLeft: Int) -> some View {
        let u = Urgency.colors(daysLeft: daysLeft, isDark: theme.isDark)
        return HStack(spacing: Spacing.s) {
            Circle()
                .fill(u.solid)
                .frame(width: 10, height: 10)
            Text(Tone.dayLabel(daysLeft: daysLeft, tone: tone))
                .font(AppFont.rounded(size: 14, weight: .medium))
                .foregroundStyle(u.pillFg)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: Layout.minTapTarget, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(u.pillBg, in: Capsule())
    }
}

#Preview {
    ContentView()
}
