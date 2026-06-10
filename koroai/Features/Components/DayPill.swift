// 残日数バッジ。Urgency.colors + Tone.dayLabel。プロトタイプ FKDayPill の移植。
//
// md: fs14 / pad 縦5横12 / sm: fs12.5 / pad 縦3横9。先頭に 6pt の solid 色ドット。Capsule・w700。

import SwiftUI

struct DayPill: View {
    let daysLeft: Int
    var size: Size = .md

    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store

    enum Size { case md, sm }

    private var colors: UrgencyColors {
        Urgency.colors(daysLeft: daysLeft, isDark: theme.isDark)
    }

    private var fontSize: CGFloat { size == .sm ? 12.5 : 14 }
    private var vPad: CGFloat { size == .sm ? 3 : 5 }
    private var hPad: CGFloat { size == .sm ? 9 : 12 }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(colors.solid)
                .frame(width: 6, height: 6)
            Text(Tone.dayLabel(daysLeft: daysLeft, tone: store.tone))
                .font(AppFont.rounded(size: fontSize, weight: .bold))
                .foregroundStyle(colors.pillFg)
                .lineLimit(1)
        }
        .padding(.vertical, vPad)
        .padding(.horizontal, hPad)
        .background(colors.pillBg, in: Capsule())
    }
}
