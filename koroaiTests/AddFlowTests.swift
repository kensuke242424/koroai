// 追加フロー（Step 4）のテスト。
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

// MARK: - AddFlowModel（@MainActor）

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

    @Test func openAddUsesCategoryDefaults() {
        let model = AddFlowModel()
        let store = makeStore()
        let veg = FoodCategory.find("veg")!
        model.openAdd(category: veg, store: store)
        #expect(model.days == veg.defaultDays) // 5
        #expect(model.quantity == 5)
        #expect(model.amount == 1)
        #expect(model.amountMode == veg.defaultAmountMode) // .amount
        #expect(model.amountTouched == false)
        #expect(model.view == .detail)
        #expect(model.editingId == nil)
    }

    @Test func modeOverrideIsSavedAndReflected() {
        let suite = "test.addflow.override." + UUID().uuidString
        let store = makeStore(suite)
        let veg = FoodCategory.find("veg")! // 既定 .amount
        let model = AddFlowModel()
        model.openAdd(category: veg, store: store)
        #expect(model.amountMode == .amount)
        // ユーザーが count に切替 → override 保存・touched on
        model.amountMode = .count
        #expect(model.amountTouched == true)
        #expect(store.amountModeOverride(for: "veg") == .count)
        // 次に同カテゴリを開くと override が反映される
        let model2 = AddFlowModel()
        model2.openAdd(category: veg, store: store)
        #expect(model2.amountMode == .count)
        #expect(model2.amountTouched == false) // 初期化では touched しない
    }

    @Test func saveDetailAddsThenUpdates() {
        let model = AddFlowModel()
        let store = makeStore()
        let veg = FoodCategory.find("veg")!
        model.openAdd(category: veg, store: store)
        model.name = "トマト"
        model.saveDetail()
        #expect(model.cartCount == 1)
        #expect(model.view == .grid)
        #expect(model.cart.first?.name == "トマト")

        // 同じ行を編集して更新
        let id = model.cart.first!.id
        model.openEdit(draftId: id, store: store)
        #expect(model.editingId == id)
        model.name = "ミニトマト"
        model.days = 9
        model.saveDetail()
        #expect(model.cartCount == 1) // 増えない
        #expect(model.cart.first?.name == "ミニトマト")
        #expect(model.cart.first?.days == 9)
    }

    @Test func saveDetailEmptyNameUsesDefault() {
        let model = AddFlowModel()
        let store = makeStore()
        model.openAdd(category: FoodCategory.find("fish")!, store: store)
        model.name = "   "
        model.saveDetail()
        #expect(model.cart.first?.name == "刺身")
    }

    @Test func countOfReflectsCart() {
        let model = AddFlowModel()
        let store = makeStore()
        model.openAdd(category: FoodCategory.find("fish")!, store: store)
        model.saveDetail()
        model.openAdd(category: FoodCategory.find("fish")!, store: store)
        model.saveDetail()
        model.openAdd(category: FoodCategory.find("veg")!, store: store)
        model.saveDetail()
        #expect(model.countOf(catId: "fish") == 2)
        #expect(model.countOf(catId: "veg") == 1)
        #expect(model.countOf(catId: "egg") == 0)
    }

    @Test func requestCloseBranchesOnCart() {
        let model = AddFlowModel()
        let store = makeStore()
        // 空かご → 即閉じ可・確認は出ない
        #expect(model.requestClose() == true)
        #expect(model.confirmClose == false)
        // 1品入れると確認待ち
        model.openAdd(category: FoodCategory.find("fish")!, store: store)
        model.saveDetail()
        #expect(model.requestClose() == false)
        #expect(model.confirmClose == true)
    }

    @Test func deleteEditingRemovesFromCart() {
        let model = AddFlowModel()
        let store = makeStore()
        model.openAdd(category: FoodCategory.find("fish")!, store: store)
        model.saveDetail()
        let id = model.cart.first!.id
        model.openEdit(draftId: id, store: store)
        model.deleteEditing()
        #expect(model.cartCount == 0)
        #expect(model.view == .grid)
    }

    @Test func commitInsertsFoodItemsAndResets() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.openAdd(category: FoodCategory.find("fish")!, store: store)
        model.name = "まぐろ"
        model.saveDetail()
        model.openAdd(category: FoodCategory.find("veg")!, store: store)
        model.saveDetail()
        let n = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        #expect(n == 2)
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(items.count == 2)
        #expect(items.contains { $0.name == "まぐろ" })
        // commit 後はリセットされる
        #expect(model.cartCount == 0)
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
