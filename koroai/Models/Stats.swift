// 食べきり集計の導出。カウンタを直持ちせず ConsumptionLog のクエリ結果から算出する純関数群。
//
// 達成カードの数字は「当月の .ate 件数」。これは記録ログから毎回数えることで、
// 記録の追加・取り消しが常に集計と整合する（CLAUDE.md の方針）。

import Foundation

enum Stats {
    /// now と同じ年・同じ暦月の `.ate` 件数。`.tossed` は数えない。純関数。
    static func monthlyAteCount(logs: [ConsumptionLog], now: Date = .now, calendar: Calendar = .current) -> Int {
        let nowComps = calendar.dateComponents([.year, .month], from: now)
        return logs.filter { log in
            guard log.action == .ate else { return false }
            let c = calendar.dateComponents([.year, .month], from: log.date)
            return c.year == nowComps.year && c.month == nowComps.month
        }.count
    }

    /// 通算の `.ate` 件数（全期間）。`.tossed` は数えない。純関数。
    static func lifetimeAteCount(logs: [ConsumptionLog]) -> Int {
        logs.filter { $0.action == .ate }.count
    }

    /// now の属する週の「1つ前」の暦週の DateInterval。
    /// 週境界は calendar.firstWeekday に従う（Asia/Tokyo の Gregorian は既定で日曜始まり）。
    static func previousWeekInterval(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        // 今週の頭を求め、そこから1週間遡った区間を「先週」とする。
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        return DateInterval(start: prevWeekStart, end: thisWeekStart)
    }

    /// 指定区間に含まれる `.ate` 件数。`.tossed` は数えない。純関数。
    /// 区間は [start, end)（end は含まない＝DateInterval.contains の挙動に合わせる）。
    static func ateCount(logs: [ConsumptionLog], in interval: DateInterval) -> Int {
        logs.filter { log in
            guard log.action == .ate else { return false }
            // DateInterval.contains は end を含むため、end ちょうどは除外する（[start, end) にする）。
            return log.date >= interval.start && log.date < interval.end
        }.count
    }

    /// 連続して食べきった月数。記録ログから導出（カウンタは持たない）。
    ///
    /// - 当月に `.ate` があれば当月を含めて過去へ連続カウントする。
    /// - 当月が 0 件でも、先月から連続が成立していれば streak は維持する
    ///   （当月途中なら未記録なだけ。先月を起点に遡って数える）。
    /// - どこにも `.ate` が無ければ 0。
    static func monthStreak(logs: [ConsumptionLog], now: Date = .now, calendar: Calendar = .current) -> Int {
        // ate を年月キー（"YYYY-MM" 相当の比較可能なタプル）の集合にする。
        let ateMonths: Set<MonthKey> = Set(
            logs.compactMap { log -> MonthKey? in
                guard log.action == .ate else { return nil }
                let c = calendar.dateComponents([.year, .month], from: log.date)
                guard let y = c.year, let m = c.month else { return nil }
                return MonthKey(year: y, month: m)
            }
        )
        guard !ateMonths.isEmpty else { return 0 }

        // 数え始める月: 当月に ate があれば当月、無ければ先月（当月途中の未記録を許容）。
        let nowComps = calendar.dateComponents([.year, .month], from: now)
        guard let ny = nowComps.year, let nm = nowComps.month else { return 0 }
        let current = MonthKey(year: ny, month: nm)

        var cursor: MonthKey = ateMonths.contains(current) ? current : current.previous()
        var streak = 0
        while ateMonths.contains(cursor) {
            streak += 1
            cursor = cursor.previous()
        }
        return streak
    }

    /// 年・月を比較・前進できる軽量キー。streak の連続判定に使う。
    struct MonthKey: Hashable {
        let year: Int
        let month: Int

        /// 1つ前の月（年跨ぎを処理）。
        func previous() -> MonthKey {
            if month == 1 { return MonthKey(year: year - 1, month: 12) }
            return MonthKey(year: year, month: month - 1)
        }
    }
}
