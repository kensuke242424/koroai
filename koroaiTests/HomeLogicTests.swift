// ホームのロジック（分割・heroVerb・日替わりタイトル・当月集計）の純関数テスト。
// 固定 Calendar（Asia/Tokyo）/ 固定 Date（2026-06-10）で決定的にする。
//
// FoodItem / ConsumptionLog は @Model のため @MainActor 上で in-memory コンテナにバッキングを与える。

import Testing
import Foundation
import SwiftData
@testable import koroai

// MARK: - HomeSplit（@Model → @MainActor）

@MainActor
struct HomeSplitTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    /// daysLeft と perishable を指定して FoodItem を作り、context に挿入する。
    private func makeItem(
        _ context: ModelContext,
        catId: String,
        name: String,
        daysLeft: Int,
        perishable: Bool,
        purchasedAt: Date? = nil
    ) -> FoodItem {
        let c = cal()
        let n = now()
        let item = FoodItem(
            catId: catId,
            name: name,
            purchasedAt: purchasedAt ?? n,
            expiresAt: DateMath.expiryDate(daysFromNow: daysLeft, from: n, calendar: c),
            perishable: perishable,
            unit: "個"
        )
        context.insert(item)
        return item
    }

    @Test func perishableBoundarySixIsHero_sevenIsPlenty() throws {
        let context = try TestSupport.makeContext()
        let six = makeItem(context, catId: "veg", name: "6日", daysLeft: 6, perishable: true)
        let seven = makeItem(context, catId: "veg", name: "7日", daysLeft: 7, perishable: true)
        let split = HomeSplitter.split(items: [six, seven], now: now(), calendar: cal())
        // 6日の生鮮 → hero（calm）、7日の生鮮 → plenty
        #expect(split.calm.contains { $0.name == "6日" })
        #expect(split.plenty.contains { $0.name == "7日" })
    }

    @Test func nonPerishableGoesToPlentyEvenAtZeroDays() throws {
        let context = try TestSupport.makeContext()
        let egg = makeItem(context, catId: "egg", name: "卵0日", daysLeft: 0, perishable: false)
        let split = HomeSplitter.split(items: [egg], now: now(), calendar: cal())
        // 非生鮮は daysLeft0 でも plenty（hero に入らない）
        #expect(split.plenty.contains { $0.name == "卵0日" })
        #expect(split.urgent.isEmpty)
        #expect(split.calm.isEmpty)
        #expect(split.hasHero == false)
    }

    @Test func urgentIsDueToday_calmIsOneToSix() throws {
        // きょうの食べ頃 = daysLeft<=0（今日まで・期限切れ含む）。それ以外の hero は今週の食材。
        let context = try TestSupport.makeContext()
        let dm1 = makeItem(context, catId: "fish", name: "dm1", daysLeft: -1, perishable: true)
        let d0 = makeItem(context, catId: "fish", name: "d0", daysLeft: 0, perishable: true)
        let d1 = makeItem(context, catId: "fish", name: "d1", daysLeft: 1, perishable: true)
        let d2 = makeItem(context, catId: "fish", name: "d2", daysLeft: 2, perishable: true)
        let d6 = makeItem(context, catId: "fish", name: "d6", daysLeft: 6, perishable: true)
        let split = HomeSplitter.split(items: [d6, d2, d1, d0, dm1], now: now(), calendar: cal())
        #expect(split.urgent.map(\.name) == ["dm1", "d0"])        // daysLeft 昇順・今日まで
        #expect(split.calm.map(\.name) == ["d1", "d2", "d6"])     // 明日以降
    }

    @Test func heroSortsByDaysThenPurchasedAt() throws {
        let context = try TestSupport.makeContext()
        let c = cal()
        let n = now()
        // 同じ daysLeft=1 の2件。purchasedAt の早い方が先（daysLeft=1 は今週の食材へ）。
        let older = makeItem(context, catId: "fish", name: "古い", daysLeft: 1, perishable: true,
                             purchasedAt: c.date(byAdding: .day, value: -3, to: n)!)
        let newer = makeItem(context, catId: "fish", name: "新しい", daysLeft: 1, perishable: true,
                             purchasedAt: c.date(byAdding: .day, value: -1, to: n)!)
        let split = HomeSplitter.split(items: [newer, older], now: n, calendar: c)
        #expect(split.calm.map(\.name) == ["古い", "新しい"])
    }

    @Test func plentySortsByDaysAscending() throws {
        let context = try TestSupport.makeContext()
        // 非生鮮 + 7日以上生鮮を混在。plenty は daysLeft 昇順。
        let egg10 = makeItem(context, catId: "egg", name: "卵10", daysLeft: 10, perishable: false)
        let veg8 = makeItem(context, catId: "veg", name: "野菜8", daysLeft: 8, perishable: true)
        let egg2 = makeItem(context, catId: "egg", name: "卵2", daysLeft: 2, perishable: false)
        let split = HomeSplitter.split(items: [egg10, veg8, egg2], now: now(), calendar: cal())
        #expect(split.plenty.map(\.name) == ["卵2", "野菜8", "卵10"])
    }

    @Test func hasDueTodayDetectsZeroDayUrgent() throws {
        let context = try TestSupport.makeContext()
        let due = makeItem(context, catId: "fish", name: "今日", daysLeft: 0, perishable: true)
        let split = HomeSplitter.split(items: [due], now: now(), calendar: cal())
        #expect(split.hasDueToday == true)
    }
}

