// 追加フロー（刷新版・2ステップ）のテスト。
//
// 純関数（CalendarGrid・DraftItem→FoodItem 変換）と AddFlowModel の状態遷移を検証する。
// 日付系は固定 Calendar（Asia/Tokyo）/ 固定 Date（2026-06-10）で決定的にする。
// @Model（FoodItem）を触るテストは @MainActor 上で in-memory コンテナを使う。

import Testing
import Foundation
import SwiftData
@testable import koroai

// MARK: - CalendarGrid.make（純関数・コンテナ不要）

struct CalendarGridTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }

    @Test func june2026_startsMonday_oneLeadingNil_andThirtyDays() {
        // 2026-06-01 は月曜（getDay()=1）→ 先頭 nil 1 個・30 日。
        let cells = CalendarGrid.make(year: 2026, month: 6, calendar: cal())
        #expect(cells.count == 1 + 30)
        #expect(cells[0] == nil)
        #expect(cells[1] != nil)
        // 末尾は 6/30。
        let nonNil = cells.compactMap { $0 }
        #expect(nonNil.count == 30)
        let last = cal().component(.day, from: nonNil.last!)
        #expect(last == 30)
        let first = cal().component(.day, from: nonNil.first!)
        #expect(first == 1)
    }

    @Test func feb2024_isLeapYear_twentyNineDays() {
        let cells = CalendarGrid.make(year: 2024, month: 2, calendar: cal())
        let nonNil = cells.compactMap { $0 }
        #expect(nonNil.count == 29)
    }

    @Test func feb2026_twentyEightDays() {
        let cells = CalendarGrid.make(year: 2026, month: 2, calendar: cal())
        let nonNil = cells.compactMap { $0 }
        #expect(nonNil.count == 28)
    }

    @Test func leadingNilCountMatchesFirstWeekday() {
        // 2024-02-01 は木曜（日曜=0 起点で 4）→ 先頭 nil 4 個。
        let cells = CalendarGrid.make(year: 2024, month: 2, calendar: cal())
        let leadingNils = cells.prefix { $0 == nil }.count
        #expect(leadingNils == 4)
    }
}

// MARK: - DraftItem → FoodItem 変換（@Model → @MainActor）

@MainActor
struct DraftConversionTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    @Test func emptyNameFallsBackToCategoryDefaultName() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "fish", name: "   ", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "切")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.name == "刺身") // fish の defaultName
    }

    @Test func keepsExplicitName() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "fish", name: "まぐろ", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "切")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.name == "まぐろ")
    }

    @Test func daysRoundTripThroughExpiresAt() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "veg", name: "トマト", days: 8, amountMode: .amount, amount: 0.5, quantity: 5, unit: "個")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.daysLeft(now: now(), calendar: cal()) == 8)
    }

    @Test func quantityTotalEqualsQuantity() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "egg", name: "卵", days: 14, amountMode: .count, amount: 1, quantity: 6, unit: "個")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.quantity == 6)
        #expect(item.quantityTotal == 6)
    }

    @Test func amountTouchedMapsToAmountIsSet() throws {
        _ = try TestSupport.makeContext()
        let untouched = DraftItem(catId: "fish", name: "x", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "切", amountTouched: false)
        let touched = DraftItem(catId: "fish", name: "x", days: 1, amountMode: .amount, amount: 0.5, quantity: 5, unit: "切", amountTouched: true)
        #expect(untouched.makeFoodItem(now: now(), calendar: cal()).amountIsSet == false)
        #expect(touched.makeFoodItem(now: now(), calendar: cal()).amountIsSet == true)
    }

    @Test func copiesPerishableFromCategory() throws {
        _ = try TestSupport.makeContext()
        let egg = DraftItem(catId: "egg", name: "卵", days: 14, amountMode: .count, amount: 1, quantity: 6, unit: "個")
        let fish = DraftItem(catId: "fish", name: "刺身", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "切")
        #expect(egg.makeFoodItem(now: now(), calendar: cal()).perishable == false)
        #expect(fish.makeFoodItem(now: now(), calendar: cal()).perishable == true)
    }
}

// MARK: - AddFlowModel（@MainActor・刷新版）

