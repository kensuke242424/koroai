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
}
