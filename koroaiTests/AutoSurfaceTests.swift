// Step 8 自動表示まわりの純関数・SwiftData 操作テスト。
// 固定 now（2026-06-10 09:00 Asia/Tokyo）/ 固定 Calendar で決定的にする。
//
// 検証対象:
//  - MonthResultTrigger.evaluate（発火条件・count/prevCount/streak）
//  - 先月比チップの分岐4通り（nil/up/same/down）
//  - AutoSurface.awayDays / decide（復帰判定）
//  - ReturnActions（期限切れ片付け・リセット・入れ直し）とログ非破壊
//  - OnboardingActions（選択投入・スキップ）
//
// @Model（FoodItem / ConsumptionLog）は @MainActor 上の in-memory コンテナでバッキングを与える。

import Testing
import Foundation
import SwiftData
@testable import koroai

@MainActor
struct AutoSurfaceTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) } // 2026-06-10 09:00 JST

    /// 指定の年月日に ate ログを作る（context へ insert）。
    @discardableResult
    private func ate(_ context: ModelContext, y: Int, m: Int, d: Int) -> ConsumptionLog {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        let date = cal().date(from: c)!
        let log = ConsumptionLog(date: date, catId: "fish", action: .ate)
        context.insert(log)
        return log
    }

    /// lastOpenedAt 用の日付を作る。
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 9
        return cal().date(from: c)!
    }

    // MARK: - MonthResultTrigger.evaluate

    @Test func monthResultFiresWithLastMonthAteAndPrevCount() throws {
        let context = try TestSupport.makeContext()
        // 5月 ate 4件・4月 ate 2件（先々月）。
        for d in [5, 10, 15, 20] { ate(context, y: 2026, m: 5, d: d) }
        for d in [8, 18] { ate(context, y: 2026, m: 4, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())

        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 5, 20), // 先月内・別暦月（過去）
            logs: logs,
            shownFor: nil,
            enabled: true,
            now: now(),
            calendar: cal()
        )
        let result = try #require(data)
        #expect(result.year == 2026)
        #expect(result.month == 5)
        #expect(result.count == 4)         // 先月（5月）の ate
        #expect(result.prevCount == 2)     // 先々月（4月）の ate
        #expect(result.monthKey == "2026-05")
    }

    @Test func monthResultNilWhenSameMonth() throws {
        let context = try TestSupport.makeContext()
        for d in [5, 10, 15, 20] { ate(context, y: 2026, m: 5, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        // 前回 6/1（now と同じ暦月）→ nil。
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 6, 1),
            logs: logs, shownFor: nil, enabled: true, now: now(), calendar: cal()
        )
        #expect(data == nil)
    }

    @Test func monthResultNilWhenLastMonthZero() throws {
        let context = try TestSupport.makeContext()
        // 先月（5月）0件・4月だけ ate。
        ate(context, y: 2026, m: 4, d: 10)
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 5, 20),
            logs: logs, shownFor: nil, enabled: true, now: now(), calendar: cal()
        )
        #expect(data == nil)
    }

    @Test func monthResultNilWhenAlreadyShown() throws {
        let context = try TestSupport.makeContext()
        for d in [5, 10] { ate(context, y: 2026, m: 5, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        // 既に "2026-05" を見せている → nil。
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 5, 20),
            logs: logs, shownFor: "2026-05", enabled: true, now: now(), calendar: cal()
        )
        #expect(data == nil)
    }

    @Test func monthResultNilWhenDisabled() throws {
        let context = try TestSupport.makeContext()
        for d in [5, 10] { ate(context, y: 2026, m: 5, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 5, 20),
            logs: logs, shownFor: nil, enabled: false, now: now(), calendar: cal()
        )
        #expect(data == nil)
    }

    @Test func monthResultPrevCountNilWhenNoAteBeforeLastMonth() throws {
        let context = try TestSupport.makeContext()
        // 5月だけ ate（先々月以前に ate ゼロ）→ prevCount nil（はじめての記録）。
        for d in [5, 10, 15] { ate(context, y: 2026, m: 5, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 5, 20),
            logs: logs, shownFor: nil, enabled: true, now: now(), calendar: cal()
        )
        let result = try #require(data)
        #expect(result.count == 3)
        #expect(result.prevCount == nil)
    }

    @Test func monthResultNilWhenNeverOpened() throws {
        let context = try TestSupport.makeContext()
        for d in [5, 10] { ate(context, y: 2026, m: 5, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        // lastOpenedAt nil（初回）→ 月替わりは出さない。
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: nil,
            logs: logs, shownFor: nil, enabled: true, now: now(), calendar: cal()
        )
        #expect(data == nil)
    }

    @Test func monthResultStreakCountsConsecutiveMonths() throws {
        let context = try TestSupport.makeContext()
        // 3月・4月・5月 連続 ate → 先月(5月)起点で streak 3。
        ate(context, y: 2026, m: 3, d: 10)
        ate(context, y: 2026, m: 4, d: 10)
        for d in [5, 10] { ate(context, y: 2026, m: 5, d: d) }
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        let data = MonthResultTrigger.evaluate(
            lastOpenedAt: date(2026, 5, 20),
            logs: logs, shownFor: nil, enabled: true, now: now(), calendar: cal()
        )
        let result = try #require(data)
        #expect(result.streak == 3)
    }

    // MARK: - 先月比チップ分岐（純関数）

    @Test func diffChipFirstRecord() {
        let chip = MonthResultCopy.diffChip(count: 4, prevCount: nil)
        #expect(chip.label == "はじめての記録")
        #expect(chip.tone == .neutral)
    }

    @Test func diffChipUp() {
        let chip = MonthResultCopy.diffChip(count: 6, prevCount: 4)
        #expect(chip.label == "先月より ＋2品")
        #expect(chip.tone == .up)
    }

    @Test func diffChipSame() {
        let chip = MonthResultCopy.diffChip(count: 4, prevCount: 4)
        #expect(chip.label == "先月と同じペース")
        #expect(chip.tone == .neutral)
    }

    @Test func diffChipDown() {
        let chip = MonthResultCopy.diffChip(count: 3, prevCount: 5)
        #expect(chip.label == "マイペースで継続中")
        #expect(chip.tone == .neutral)
    }

    // MARK: - awayDays 判定

    @Test func awayDaysNineTriggersReturn() {
        let away = AutoSurface.awayDays(lastOpenedAt: date(2026, 6, 1), now: now(), calendar: cal())
        #expect(away == 9)
        #expect(away >= AutoSurface.awayThreshold)
    }

    @Test func awayDaysFourDoesNotTrigger() {
        let away = AutoSurface.awayDays(lastOpenedAt: date(2026, 6, 6), now: now(), calendar: cal())
        #expect(away == 4)
        #expect(away < AutoSurface.awayThreshold)
    }

    @Test func awayDaysNilIsZero() {
        let away = AutoSurface.awayDays(lastOpenedAt: nil, now: now(), calendar: cal())
        #expect(away == 0)
    }

    @Test func decideReturningWhenNineDaysAway() throws {
        let context = try TestSupport.makeContext()
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        let decision = AutoSurface.decide(
            onboarded: true,
            lastOpenedAt: date(2026, 6, 1),
            logs: logs,
            monthResultShownFor: nil,
            monthlyResultEnabled: true,
            now: now(), calendar: cal()
        )
        #expect(decision == .returning(daysAway: 9))
    }

    @Test func decideOnboardingWhenNotOnboarded() throws {
        let context = try TestSupport.makeContext()
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        let decision = AutoSurface.decide(
            onboarded: false,
            lastOpenedAt: date(2026, 6, 1),
            logs: logs,
            monthResultShownFor: nil,
            monthlyResultEnabled: true,
            now: now(), calendar: cal()
        )
        #expect(decision == .onboarding)
    }

    // MARK: - 期限切れ片付け（daysLeft<0 のみ削除・ログ件数不変）

    private func item(_ context: ModelContext, _ catId: String, daysLeft: Int) -> FoodItem {
        let c = cal(); let n = now()
        let fi = FoodItem(
            catId: catId, name: catId,
            purchasedAt: n,
            expiresAt: DateMath.expiryDate(daysFromNow: daysLeft, from: n, calendar: c),
            perishable: true, unit: "個"
        )
        context.insert(fi)
        return fi
    }

    @Test func purgeExpiredRemovesOnlyNegativeAndKeepsLogs() throws {
        let context = try TestSupport.makeContext()
        item(context, "fish", daysLeft: -2)   // 期限切れ
        item(context, "veg", daysLeft: -1)     // 期限切れ
        item(context, "leafy", daysLeft: 0)    // 今日（残す）
        item(context, "dairy", daysLeft: 3)    // 残す
        ate(context, y: 2026, m: 6, d: 1)      // ログ1件
        ate(context, y: 2026, m: 5, d: 1)      // ログ1件
        try context.save()

        let removed = ReturnActions.purgeExpired(context: context, now: now(), calendar: cal())
        #expect(removed == 2)

        let remaining = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(remaining.count == 2)
        #expect(remaining.allSatisfy { $0.daysLeft(now: now(), calendar: cal()) >= 0 })
        // ログは不変。
        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        #expect(logs.count == 2)
    }

    // MARK: - 復帰リセットはログを消さない（設定リセットとの違い）

    @Test func returnResetClearsItemsButKeepsLogs() throws {
        let context = try TestSupport.makeContext()
        item(context, "fish", daysLeft: 2)
        item(context, "veg", daysLeft: 4)
        ate(context, y: 2026, m: 6, d: 1)
        ate(context, y: 2026, m: 5, d: 1)
        try context.save()

        ReturnActions.resetItemsOnly(context: context)

        #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
        // 設定リセットと違い、ログは保持される。
        #expect(try context.fetch(FetchDescriptor<ConsumptionLog>()).count == 2)
    }

    // MARK: - 入れ直し（生鮮10種のみ・既定で投入・全置換）

    @Test func reenterReplacesAllWithSelectedDefaults() throws {
        let context = try TestSupport.makeContext()
        // 既存食材2件＋ログ。
        item(context, "fish", daysLeft: 5)
        item(context, "egg", daysLeft: 10)
        ate(context, y: 2026, m: 5, d: 1)
        try context.save()

        ReturnActions.replaceAllItems(with: ["leafy", "dairy"], context: context, now: now(), calendar: cal())

        let items = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(items.count == 2)
        let byCat = Dictionary(uniqueKeysWithValues: items.map { ($0.catId, $0) })
        // FoodItem.make の既定（名前＝カテゴリ defaultName・日数＝defaultDays）。
        let leafy = try #require(byCat["leafy"])
        #expect(leafy.name == FoodCategory.find("leafy")!.defaultName)
        #expect(leafy.daysLeft(now: now(), calendar: cal()) == FoodCategory.find("leafy")!.defaultDays)
        // ログは保持。
        #expect(try context.fetch(FetchDescriptor<ConsumptionLog>()).count == 1)
    }

    @Test func perishableCategoriesForReenterExcludeEgg() {
        // 入れ直しシートは生鮮（perishable==true）のみ。卵だけが非生鮮。
        // 注: 仕様書本文は「10種」と記すが、ハンドオフ fk-data.js の正は egg のみ非生鮮＝11種。
        //     実装は perishable フラグで出し分けるため、データ（11種）に追従する。
        let perishable = FoodCategory.all.filter(\.perishable)
        #expect(perishable.count == 11)
        #expect(!perishable.contains { $0.id == "egg" })
        #expect(FoodCategory.all.count == 12)
    }

    // MARK: - オンボーディング投入

    @Test func onboardingSeedsSelectedCategories() throws {
        let context = try TestSupport.makeContext()
        OnboardingActions.seedSelected(["fish", "veg"], context: context, now: now(), calendar: cal())
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(items.count == 2)
        #expect(Set(items.map(\.catId)) == ["fish", "veg"])
        // ConsumptionLog は作らない。
        #expect(try context.fetch(FetchDescriptor<ConsumptionLog>()).isEmpty)
    }

    @Test func onboardingSkipSeedsNothing() throws {
        let context = try TestSupport.makeContext()
        OnboardingActions.seedSelected([], context: context, now: now(), calendar: cal())
        #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }
}
