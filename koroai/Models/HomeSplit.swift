// ホーム（案C）の食材分割。プロトタイプ fkSplit + FKHomeC の純関数移植。
//
// fkSplit: hero = perishable && daysLeft<=6 / plenty = それ以外。
//   非生鮮（perishable=false）は daysLeft が小さくても plenty 行き（プロトタイプ仕様）。
//   hero は daysLeft 昇順 → purchasedAt 昇順。plenty は daysLeft 昇順。
// hero のうち daysLeft<=0（期限が今日まで・期限切れ含む）を urgent（きょうの食べ頃）、
//   daysLeft>0 を calm（今週の食材）。calm は daysLeft 昇順で並べ直す。
//   ※旧仕様は urgent=daysLeft<=2。ユーザー指定（2026-06）で「今日まで」に変更。
//
// 残日数は保存しないため、分割のたびに now/calendar から算出する。テストのため両方を注入できる。

import Foundation

/// 案C ホームの分割結果。
struct HomeSplit {
    /// きょうの食べ頃（期限が今日まで＝daysLeft<=0 の生鮮）。daysLeft 昇順 → purchasedAt 昇順。
    let urgent: [FoodItem]
    /// 今週の食材（残1〜6日の生鮮）。daysLeft 昇順。
    let calm: [FoodItem]
    /// ゆとりあり（それ以外＝非生鮮 or 残7日以上の生鮮）。daysLeft 昇順。
    let plenty: [FoodItem]

    /// 生鮮で食べ頃が近い（hero 全体＝urgent + calm）が1件以上あるか。達成カード表示条件に使う。
    var hasHero: Bool { !urgent.isEmpty || !calm.isEmpty }
    /// 冷蔵庫の総品数。
    var totalCount: Int { urgent.count + calm.count + plenty.count }
    /// 今日以下（daysLeft<=0）の hero があるか。「今朝のまとめ」チップの未読ドット判定に使う。
    var hasDueToday: Bool { urgent.contains { $0.daysLeft(now: dueNow, calendar: dueCalendar) <= 0 } }

    // hasDueToday の判定に使う now/calendar を保持（split で同じ値を使うため）。
    fileprivate let dueNow: Date
    fileprivate let dueCalendar: Calendar
}

enum HomeSplitter {
    /// hero/calm/urgent/plenty に分割する純関数。
    static func split(items: [FoodItem], now: Date = .now, calendar: Calendar = .current) -> HomeSplit {
        func days(_ it: FoodItem) -> Int { it.daysLeft(now: now, calendar: calendar) }

        var hero: [FoodItem] = []
        var plenty: [FoodItem] = []
        for it in items {
            if it.perishable && days(it) <= 6 {
                hero.append(it)
            } else {
                plenty.append(it)
            }
        }

        // hero: daysLeft 昇順 → purchasedAt 昇順
        hero.sort { a, b in
            let da = days(a), db = days(b)
            if da != db { return da < db }
            return a.purchasedAt < b.purchasedAt
        }
        // plenty: daysLeft 昇順
        plenty.sort { days($0) < days($1) }

        // きょうの食べ頃 = 期限が今日まで（daysLeft<=0・期限切れ含む）。それ以外の hero は今週の食材へ。
        let urgent = hero.filter { days($0) <= 0 }
        let calm = hero.filter { days($0) > 0 }.sorted { days($0) < days($1) }

        return HomeSplit(urgent: urgent, calm: calm, plenty: plenty, dueNow: now, dueCalendar: calendar)
    }
}
