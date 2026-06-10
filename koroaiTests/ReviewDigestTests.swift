// Step 6（ふりかえり＋今朝のまとめ）の純関数テスト。
//
// 固定 Calendar（Asia/Tokyo）/ 固定 Date（2026-06-10）で決定的にする。
// @Model（ConsumptionLog）を触る Stats のテストは @MainActor 上で in-memory コンテナにバッキングを与える。

import Testing
import Foundation
import SwiftData
@testable import koroai

// MARK: - Stats（lifetime / previousWeek / ateCount / monthStreak）

@MainActor
struct ReviewStatsTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    /// daysAgo 日前の ate/tossed ログを context にバッキングして返す。
    private func log(_ context: ModelContext, _ action: ConsumptionAction, daysAgo: Int) -> ConsumptionLog {
        let d = cal().date(byAdding: .day, value: -daysAgo, to: now())!
        let l = ConsumptionLog(date: d, catId: "fish", action: action)
        context.insert(l)
        return l
    }

    /// 指定年月日の ate ログ。
    private func ateOn(_ context: ModelContext, _ y: Int, _ m: Int, _ d: Int) -> ConsumptionLog {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        let l = ConsumptionLog(date: cal().date(from: c)!, catId: "veg", action: .ate)
        context.insert(l)
        return l
    }

    // ── lifetimeAteCount ──

    @Test func lifetimeCountsAllAteIgnoresTossed() throws {
        let context = try TestSupport.makeContext()
        let logs = [
            log(context, .ate, daysAgo: 0),
            log(context, .ate, daysAgo: 40),     // 通算なので月をまたいでも数える
            log(context, .ate, daysAgo: 400),    // 1年以上前でも数える
            log(context, .tossed, daysAgo: 1),   // 廃棄は数えない
        ]
        #expect(Stats.lifetimeAteCount(logs: logs) == 3)
    }

    @Test func lifetimeIsZeroForEmpty() {
        #expect(Stats.lifetimeAteCount(logs: []) == 0)
    }

    // ── previousWeekInterval ──

    @Test func previousWeekIsTheCalendarWeekBeforeNow() {
        // 2026-06-10 は水曜。日曜始まりの週は 6/7(日)〜6/13(土)。
        // よって先週は 5/31(日)〜6/6(土)。interval は [5/31 00:00, 6/7 00:00)。
        let interval = Stats.previousWeekInterval(now: now(), calendar: cal())
        let startC = cal().dateComponents([.year, .month, .day], from: interval.start)
        let endC = cal().dateComponents([.year, .month, .day], from: interval.end)
        #expect(startC.month == 5 && startC.day == 31)
        #expect(endC.month == 6 && endC.day == 7)
        // ちょうど7日間。
        #expect(interval.duration == 7 * 24 * 60 * 60)
    }

    @Test func previousWeekStartIsFirstWeekday() {
        let interval = Stats.previousWeekInterval(now: now(), calendar: cal())
        let weekday = cal().component(.weekday, from: interval.start)
        #expect(weekday == cal().firstWeekday)
    }

    // ── ateCount(in:) ──

    @Test func ateCountInPreviousWeekCountsOnlyThatWeeksAte() throws {
        let context = try TestSupport.makeContext()
        let interval = Stats.previousWeekInterval(now: now(), calendar: cal())
        // 先週内（6/1, 6/2）の ate 2件
        let a = ateOn(context, 2026, 6, 1)
        let b = ateOn(context, 2026, 6, 2)
        // 今週内（6/8）の ate → 数えない
        let c = ateOn(context, 2026, 6, 8)
        // 先週内の tossed → 数えない
        var tc = DateComponents(); tc.year = 2026; tc.month = 6; tc.day = 3; tc.hour = 9
        let toss = ConsumptionLog(date: cal().date(from: tc)!, catId: "fish", action: .tossed)
        context.insert(toss)
        let n = Stats.ateCount(logs: [a, b, c, toss], in: interval)
        #expect(n == 2)
    }

    @Test func ateCountEndIsExclusive() throws {
        let context = try TestSupport.makeContext()
        let interval = Stats.previousWeekInterval(now: now(), calendar: cal())
        // ちょうど end（6/7 00:00）の ate は [start, end) なので含めない。
        let onEnd = ConsumptionLog(date: interval.end, catId: "veg", action: .ate)
        context.insert(onEnd)
        // start ちょうど（5/31 00:00）は含める。
        let onStart = ConsumptionLog(date: interval.start, catId: "veg", action: .ate)
        context.insert(onStart)
        #expect(Stats.ateCount(logs: [onEnd, onStart], in: interval) == 1)
    }

    // ── monthStreak ──

    @Test func streakThreeConsecutiveMonths() throws {
        let context = try TestSupport.makeContext()
        // 当月(6月)・先月(5月)・先々月(4月)に ate。3月は無し → streak 3。
        let logs = [
            ateOn(context, 2026, 6, 10),
            ateOn(context, 2026, 5, 15),
            ateOn(context, 2026, 4, 20),
            // 3月は無し（連続を止める）
            ateOn(context, 2026, 1, 5),  // 飛び地。連続には寄与しない。
        ]
        #expect(Stats.monthStreak(logs: logs, now: now(), calendar: cal()) == 3)
    }

    @Test func streakBreaksOnGap() throws {
        let context = try TestSupport.makeContext()
        // 当月(6月)・先月(5月)はあるが先々月(4月)が無い → streak 2。
        let logs = [
            ateOn(context, 2026, 6, 10),
            ateOn(context, 2026, 5, 15),
            ateOn(context, 2026, 3, 20),  // 4月を飛ばしている
        ]
        #expect(Stats.monthStreak(logs: logs, now: now(), calendar: cal()) == 2)
    }

    @Test func streakKeptWhenCurrentMonthEmptyButPriorMonthsContinue() throws {
        let context = try TestSupport.makeContext()
        // 当月(6月)は0件。先月(5月)・先々月(4月)・3月は連続。当月途中の未記録を許容 → streak 3。
        let logs = [
            ateOn(context, 2026, 5, 15),
            ateOn(context, 2026, 4, 20),
            ateOn(context, 2026, 3, 12),
        ]
        #expect(Stats.monthStreak(logs: logs, now: now(), calendar: cal()) == 3)
    }

    @Test func streakZeroWhenNoAteAnywhere() throws {
        let context = try TestSupport.makeContext()
        let t = log(context, .tossed, daysAgo: 0)
        #expect(Stats.monthStreak(logs: [t], now: now(), calendar: cal()) == 0)
        #expect(Stats.monthStreak(logs: [], now: now(), calendar: cal()) == 0)
    }
}

