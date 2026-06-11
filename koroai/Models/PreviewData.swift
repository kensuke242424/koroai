// SwiftUI Preview 用の in-memory コンテナ。SeedData を投入し、達成カードの数字が出るよう ate ログも入れる。
// 本番起動には一切関与しない（Preview / 開発時のみ）。

import Foundation
import SwiftData

enum PreviewData {
    /// SeedData 7品＋ ate ログ12件（今月6・先月4・先々月2）を投入した in-memory コンテナ。
    /// lifetime 12 / 今月6 / 先週2 / 連続3ヶ月 をプレビューでも再現する。
    @MainActor static let container: ModelContainer = {
        let schema = Schema([FoodItem.self, ConsumptionLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        for item in SeedData.previewItems() {
            context.insert(item)
        }
        for log in previewAteLogs() {
            context.insert(log)
        }
        return container
    }()

    /// ふりかえり用の ate ログ12件。今月6（うち前週2）・先月4・先々月2 に分散する。
    /// koroaiApp.seedAteLogs と同じ意図のプレビュー専用版（DEBUG ゲートの外で使えるよう独立実装）。
    @MainActor static func previewAteLogs(now: Date = .now, calendar: Calendar = .current) -> [ConsumptionLog] {
        // 新10セクション（FoodCategory）id。集計はセクション単位なので分布だけ変わり件数は不変。
        let cats = ["meat", "fish", "veg", "mush", "fruit",
                    "dairy", "egg", "tofu", "staple", "deli"]
        var logs: [ConsumptionLog] = []
        var i = 0
        func cat() -> String { defer { i += 1 }; return cats[i % cats.count] }

        let prevWeek = Stats.previousWeekInterval(now: now, calendar: calendar)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

        // 今月: 前週2件
        for off in [1, 2] {
            let d = calendar.date(byAdding: .day, value: off, to: prevWeek.start) ?? prevWeek.start
            logs.append(ConsumptionLog(date: d, catId: cat(), action: .ate))
        }
        // 今月: 直近4件
        for off in [0, 1, 2, 3] {
            let d = calendar.date(byAdding: .day, value: -off, to: now) ?? now
            let safe = d < monthStart ? monthStart : d
            logs.append(ConsumptionLog(date: safe, catId: cat(), action: .ate))
        }
        // 先月4件・先々月2件
        func mid(_ monthsAgo: Int) -> Date {
            guard let md = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { return now }
            var c = calendar.dateComponents([.year, .month], from: md); c.day = 10; c.hour = 12
            return calendar.date(from: c) ?? md
        }
        for off in [0, 2, 4, 6] {
            logs.append(ConsumptionLog(date: calendar.date(byAdding: .day, value: off, to: mid(1)) ?? mid(1), catId: cat(), action: .ate))
        }
        for off in [0, 3] {
            logs.append(ConsumptionLog(date: calendar.date(byAdding: .day, value: off, to: mid(2)) ?? mid(2), catId: cat(), action: .ate))
        }
        return logs
    }
}
