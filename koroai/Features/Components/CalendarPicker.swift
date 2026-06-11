// もち日数をカレンダーで選ぶピッカー。プロトタイプ FKDatePicker の移植。
//
// surface 角丸16。ヘッダー（‹ › ナビ・「YYYY年 M月」fs14.5 w800）／曜日行／日セル／フッター。
// ステッパー⇄カレンダーは days を単一の source of truth とする双方向同期:
//   選択日 = today + max(0, days) から導出。日付タップ → 暦日差を days に書き戻す。
// 過去日は選択不可（opacity 0.32・disabled）。月ナビは自由に移動できる（過去月へ行っても過去日は選べないだけ）。
// 月ビュー(vm)は内部 @State。days が変わったら選択日を内包する月へ追従する。

import SwiftUI

struct CalendarPicker: View {
    @Binding var days: Int
    /// 今日（テスト・プレビュー注入用）。
    var now: Date = .now
    var calendar: Calendar = .current

    @Environment(\.tokens) private var tokens

    // 土曜の固定色。出典: fk-flows.jsx FKDatePicker 曜日行 '#5f93a2'（プロトタイプ準拠の固定色）。
    private static let saturdayColor = Color(hex: 0x5f93a2)

    private static let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    // 表示中の月（その月の 1 日の startOfDay）。
    @State private var vmMonth: Date = .now

    private var today: Date { calendar.startOfDay(for: now) }
    private var selected: Date {
        calendar.date(byAdding: .day, value: max(0, days), to: today) ?? today
    }

    private var navBg: Color { ControlColors.neutral(isDark: tokens.colorSchemeIsDark) }

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayRow
            grid
            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 13)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { syncMonthToSelection() }
        .onChange(of: days) { _, _ in syncMonthToSelection() }
    }

    // MARK: - ヘッダー（月ナビ）

    private var header: some View {
        let comps = calendar.dateComponents([.year, .month], from: vmMonth)
        return HStack {
            navButton("chevron.left") { shiftMonth(-1) }
            Spacer()
            Text("\(verbatimYear(comps.year ?? 0))年 \(comps.month ?? 0)月")
                .font(AppFont.rounded(size: 14.5, weight: .heavy))
                .foregroundStyle(tokens.text)
            Spacer()
            navButton("chevron.right") { shiftMonth(1) }
        }
        .padding(.bottom, 8)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tokens.text)
                .frame(width: 30, height: 30)
                .background(navBg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "chevron.left" ? "前の月" : "次の月")
    }

    // MARK: - 曜日行

    private var weekdayRow: some View {
        HStack(spacing: 2) {
            ForEach(Array(Self.weekdayLabels.enumerated()), id: \.offset) { i, w in
                Text(w)
                    .font(AppFont.rounded(size: 10.5, weight: .bold))
                    .foregroundStyle(weekdayColor(i))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 3)
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return tokens.accent }      // 日
        if index == 6 { return Self.saturdayColor }  // 土
        return tokens.textTer
    }

    // MARK: - 日セルグリッド

    private var grid: some View {
        let comps = calendar.dateComponents([.year, .month], from: vmMonth)
        let cells = CalendarGrid.make(year: comps.year ?? 0, month: comps.month ?? 0, calendar: calendar)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                dayCell(cell)
            }
        }
    }

    /// 日セルの固定高。aspectRatio(1) だと Text セルは内容高に縮む一方、
    /// 空白セル（Color.clear）は正方形いっぱいに広がり、空白を含む週だけ
    /// 行が高くなってしまうため、全セルを同じ高さに固定する。
    private static let cellHeight: CGFloat = 34

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let diff = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
            let past = diff < 0
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isSel = calendar.isDate(date, inSameDayAs: selected)
            Button {
                if !past { days = diff }
            } label: {
                Text("\(calendar.component(.day, from: date))")
                    .font(AppFont.rounded(size: 13, weight: isSel || isToday ? .heavy : .semibold))
                    .foregroundStyle(isSel ? .white : (past ? tokens.textTer : tokens.text))
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.cellHeight)
                    .background {
                        if isSel {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tokens.accent)
                        } else if isToday {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(tokens.accent, lineWidth: 1.5)
                        }
                    }
                    .opacity(past ? 0.32 : 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(past)
        } else {
            Color.clear.frame(height: Self.cellHeight)
        }
    }

    // MARK: - フッター

    private var footer: some View {
        Text(footerText)
            .font(AppFont.rounded(size: 12, weight: .bold))
            .foregroundStyle(tokens.textSec)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    private var footerText: String {
        if days <= 0 { return "今日まで" }
        let comps = calendar.dateComponents([.month, .day, .weekday], from: selected)
        let wd = Self.weekdayLabels[(comps.weekday ?? 1) - 1]
        return "\(comps.month ?? 0)/\(comps.day ?? 0)（\(wd)）まで・あと\(days)日"
    }

    // MARK: - 月追従

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: vmMonth) {
            vmMonth = startOfMonth(next)
        }
    }

    /// 選択日を内包する月へ vm を合わせる（days 変更時）。
    private func syncMonthToSelection() {
        vmMonth = startOfMonth(selected)
    }

    private func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// 年は桁区切りを入れない（"2,026年" を避ける）。
    private func verbatimYear(_ year: Int) -> String {
        String(year)
    }
}