// MARK: - Milestones.crossed（純関数・コンテナ不要）

struct MilestonesTests {

    @Test func crossingFromZeroToOneHitsFirst() {
        #expect(Milestones.crossed(prev: 0, next: 1)?.id == "first")
    }

    @Test func crossingSixToSevenHitsWeek() {
        #expect(Milestones.crossed(prev: 6, next: 7)?.id == "week")
    }

    @Test func crossingFiveToThirteenHitsHighestTwelve() {
        // 7 と 12 を同時に跨ぐ → 最上位 = twelve。
        #expect(Milestones.crossed(prev: 5, next: 13)?.id == "twelve")
    }

    @Test func noMovementReturnsNil() {
        #expect(Milestones.crossed(prev: 3, next: 3) == nil)
        #expect(Milestones.crossed(prev: 12, next: 12) == nil)
    }

    @Test func hasSixMilestonesInAscendingOrder() {
        #expect(Milestones.all.count == 6)
        #expect(Milestones.all.map(\.at) == [1, 3, 7, 12, 20, 40])
    }
}

// MARK: - Ranks（純関数・コンテナ不要）

struct RanksTests {

    @Test(arguments: [
        (0, "はじめの一歩"),
        (4, "はじめの一歩"),
        (5, "食べきり上手"),
        (11, "食べきり上手"),
        (12, "ムダなしの達人"),
        (19, "ムダなしの達人"),
        (20, "食べきりマイスター"),
        (25, "食べきりマイスター"),
    ])
    func rankBoundaries(count: Int, expected: String) {
        #expect(Ranks.rank(for: count).name == expected)
    }
}

// MARK: - DigestBuilder（純関数・コンテナ不要）

struct DigestBuilderTests {

    private func item(_ name: String, days: Int, perishable: Bool = true, catId: String = "fish") -> DigestItem {
        DigestItem(id: UUID(), catId: catId, name: name, perishable: perishable, days: days)
    }

    // ── 振り分け（today / tomorrow / soon / hero） ──

    @Test func bucketsByDays() {
        let items = [
            item("今日0", days: 0),
            item("過去-1", days: -1),
            item("明日", days: 1),
            item("soon2", days: 2),
            item("soon3", days: 3),
            item("calm4", days: 4),
            item("calm6", days: 6),
            item("除外7", days: 7),         // hero(<=6) 外
            item("非生鮮", days: 0, perishable: false), // 生鮮でないので hero 外
        ]
        let r = DigestBuilder.build(items: items, tone: .gentle)
        #expect(r.today.map(\.name) == ["過去-1", "今日0"]) // days 昇順
        #expect(r.tomorrow.map(\.name) == ["明日"])
        #expect(r.soon.map(\.name) == ["soon2", "soon3"])
        #expect(r.hero.map(\.name) == ["過去-1", "今日0", "明日", "soon2", "soon3", "calm4", "calm6"])
        #expect(r.urgent.map(\.name) == ["過去-1", "今日0", "明日", "soon2", "soon3"])
    }

    // ── lead 分岐4通り ──

    @Test func leadWhenTodayExists() {
        let r = DigestBuilder.build(items: [item("a", days: 0), item("b", days: 0)], tone: .gentle)
        #expect(r.lead == "今日のうちに食べきりたいものが 2品")
        #expect(r.leadEndsWithPeriod == true)
    }