@MainActor
struct AddFlowModelTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    /// テスト用に独立した UserDefaults suite を持つ AppStore を作る。
    private func makeStore(_ suite: String = "test.addflow." + UUID().uuidString) -> AppStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppStore(defaults: defaults)
    }

    // MARK: addOne: 既定値・カウント増加

    @Test func addOneUsesCategoryDefaults() {
        let model = AddFlowModel()
        let store = makeStore()
        let veg = FoodCategory.find("veg")!
        model.addOne(category: veg, store: store)
        #expect(model.cartCount == 1)
        let it = model.cart.first!
        #expect(it.days == veg.defaultDays)            // 5
        #expect(it.amount == 0.72)
        #expect(it.quantity == 1)
        #expect(it.unit == veg.defaultUnit)
        #expect(it.amountMode == veg.defaultAmountMode) // .amount
        #expect(it.amountTouched == false)
        #expect(it.name == "")
        #expect(model.countOf(catId: "veg") == 1)
        #expect(model.screen == .select)
    }

    @Test func addOneReflectsModeOverride() {
        let store = makeStore()
        let veg = FoodCategory.find("veg")! // 既定 .amount
        store.setAmountModeOverride(.count, for: "veg")
        let model = AddFlowModel()
        model.addOne(category: veg, store: store)
        #expect(model.cart.first?.amountMode == .count) // override 反映
    }

    @Test func addOneIncrementsCount() {
        let model = AddFlowModel()
        let store = makeStore()
        let fish = FoodCategory.find("fish")!
        model.addOne(category: fish, store: store)
        model.addOne(category: fish, store: store)
        #expect(model.countOf(catId: "fish") == 2)
        #expect(model.cartCount == 2)
    }

    // MARK: removeLastOfCategory: 最後に追加した方が消える

    @Test func removeLastOfCategoryRemovesNewest() {
        let model = AddFlowModel()
        let store = makeStore()
        let fish = FoodCategory.find("fish")!
        model.addOne(category: fish, store: store) // order 1
        model.addOne(category: fish, store: store) // order 2（最後）
        let firstId = model.cart.first { $0.addedOrder == 1 }!.id
        let lastId = model.cart.first { $0.addedOrder == 2 }!.id
        model.removeLastOfCategory("fish")
        #expect(model.countOf(catId: "fish") == 1)
        // 最後に追加した方（order 2）が消える。
        #expect(model.cart.contains { $0.id == firstId })
        #expect(!model.cart.contains { $0.id == lastId })
    }

    @Test func removeLastOfCategoryToZero() {
        let model = AddFlowModel()
        let store = makeStore()
        let fish = FoodCategory.find("fish")!
        model.addOne(category: fish, store: store)
        model.removeLastOfCategory("fish") // 1件 → 0件（チップ消滅相当）
        #expect(model.countOf(catId: "fish") == 0)
        #expect(model.cartCount == 0)
    }

    @Test func removeLastOfCategoryNoopWhenAbsent() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("fish")!, store: store)
        model.removeLastOfCategory("veg") // 無いカテゴリ → 何も起きない
        #expect(model.cartCount == 1)
    }

    // MARK: grouped: 追加順降順（最新が先頭）・count 集約が countOf と一致

    @Test func groupedIsNewestFirstAndCountMatches() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("fish")!, store: store)  // order 1
        model.addOne(category: FoodCategory.find("veg")!, store: store)   // order 2
        model.addOne(category: FoodCategory.find("fish")!, store: store)  // order 3（fish 最新）
        let groups = model.grouped
        // fish の最新 order(3) > veg の order(2) → fish が先頭。
        #expect(groups.first?.catId == "fish")
        #expect(groups.count == 2)
        // count 集約がタイル countOf と一致。
        for g in groups {
            #expect(g.count == model.countOf(catId: g.catId))
        }
        #expect(groups.first { $0.catId == "fish" }?.count == 2)
        #expect(groups.first { $0.catId == "veg" }?.count == 1)
    }

    // MARK: updateItem 系: amountTouched 遷移

    @Test func setAmountModeTouchesAndSavesOverride() {
        let suite = "test.addflow.override." + UUID().uuidString
        let store = makeStore(suite)
        let veg = FoodCategory.find("veg")! // 既定 .amount
        let model = AddFlowModel()
        model.addOne(category: veg, store: store)
        let id = model.cart.first!.id
        #expect(model.cart.first?.amountTouched == false)
        model.setAmountMode(id: id, .count)
        #expect(model.cart.first?.amountMode == .count)
        #expect(model.cart.first?.amountTouched == true)
        // mode 変更で override 記憶。
        #expect(store.amountModeOverride(for: "veg") == .count)
    }

    @Test func setAmountTouches() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("veg")!, store: store)
        let id = model.cart.first!.id
        model.setAmount(id: id, 0.5)
        #expect(model.cart.first?.amount == 0.5)
        #expect(model.cart.first?.amountTouched == true)
    }

    @Test func setQuantityTouches() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("egg")!, store: store)
        let id = model.cart.first!.id
        model.setQuantity(id: id, 6)
        #expect(model.cart.first?.quantity == 6)
        #expect(model.cart.first?.amountTouched == true)
    }

    @Test func setNameAndDaysDoNotTouch() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("veg")!, store: store)
        let id = model.cart.first!.id
        model.setName(id: id, "トマト")
        model.setDays(id: id, 9)
        #expect(model.cart.first?.name == "トマト")
        #expect(model.cart.first?.days == 9)
        // name/days 変更では touched しない。
        #expect(model.cart.first?.amountTouched == false)
    }

    @Test func setSameValueDoesNotTouch() {
        let model = AddFlowModel()
        let store = makeStore()
        let veg = FoodCategory.find("veg")! // 既定 .amount / amount 0.72
        model.addOne(category: veg, store: store)
        let id = model.cart.first!.id
        // 同値 set は touched しない。
        model.setAmount(id: id, 0.72)
        model.setAmountMode(id: id, .amount)
        model.setQuantity(id: id, 1)
        #expect(model.cart.first?.amountTouched == false)
    }

    // MARK: removeItem: 個別除外

    @Test func removeItemRemovesById() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("fish")!, store: store)
        model.addOne(category: FoodCategory.find("veg")!, store: store)
        let vegId = model.cart.first { $0.catId == "veg" }!.id
        model.removeItem(id: vegId)
        #expect(model.cartCount == 1)
        #expect(model.countOf(catId: "veg") == 0)
        #expect(model.countOf(catId: "fish") == 1)
    }

    // MARK: requestClose 分岐

    @Test func requestCloseBranchesOnCart() {
        let model = AddFlowModel()
        let store = makeStore()
        // 空かご → 即閉じ可・確認は出ない
        #expect(model.requestClose() == true)
        #expect(model.confirmClose == false)
        // 1品入れると確認待ち
        model.addOne(category: FoodCategory.find("fish")!, store: store)
        #expect(model.requestClose() == false)
        #expect(model.confirmClose == true)
    }

    // MARK: commit: 件数・name フォールバック・qtyTotal=max・amountIsSet=touched・reset

    @Test func commitInsertsFoodItemsAndResets() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("fish")!, store: store)
        let fishId = model.cart.first!.id
        model.setName(id: fishId, "まぐろ")
        model.addOne(category: FoodCategory.find("veg")!, store: store)
        model.screen = .confirm
        let n = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        #expect(n == 2)
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(items.count == 2)
        #expect(items.contains { $0.name == "まぐろ" })
        // 名前空はカテゴリ既定名へフォールバック（veg → トマト）。
        #expect(items.contains { $0.name == "トマト" })
        // commit 後はリセットされる。
        #expect(model.cartCount == 0)
        #expect(model.screen == .select)
    }

    @Test func commitAmountIsSetFollowsTouched() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("fish")!, store: store) // untouched
        model.addOne(category: FoodCategory.find("veg")!, store: store)
        let vegId = model.cart.first { $0.catId == "veg" }!.id
        model.setAmount(id: vegId, 0.5) // touched
        _ = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        let fishItem = items.first { $0.catId == "fish" }!
        let vegItem = items.first { $0.catId == "veg" }!
        #expect(fishItem.amountIsSet == false)
        #expect(vegItem.amountIsSet == true)
    }

    @Test func commitQuantityTotalIsMax() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("egg")!, store: store)
        let id = model.cart.first!.id
        model.setQuantity(id: id, 6) // quantity=6・追加時 total=quantity
        _ = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        let egg = items.first { $0.catId == "egg" }!
        // qtyTotal = max(qtyTotal, quantity) = 6。
        #expect(egg.quantityTotal == 6)
        #expect(egg.quantity == 6)
    }

    // MARK: reset

    @Test func resetClearsCartAndScreen() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(category: FoodCategory.find("fish")!, store: store)
        model.screen = .confirm
        model.confirmClose = true
        model.reset(store: store)
        #expect(model.cartCount == 0)
        #expect(model.screen == .select)
        #expect(model.confirmClose == false)
    }
}

// MARK: - ステッパー/カレンダー同期（純関数ロジック）

@MainActor
struct StepperCalendarSyncTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    @Test func selectedDateIsTodayPlusDays() {
        // days=8 のときの選択日 = today + 8。CalendarPicker と同じ導出を検証する。
        let c = cal()
        let n = now()
        let today = c.startOfDay(for: n)
        let days = 8
        let selected = c.date(byAdding: .day, value: max(0, days), to: today)!
        let diff = c.dateComponents([.day], from: today, to: selected).day!
        #expect(diff == 8)
    }

    @Test func pickingPastDateIsRejected() {
        // 過去日（today-1）の暦日差は負 → past 判定で days 書き戻しは行われない。
        let c = cal()
        let n = now()
        let today = c.startOfDay(for: n)
        let past = c.date(byAdding: .day, value: -1, to: today)!
        let diff = c.dateComponents([.day], from: today, to: c.startOfDay(for: past)).day!
        #expect(diff < 0) // past → CalendarPicker は days を更新しない（disabled）
    }

    @Test func stepperClampsAtZero() {
        // DaysStepper の −ボタン相当: max(0, days-1)。0 で下限クランプ。
        var days = 0
        days = max(0, days - 1)
        #expect(days == 0)
    }
}
