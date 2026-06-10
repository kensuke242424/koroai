// 月カレンダーのグリッド生成（純関数・テスト対象）。
//
// プロトタイプ FKDatePicker のセル生成ロジックを切り出したもの。
// 先頭に「月初の曜日」分だけ nil を詰め、以降 1 日ずつ Date を並べる（日曜始まり）。
// カレンダー（特に firstWeekday / timeZone）を注入できるようにし、テストの決定性を担保する。

import Foundation

enum CalendarGrid {
    /// 指定年月のカレンダーセル列を作る。
    /// - 先頭に月初の曜日（日曜=0 始まり）分の nil を詰める。
    /// - 以降は 1 日ずつ、その月の startOfDay を並べる。
    /// - 戻り値の length = 先頭 nil 数 + その月の日数。
    static func make(year: Int, month: Int, calendar: Calendar = .current) -> [Date?] {
        var firstComp = DateComponents()
        firstComp.year = year
        firstComp.month = month
        firstComp.day = 1
        guard let first = calendar.date(from: firstComp) else { return [] }

        // 月初の曜日（プロトタイプは getDay()＝日曜0）。Calendar.component(.weekday) は 1=日曜なので -1。
        let startWeekday = calendar.component(.weekday, from: first) - 1
        // その月の日数。
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 0

        var cells: [Date?] = Array(repeating: nil, count: startWeekday)
        for d in 0..<daysInMonth {
            cells.append(calendar.date(byAdding: .day, value: d, to: first))
        }
        return cells
    }
}