// MARK: - heroVerb（純関数・コンテナ不要）

struct HeroVerbTests {

    @Test(arguments: [
        (0, "今日のうちに、食べきろう"),
        (1, "あすまでに、食べきりたい"),
        (3, "あと3日、おいしいうちに"),
    ])
    func gentle(daysLeft: Int, expected: String) {
        #expect(HomeCopy.heroVerb(tone: .gentle, daysLeft: daysLeft) == expected)
    }

    @Test(arguments: [
        (0, "今日中に使い切る"),
        (1, "明日まで"),
        (3, "あと3日"),
    ])
    func simple(daysLeft: Int, expected: String) {
        #expect(HomeCopy.heroVerb(tone: .simple, daysLeft: daysLeft) == expected)
    }

    @Test(arguments: [
        (0, "きょうが食べどき！"),
        (1, "そろそろ食べごろ"),
        (3, "あと3日、楽しみに"),
    ])
    func cheer(daysLeft: Int, expected: String) {
        #expect(HomeCopy.heroVerb(tone: .cheer, daysLeft: daysLeft) == expected)
    }
}

// MARK: - dailyHeadline（純関数・固定日で決定的）

struct DailyHeadlineTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 9
        return cal().date(from: c)!
    }

    @Test func isDeterministicForFixedDate() {
        let d = date(2026, 6, 10)
        let a = HomeCopy.dailyHeadline(date: d, calendar: cal())
        let b = HomeCopy.dailyHeadline(date: d, calendar: cal())
        #expect(a == b)
    }

    @Test func summerDatePicksAllOrSummerHeadline() {
        // 6月 = 夏。プールは all + summer のみ。winter 専用文言は出ない。
        let d = date(2026, 7, 15)
        let headline = HomeCopy.dailyHeadline(date: d, calendar: cal())
        let winterOnly = HomeCopy.dailyHeadlines.filter { $0.season == "winter" }.map(\.text)
        #expect(!winterOnly.contains(headline))
    }

    @Test func winterDateDoesNotPickSummerHeadline() {
        let d = date(2026, 1, 15)
        let headline = HomeCopy.dailyHeadline(date: d, calendar: cal())
        let summerOnly = HomeCopy.dailyHeadlines.filter { $0.season == "summer" }.map(\.text)
        #expect(!summerOnly.contains(headline))
    }

    @Test func neverEmptyAcrossWholeYear() {
        for month in 1...12 {
            for day in [1, 15, 28] {
                let h = HomeCopy.dailyHeadline(date: date(2026, month, day), calendar: cal())
                #expect(!h.isEmpty)
            }
        }
    }

    @Test func seasonBoundaries() {
        #expect(HomeCopy.season(month: 12) == .winter)
        #expect(HomeCopy.season(month: 2) == .winter)
        #expect(HomeCopy.season(month: 3) == .spring)
        #expect(HomeCopy.season(month: 5) == .spring)
        #expect(HomeCopy.season(month: 6) == .summer)
        #expect(HomeCopy.season(month: 8) == .summer)
        #expect(HomeCopy.season(month: 9) == .autumn)
        #expect(HomeCopy.season(month: 11) == .autumn)
    }
}

// MARK: - Stats.monthlyAteCount（@Model → @MainActor）

@MainActor
struct StatsTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    private func log(_ context: ModelContext, _ action: ConsumptionAction, daysAgo: Int) -> ConsumptionLog {
        let c = cal()
        let d = c.date(byAdding: .day, value: -daysAgo, to: now())!
        let l = ConsumptionLog(date: d, catId: "fish", action: action)
        context.insert(l)
        return l
    }

    @Test func countsOnlyCurrentMonthAte() throws {
        let context = try TestSupport.makeContext()
        // 当月（6月）の ate を3件、tossed を1件
        let l1 = log(context, .ate, daysAgo: 0)   // 6/10
        let l2 = log(context, .ate, daysAgo: 5)   // 6/5
        let l3 = log(context, .ate, daysAgo: 9)   // 6/1
        let toss = log(context, .tossed, daysAgo: 0)
        // 先月（5月）の ate を1件 → 数えない
        let lastMonth = log(context, .ate, daysAgo: 11) // 5/30
        let count = Stats.monthlyAteCount(
            logs: [l1, l2, l3, toss, lastMonth],
            now: now(), calendar: cal()
        )
        #expect(count == 3)
    }

    @Test func excludesTossed() throws {
        let context = try TestSupport.makeContext()
        let a = log(context, .ate, daysAgo: 0)
        let t1 = log(context, .tossed, daysAgo: 1)
        let t2 = log(context, .tossed, daysAgo: 2)
        let count = Stats.monthlyAteCount(logs: [a, t1, t2], now: now(), calendar: cal())
        #expect(count == 1)
    }

    @Test func differentYearSameMonthNotCounted() throws {
        let context = try TestSupport.makeContext()
        let c = cal()
        // 1年前の同月（2025-06）の ate は数えない
        let oldDate = c.date(byAdding: .year, value: -1, to: now())!
        let old = ConsumptionLog(date: oldDate, catId: "fish", action: .ate)
        context.insert(old)
        let thisMonth = log(context, .ate, daysAgo: 0)
        let count = Stats.monthlyAteCount(logs: [old, thisMonth], now: now(), calendar: cal())
        #expect(count == 1)
    }
}
