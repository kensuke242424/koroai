// もち日数ステッパー。プロトタイプ FKStepper の移植。
//
// −／＋ ボタンは 44pt 角丸14・中立背景・fs24。中央表示は最小幅92:
//   days≤0 →「今日」(fs22 w800) / それ以外 →「あと」(fs14 textSec)+N(fs30 w800)+「日」(fs16 textSec)。
// −ボタンは 0 で下限クランプ（過去日へは行けない）。

import SwiftUI

struct DaysStepper: View {
    @Binding var days: Int

    @Environment(\.tokens) private var tokens

    private var btnBg: Color { ControlColors.neutral(isDark: tokens.colorSchemeIsDark) }

    var body: some View {
        HStack(spacing: 14) {
            button("−") { days = max(0, days - 1) }
            label
                .frame(minWidth: 92)
            button("+") { days += 1 }
        }
    }

    private func button(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(AppFont.rounded(size: 24, weight: .bold))
                .foregroundStyle(tokens.text)
                .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
                .background(btnBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var label: some View {
        if days <= 0 {
            Text("今日")
                .font(AppFont.rounded(size: 22, weight: .heavy))
                .foregroundStyle(tokens.text)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("あと")
                    .font(AppFont.rounded(size: 14, weight: .bold))
                    .foregroundStyle(tokens.textSec)
                Text("\(days)")
                    .font(AppFont.rounded(size: 30, weight: .heavy))
                    .foregroundStyle(tokens.text)
                Text("日")
                    .font(AppFont.rounded(size: 16, weight: .bold))
                    .foregroundStyle(tokens.textSec)
            }
        }
    }
}
