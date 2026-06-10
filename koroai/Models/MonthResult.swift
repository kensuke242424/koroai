// 月替わりリザルトのデータと発火判定。全てログ導出（カウンタリセット不要）。
//
// 設計（Step 8 確定判断）:
//  - 月替わりリザルトは全て ConsumptionLog から導出する。月が替われば当月件数は自動で 0 になる。
//  - 発火条件は MonthResultTrigger.evaluate（純関数・now/calendar 注入可）で一元管理する。
//  - 出典: fk-app.jsx の月替わり検知（saved.month != cur ∧ savedCount > 0）を SwiftData ログ基準に作り直したもの。
//
// プロトタイプの月インデックスは 0-index（new Date().getMonth()）だが、本実装は year + month(1-12) を保持し、
// 表示側で「m月」「nextM月」を計算する。

import Foundation

/// 月替わりリザルト1回分のデータ。全てログから導出する。
struct MonthResultData: Equatable {
    /// 対象（＝先月）の年。
    let year: Int
    /// 対象（＝先月）の月（1...12）。
    let month: Int
    /// 対象月の `.ate` 件数（ヒーロー数字・称号の基準）。
    let count: Int
    /// 先々月の `.ate` 件数。先月開始より前に ate ログが1件も無ければ nil（＝「はじめての記録」）。
    let prevCount: Int?
    /// 連続して食べきった月数（対象月＝先月時点で算出）。
    let streak: Int

    /// 対象月のキー（"YYYY-MM"）。二重表示防止の照合に使う。
    var monthKey: String { MonthResultTrigger.monthKey(year: year, month: month) }
}

enum MonthResultTrigger {

    /// 月替わりリザルトを出すべきか判定し、出すなら導出データを返す（純関数）。
    ///
    /// 発火条件（すべて満たすとき返す）:
    ///  1. enabled == true（AppStore.showMonthlyResult）。
    ///  2. lastOpenedAt が non-nil かつ、now とは別の暦月（過去）である＝月をまたいで起動した。
    ///  3. 先月（now の前月）の `.ate` 件数 > 0。
    ///  4. shownFor != 先月キー（"YYYY-MM"）＝まだその月のリザルトを見せていない。
    ///
    /// 返り値:
    ///  - count    = 先月の `.ate` 件数。
    ///  - prevCount = 先々月の `.ate` 件数。ただし先月開始より前に `.ate` が1件も無ければ nil（はじめての記録）。
    ///  - streak   = 先月内の日付を now として monthStreak で算出。
    static func evaluate(
        lastOpenedAt: Date?,
        logs: [ConsumptionLog],
        shownFor: String?,
        enabled: Bool,
        now: Date,
        calendar: Calendar
    ) -> MonthResultData? {
        guard enabled else { return nil }
        guard let lastOpenedAt else { return nil }

        // 2. 暦月が異なり、かつ前回が過去であること。
        let nowComps = calendar.dateComponents([.year, .month], from: now)
        let lastComps = calendar.dateComponents([.year, .month], from: lastOpenedAt)
        guard let ny = nowComps.year, let nm = nowComps.month,
              let ly = lastComps.year, let lm = lastComps.month else { return nil }
        let nowKey = (ny, nm)
        let lastKey = (ly, lm)
        // 同月なら出さない。未来月（時計巻き戻し等）も出さない。
        guard lastKey != nowKey else { return nil }
        guard (ly, lm) < (ny, nm) else { return nil }

        // 先月（now の前月）の年月。
        guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
        let lmc = calendar.dateComponents([.year, .month], from: lastMonthDate)
        guard let pmy = lmc.year, let pmm = lmc.month else { return nil }

        // 先月の月初。
        guard let lastMonthInterval = calendar.dateInterval(
            of: .month,
            for: lastMonthDate
        ) else { return nil }
        let lastMonthStart = lastMonthInterval.start

        // 3. 先月の ate 件数 > 0。
        let count = ateCount(in: lastMonthDate, logs: logs, calendar: calendar)
        guard count > 0 else { return nil }

        // 4. 既にその月のリザルトを見せていれば出さない。
        let key = monthKey(year: pmy, month: pmm)
        guard shownFor != key else { return nil }

        // prevCount: 先々月の ate 件数。ただし「先月開始より前」に ate が1件も無ければ nil（はじめての記録）。
        let hasAteBeforeLastMonth = logs.contains { log in
            log.action == .ate && log.date < lastMonthStart
        }
        let prevCount: Int?
        if hasAteBeforeLastMonth, let prevPrevDate = calendar.date(byAdding: .month, value: -2, to: now) {
            prevCount = ateCount(in: prevPrevDate, logs: logs, calendar: calendar)
        } else {
            prevCount = nil
        }

        // streak: 先月内の日付を now として算出（先月を起点に連続を数える）。
        let streak = Stats.monthStreak(logs: logs, now: lastMonthDate, calendar: calendar)

        return MonthResultData(year: pmy, month: pmm, count: count, prevCount: prevCount, streak: streak)
    }

    /// date と同じ年・月の `.ate` 件数。
    private static func ateCount(in date: Date, logs: [ConsumptionLog], calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return logs.filter { log in
            guard log.action == .ate else { return false }
            let c = calendar.dateComponents([.year, .month], from: log.date)
            return c.year == comps.year && c.month == comps.month
        }.count
    }

    /// "YYYY-MM" 形式の月キー。
    static func monthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }
}