    @Test func leadWhenOnlyTomorrow() {
        let r = DigestBuilder.build(items: [item("a", days: 1)], tone: .gentle)
        #expect(r.lead == "あすが食べどきのものが 1品")
        #expect(r.leadEndsWithPeriod == true)
    }

    @Test func leadWhenOnlySoon() {
        let r = DigestBuilder.build(items: [item("a", days: 2), item("b", days: 3)], tone: .gentle)
        #expect(r.lead == "近いうちに食べたいものが 2品")
        #expect(r.leadEndsWithPeriod == false) // soon のみは末尾「。」なし
    }

    @Test func leadWhenNothingUrgent() {
        let r = DigestBuilder.build(items: [item("a", days: 5)], tone: .gentle)
        #expect(r.lead == "今日は急ぎの食材はありません")
        #expect(r.sub == "ゆっくりどうぞ。")
        #expect(r.nudge == nil)
        #expect(r.leadEndsWithPeriod == false)
    }

    @Test func cheerSoonLeadDiffersFromGentle() {
        let r = DigestBuilder.build(items: [item("a", days: 2)], tone: .cheer)
        #expect(r.lead == "そろそろのものが 1品")
    }

    @Test func cheerEmptyLead() {
        let r = DigestBuilder.build(items: [item("a", days: 5)], tone: .cheer)
        #expect(r.lead == "急ぎはなし、上手に使えてます！")
    }

    // ── nudge の対象（today[0] 優先） ──

    @Test func nudgePrefersFirstTodayByDaysOrder() {
        // days 昇順ソート後の today 先頭（最も差し迫ったもの）が対象。
        let r = DigestBuilder.build(items: [item("今日", days: 0), item("過去", days: -2), item("明日", days: 1)], tone: .gentle)
        #expect(r.nudge == "過去、今日のうちに使い切れます")
    }

    @Test func nudgeFallsBackToTomorrowWhenNoToday() {
        let r = DigestBuilder.build(items: [item("明日", days: 1), item("soon", days: 3)], tone: .gentle)
        #expect(r.nudge == "明日、今日のうちに使い切れます")
    }

    // ── verb 3トーン ──

    @Test func verbGentle() {
        #expect(DigestBuilder.verb(days: 0, tone: .gentle) == "今日のうちに")
        #expect(DigestBuilder.verb(days: 1, tone: .gentle) == "あすまでに")
        #expect(DigestBuilder.verb(days: 3, tone: .gentle) == "あと3日")
    }

    @Test func verbSimple() {
        #expect(DigestBuilder.verb(days: 0, tone: .simple) == "今日中")
        #expect(DigestBuilder.verb(days: 1, tone: .simple) == "明日まで")
        #expect(DigestBuilder.verb(days: 2, tone: .simple) == "あと2日")
    }

    @Test func verbCheer() {
        #expect(DigestBuilder.verb(days: 0, tone: .cheer) == "きょうが食べどき")
        #expect(DigestBuilder.verb(days: 1, tone: .cheer) == "そろそろ")
        #expect(DigestBuilder.verb(days: 3, tone: .cheer) == "あと3日")
    }

    // ── nudge / lead のトーン別文言（simple / cheer の today） ──

    @Test func todayNudgeAndLeadTones() {
        let g = DigestBuilder.build(items: [item("豆腐", days: 0)], tone: .gentle)
        #expect(g.lead == "今日のうちに食べきりたいものが 1品")
        #expect(g.nudge == "豆腐、今日のうちに使い切れます")

        let s = DigestBuilder.build(items: [item("豆腐", days: 0)], tone: .simple)
        #expect(s.lead == "今日中：1品")
        #expect(s.nudge == "豆腐を使い切る")

        let c = DigestBuilder.build(items: [item("豆腐", days: 0)], tone: .cheer)
        #expect(c.lead == "きょうが食べごろ、1品！")
        #expect(c.nudge == "豆腐、今日おいしく食べきろう！")
    }
}

// MARK: - DigestSheet.timeLabel（純関数）

struct DigestTimeLabelTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }

    private func at(_ h: Int, _ m: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 10; c.hour = h; c.minute = m
        return cal().date(from: c)!
    }

    @Test func morningBeforeNoon() {
        #expect(DigestSheet.timeLabel(now: at(7, 30), calendar: cal()) == "今朝 7:30")
        #expect(DigestSheet.timeLabel(now: at(0, 5), calendar: cal()) == "今朝 0:05")
        #expect(DigestSheet.timeLabel(now: at(11, 59), calendar: cal()) == "今朝 11:59")
    }

    @Test func noonAndAfter() {
        #expect(DigestSheet.timeLabel(now: at(12, 0), calendar: cal()) == "きょう 12:00")
        #expect(DigestSheet.timeLabel(now: at(18, 7), calendar: cal()) == "きょう 18:07")
    }
}
