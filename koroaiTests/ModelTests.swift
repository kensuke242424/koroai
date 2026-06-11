// FoodCategory / FoodItem / SeedData / SwiftData コンテナのテスト。
//
// @Model（FoodItem / ConsumptionLog）のインスタンスは、生成しただけでも
// 保存プロパティへのアクセス時に「アクティブなコンテナ」を必要とする。
// テストを並列実行するとコンテナ不在でクラッシュするため、@Model を触る
// テストは @MainActor 上で in-memory コンテナを用意し、context に insert して
// バッキングを与える。日付系は固定 Calendar / 固定 Date で決定的にする。

import Testing
import Foundation
import SwiftData
@testable import koroai

// MARK: - 共有ヘルパー

enum TestSupport {
    static func tokyoCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }

    static func fixedNow(_ cal: Calendar) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 10; c.hour = 9; c.minute = 0
        return cal.date(from: c)!
    }

    /// FoodItem / ConsumptionLog 用の in-memory コンテナ。
    @MainActor static func makeContext() throws -> ModelContext {
        let schema = Schema([FoodItem.self, ConsumptionLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}

// MARK: - FoodCategory（値型・コンテナ不要）

struct FoodCategoryTests {

    @Test func hasTenSections() {
        // 旧12カテゴリ → 10セクションに再編。
        #expect(FoodCategory.all.count == 10)
    }

    @Test func idsAreUnique() {
        let ids = FoodCategory.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func onlyEggIsNonPerishable() {
        let nonPerishable = FoodCategory.all.filter { !$0.perishable }
        #expect(nonPerishable.count == 1)
        #expect(nonPerishable.first?.id == "egg")
    }

    @Test func fishDefaultDaysIsOne() {
        #expect(FoodCategory.find("fish")?.defaultDays == 1)
    }

    @Test func eggDefaultDaysIsFourteen() {
        #expect(FoodCategory.find("egg")?.defaultDays == 14)
    }

    @Test func fruitDefaultModeIsCount() {
        #expect(FoodCategory.find("fruit")?.defaultAmountMode == .count)
    }

    @Test func vegDefaultModeIsAmount() {
        #expect(FoodCategory.find("veg")?.defaultAmountMode == .amount)
    }

    @Test func findUnknownReturnsNil() {
        #expect(FoodCategory.find("nope") == nil)
    }

    @Test func orderIsCanonical() {
        let expected = ["meat", "fish", "veg", "mush", "fruit", "dairy", "egg", "tofu", "staple", "deli"]
        #expect(FoodCategory.all.map(\.id) == expected)
    }

    @Test func legacyAliasesResolveToSections() {
        // 旧 id（chicken/leafy/bread）は保存データ互換のため新セクションへ解決される。
        #expect(FoodCategory.find("chicken")?.id == "meat")
        #expect(FoodCategory.find("leafy")?.id == "veg")
        #expect(FoodCategory.find("bread")?.id == "staple")
    }
}

// MARK: - FoodItem（@Model・コンテナ必要 → @MainActor）

@MainActor
struct FoodItemTests {

    @Test func makeUsesCategoryDefaults() throws {
        let cal = TestSupport.tokyoCalendar()
        let now = TestSupport.fixedNow(cal)
        let context = try TestSupport.makeContext()
        let cat = FoodCategory.find("meat")!
        let item = FoodItem.make(category: cat, now: now, calendar: cal)
        context.insert(item)

        #expect(item.name == cat.defaultName)             // "豚こま"
        #expect(item.catId == "meat")
        #expect(item.unit == cat.defaultUnit)             // "パック"
        #expect(item.amountMode == cat.defaultAmountMode) // .amount
        #expect(item.perishable == cat.perishable)        // true
        #expect(item.amountIsSet == false)
        #expect(item.daysLeft(now: now, calendar: cal) == cat.defaultDays) // 2
    }

    @Test func makeHonorsExplicitDaysLeft() throws {
        let cal = TestSupport.tokyoCalendar()
        let now = TestSupport.fixedNow(cal)
        let context = try TestSupport.makeContext()
        let cat = FoodCategory.find("egg")!
        let item = FoodItem.make(category: cat, daysLeft: 5, now: now, calendar: cal)
        context.insert(item)
        #expect(item.daysLeft(now: now, calendar: cal) == 5)
        #expect(item.perishable == false) // egg はカテゴリ既定をコピー
    }

    @Test func makeHonorsExplicitName() throws {
        let cal = TestSupport.tokyoCalendar()
        let now = TestSupport.fixedNow(cal)
        let context = try TestSupport.makeContext()
        let item = FoodItem.make(category: FoodCategory.find("fish")!, name: "刺身（まぐろ）", now: now, calendar: cal)
        context.insert(item)
        #expect(item.name == "刺身（まぐろ）")
    }

    @Test func amountModeFallsBackOnUnknownRaw() throws {
        let context = try TestSupport.makeContext()
        let item = FoodItem(catId: "fish", name: "x", expiresAt: .now, perishable: true, unit: "切")
        context.insert(item)
        item.amountModeRaw = "bogus"
        #expect(item.amountMode == .amount)
    }

    @Test func categoryResolvesFromCatId() throws {
        let context = try TestSupport.makeContext()
        let item = FoodItem(catId: "tofu", name: "x", expiresAt: .now, perishable: true, unit: "丁")
        context.insert(item)
        #expect(item.category?.id == "tofu")
    }
}

// MARK: - SeedData（@Model を生成 → @MainActor）

@MainActor
struct SeedDataTests {

    /// previewItems を生成し、in-memory context に挿入してバッキングを与える。
    private func seedItems() throws -> [FoodItem] {
        let cal = TestSupport.tokyoCalendar()
        let now = TestSupport.fixedNow(cal)
        let context = try TestSupport.makeContext()
        let items = SeedData.previewItems(now: now, calendar: cal)
        for item in items { context.insert(item) }
        return items
    }

    @Test func previewHasSevenItems() throws {
        #expect(try seedItems().count == 7)
    }

    @Test func eggItemHasExpectedQuantities() throws {
        let egg = try seedItems().first { $0.catId == "egg" }
        #expect(egg?.quantity == 8)
        #expect(egg?.quantityTotal == 10)
        #expect(egg?.amountMode == .count)
        #expect(egg?.amountIsSet == true)
    }

    @Test func vegItemOverridesToCountMode() throws {
        // veg セクションには ほうれん草(amount) と ミニトマト(count) があるので名前で特定する。
        let veg = try seedItems().first { $0.name == "ミニトマト" }
        #expect(veg?.catId == "veg")
        #expect(veg?.amountMode == .count)   // セクション既定は amount だが count に上書き
        #expect(veg?.quantity == 4)
        #expect(veg?.quantityTotal == 6)
    }

    @Test func fishItemHasAmountSet() throws {
        let cal = TestSupport.tokyoCalendar()
        let now = TestSupport.fixedNow(cal)
        let fish = try seedItems().first { $0.catId == "fish" }
        #expect(fish?.amountIsSet == true)
        #expect(abs((fish?.amount ?? 0) - 0.5) < 0.0001)
        #expect(fish?.daysLeft(now: now, calendar: cal) == 0)
    }
}

// MARK: - SwiftData コンテナ

@MainActor
struct SwiftDataContainerTests {

    @Test func inMemoryContainerInsertsAndFetches() throws {
        let context = try TestSupport.makeContext()

        let cat = FoodCategory.find("dairy")!
        let item = FoodItem.make(category: cat)
        context.insert(item)
        context.insert(ConsumptionLog(catId: "dairy", action: .ate))
        try context.save()

        let items = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(items.count == 1)
        #expect(items.first?.catId == "dairy")

        let logs = try context.fetch(FetchDescriptor<ConsumptionLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.action == .ate)
    }
}
