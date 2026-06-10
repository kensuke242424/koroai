import SwiftUI
import SwiftData

@main
struct koroaiApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(container)
    }

    /// 永続コンテナ。FoodItem / ConsumptionLog を扱う。
    /// DEBUG かつ起動引数 "-seedPreviewData" のときだけ、空 DB に SeedData を投入する
    /// （プレビュー／スクショ用。本番起動には影響させない）。
    /// 注意: computed にすると body 再評価のたびに別コンテナが生成されうるため、stored で1つに固定する。
    private let container: ModelContainer = Self.makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([FoodItem.self, ConsumptionLog.self])
        do {
            let container = try ModelContainer(for: schema)
            #if DEBUG
            if CommandLine.arguments.contains("-seedPreviewData") {
                seedIfEmpty(container)
            }
            #endif
            return container
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }

    #if DEBUG
    /// 空 DB のときだけシードを投入する（既存データは壊さない）。
    @MainActor
    private static func seedIfEmpty(_ container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        guard existing.isEmpty else { return }
        for item in SeedData.previewItems() {
            context.insert(item)
        }
        for log in seedAteLogs() {
            context.insert(log)
        }
        try? context.save()
    }

    /// ふりかえり／達成カード用の ate ログ12件。
    /// 「今月6件（うち前週に2件）・先月4件・先々月2件」に分散させ、
    /// lifetime 12 / 今月6 / 先週2 / 連続3ヶ月 が再現されるようにする。
    /// 日付は now から calendar で算出する（実時間に追随）。
    @MainActor
    static func seedAteLogs(now: Date = .now, calendar: Calendar = .current) -> [ConsumptionLog] {
        let cats = ["fish", "leafy", "veg", "dairy", "tofu", "egg",
                    "chicken", "meat", "fruit", "mush", "bread", "deli"]
        var logs: [ConsumptionLog] = []
        var catIndex = 0
        func nextCat() -> String { defer { catIndex += 1 }; return cats[catIndex % cats.count] }

        // ── 当月6件（うち前週に2件）──
        // 前週2件: 先週（previousWeekInterval）の中ほどに置く。当月に収まるよう、
        //   月初に near のときは依存しないが、ここでは「先週の開始＋1日／＋2日」を採用する。
        //   先週が前月に食い込む環境ではテスト側の固定日で別途検証する（ここはスクショ用シード）。
        let prevWeek = Stats.previousWeekInterval(now: now, calendar: calendar)
        let prevWeekA = calendar.date(byAdding: .day, value: 1, to: prevWeek.start) ?? prevWeek.start
        let prevWeekB = calendar.date(byAdding: .day, value: 2, to: prevWeek.start) ?? prevWeek.start
        logs.append(ConsumptionLog(date: prevWeekA, catId: nextCat(), action: .ate))
        logs.append(ConsumptionLog(date: prevWeekB, catId: nextCat(), action: .ate))

        // 当月の残り4件: 今日と直近数日（同月内）に置く。
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        for offset in [0, 1, 2, 3] {
            // now から offset 日前。monthStart を下回ったら monthStart 当日に寄せる（同月を保証）。
            let d = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let safe = d < monthStart ? monthStart : d
            logs.append(ConsumptionLog(date: safe, catId: nextCat(), action: .ate))
        }

        // ── 先月4件 ──
        let lastMonthMid = monthMidpoint(monthsAgo: 1, now: now, calendar: calendar)
        for offset in [0, 2, 4, 6] {
            let d = calendar.date(byAdding: .day, value: offset, to: lastMonthMid) ?? lastMonthMid
            logs.append(ConsumptionLog(date: d, catId: nextCat(), action: .ate))
        }

        // ── 先々月2件 ──
        let prevPrevMid = monthMidpoint(monthsAgo: 2, now: now, calendar: calendar)
        for offset in [0, 3] {
            let d = calendar.date(byAdding: .day, value: offset, to: prevPrevMid) ?? prevPrevMid
            logs.append(ConsumptionLog(date: d, catId: nextCat(), action: .ate))
        }

        return logs
    }

    /// monthsAgo か月前の月の 10 日（同月内に確実に収まる安全な基準日）。
    @MainActor
    private static func monthMidpoint(monthsAgo: Int, now: Date, calendar: Calendar) -> Date {
        guard let monthDate = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { return now }
        var comps = calendar.dateComponents([.year, .month], from: monthDate)
        comps.day = 10
        comps.hour = 12
        return calendar.date(from: comps) ?? monthDate
    }
    #endif
}
