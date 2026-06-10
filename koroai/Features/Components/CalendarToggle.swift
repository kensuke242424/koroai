// 「カレンダーで日付を選ぶ」トグル。プロトタイプ FKCalToggle の移植。
//
// 全幅・透明背景・brandInk・fs13.5 w800・SF Symbols "calendar" アイコン（絵文字不使用）。
// 開いていれば「カレンダーを閉じる」/ 閉じていれば「カレンダーで日付を選ぶ」。

import SwiftUI

struct CalendarToggle: View {
    @Binding var isOpen: Bool

    @Environment(\.tokens) private var tokens

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                Text(isOpen ? "カレンダーを閉じる" : "カレンダーで日付を選ぶ")
                    .font(AppFont.rounded(size: 13.5, weight: .heavy))
            }
            .foregroundStyle(tokens.brandInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Layout.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
