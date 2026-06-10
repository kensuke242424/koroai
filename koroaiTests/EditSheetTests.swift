// 編集シート（Step 5）のテスト。
//
// 純関数（EditPatch のパッチ計算）と EditSheetModel の状態遷移を検証する。
// 日付系は固定 Calendar（Asia/Tokyo）/ 固定 Date（2026-06-10）で決定的にする。
// @Model（FoodItem）を触るテストは @MainActor 上で in-memory コンテナを使う。

import Testing
import Foundation
import SwiftData
@testable import koroai

// MARK: - EditPatch（パッチ計算・@MainActor で FoodItem を触る）

@MainActor
struct EditPatchTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    /// テスト用の FoodItem を in-memory context に insert して返す。
    private func makeItem(
        context: ModelContext,
        catId: String = "veg",
        name: String = "トマト",
        days: Int = 5,
        amountMode: AmountMode = .amount,
        amount: Double = 1,
        quantity: Int = 1,
        quantityTotal: Int = 1,
        unit: String = "個",
        amountIsSet: Bool = false
    ) -> FoodItem {
        let cat = FoodCategory.find(catId)!
        let item = FoodItem(
            catId: catId,
            name: name,
            purchasedAt: now(),
            expiresAt: DateMath.expiryDate(daysFromNow: days, from: now(), calendar: cal()),
            perishable: cat.perishable,
            amountMode: amountMode,
            amount: amount,
            quantity: quantity,
            quantityTotal: quantityTotal,
            unit: unit,
            amountIsSet: amountIsSet
        )
        context.insert(item)
        return item
    }

    @Test func emptyNameFallsBackToCategoryName() throws {
        let context = try TestSupport.makeContext()
        let item = makeItem(context: context, catId: "fish")
        let patch = EditPatch(catId: "fish", name: "   ", days: 1, amountMode: .amount,
                              amount: 1, quantity: 1, unit: "切", amountTouched: false)
        patch.apply(to: item, now: now(), calendar: cal())
        // FKEditSheet は cat.name へフォールバック（defaultName=刺身 ではなく name=魚・刺身）。
        #expect(item.name == "魚・刺身")
        #expect(FoodCategory.find("fish")!.defaultName == "刺身") // 念のため別物であることを確認
    }

    @Test func keepsExplicitTrimmedName() throws {
        let context = try TestSupport.makeContext()
        let item = makeItem(context: context, catId: "fish")
        let patch = EditPatch(catId: "fish", name: "  まぐろ  ", days: 1, amountMode: .amount,
                              amount: 1, quantity: 1, unit: "切", amountTouched: false)
        patch.apply(to: item, now: now(), calendar: cal())
        #expect(item.name == "まぐろ")
    }

    @Test func daysRoundTripThroughExpiresAt() throws {
        let context = try TestSupport.makeContext()
        let item = makeItem(context: context, catId: "veg", days: 5)
        let patch = EditPatch(catId: "veg", name: "トマト", days: 9, amountMode: .amount,
                              amount: 0.5, quantity: 1, unit: "個", amountTouched: false)
        patch.apply(to: item, now: now(), calendar: cal())
        #expect(item.daysLeft(now: now(), calendar: cal()) == 9)
    }

    @Test func quantityTotalGrowsWhenIncreasedAbove() throws {
        let context = try TestSupport.makeContext()
        // 初期 quantity=3 / total=3 を 5 へ増やす → total も 5 へ追従。
        let item = makeItem(context: context, catId: "egg", amountMode: .count,
                            quantity: 3, quantityTotal: 3, unit: "個")
        let patch = EditPatch(catId: "egg", name: "卵", days: 14, amountMode: .count,
                              amount: 1, quantity: 5, unit: "個", amountTouched: true)
        patch.apply(to: item, now: now(), calendar: cal())
        #expect(item.quantity == 5)
        #expect(item.quantityTotal == 5)
    }

    @Test func quantityTotalHeldWhenDecreased() throws {
        let context = try TestSupport.makeContext()
        // 初期 quantity=6 / total=10 を 4 へ減らす → total は据え置き 10。
        let item = makeItem(context: context, catId: "egg", amountMode: .count,
                            quantity: 6, quantityTotal: 10, unit: "個")
        let patch = EditPatch(catId: "egg", name: "卵", days: 14, amountMode: .count,
                              amount: 1, quantity: 4, unit: "個", amountTouched: true)
        patch.apply(to: item, now: now(), calendar: cal())
        #expect(item.quantity == 4)
        #expect(item.quantityTotal == 10)
    }

    @Test func amountIsSetTransitionsTrueOnlyWhenTouched() throws {
        let context = try TestSupport.makeContext()
        // 既存 false・touched なし → false のまま。
        let untouchedItem = makeItem(context: context, amountIsSet: false)
        let untouched = EditPatch(catId: "veg", name: "トマト", days: 5, amountMode: .amount,
                                  amount: 1, quantity: 1, unit: "個", amountTouched: false)
        untouched.apply(to: untouchedItem, now: now(), calendar: cal())
        #expect(untouchedItem.amountIsSet == false)

        // 既存 false・touched あり → true へ。
        let touchedItem = makeItem(context: context, amountIsSet: false)
        let touched = EditPatch(catId: "veg", name: "トマト", days: 5, amountMode: .amount,
                                amount: 0.5, quantity: 1, unit: "個", amountTouched: true)
        touched.apply(to: touchedItem, now: now(), calendar: cal())
        #expect(touchedItem.amountIsSet == true)
    }

    @Test func amountIsSetStaysTrueWhenAlreadySetAndUntouched() throws {
        let context = try TestSupport.makeContext()
        // 既 true・touched なし → true を維持（false に落とさない）。
        let item = makeItem(context: context, amountIsSet: true)
        let patch = EditPatch(catId: "veg", name: "トマト", days: 5, amountMode: .amount,
                              amount: 1, quantity: 1, unit: "個", amountTouched: false)
        patch.apply(to: item, now: now(), calendar: cal())
        #expect(item.amountIsSet == true)
    }
}

// MARK: - EditSheetModel（@MainActor）

@MainActor
struct EditSheetModelTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    private func makeStore(_ suite: String = "test.editsheet." + UUID().uuidString) -> AppStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppStore(defaults: defaults)
    }

    private func makeItem(
        context: ModelContext,
        catId: String = "veg",
        name: String = "トマト",
        days: Int = 5,
        amountMode: AmountMode = .amount,
        amount: Double = 0.5,
        quantity: Int = 2,
        quantityTotal: Int = 4,
        unit: String = "個"
    ) -> FoodItem {
        let cat = FoodCategory.find(catId)!
        let item = FoodItem(
            catId: catId,
            name: name,
            purchasedAt: now(),
            expiresAt: DateMath.expiryDate(daysFromNow: days, from: now(), calendar: cal()),
            perishable: cat.perishable,
            amountMode: amountMode,
            amount: amount,
            quantity: quantity,
            quantityTotal: quantityTotal,
            unit: unit
        )
        context.insert(item)
        return item
    }

    @Test func beginLoadsItemFieldsAndDaysLeftWithoutTouching() throws {
        let context = try TestSupport.makeContext()
        let store = makeStore()
        let item = makeItem(context: context, name: "ミニトマト", days: 5,
                            amountMode: .amount, amount: 0.5, quantity: 2, quantityTotal: 4, unit: "個")
        let model = EditSheetModel()
        model.begin(item: item, store: store, now: now(), calendar: cal())
        #expect(model.name == "ミニトマト")
        #expect(model.days == item.daysLeft(now: now(), calendar: cal())) // == 5
        #expect(model.days == 5)
        #expect(model.amountMode == .amount)
        #expect(model.amount == 0.5)
        #expect(model.quantity == 2)
        #expect(model.quantityTotal == 4)
        #expect(model.unit == "個")
        #expect(model.amountTouched == false) // 初期化では touched しない
    }

    @Test func modeSwitchSavesOverrideAndTouches() throws {
        let context = try TestSupport.makeContext()
        let store = makeStore()
        let item = makeItem(context: context, catId: "veg", amountMode: .amount)
        let model = EditSheetModel()
        model.begin(item: item, store: store, now: now(), calendar: cal())
        #expect(model.amountMode == .amount)
        model.amountMode = .count
        #expect(model.amountTouched == true)
        #expect(store.amountModeOverride(for: "veg") == .count)
    }

    @Test func beginDoesNotUpdateOverrideDuringInit() throws {
        let context = try TestSupport.makeContext()
        let store = makeStore()
        // item は count モード。begin で amountMode を count にセットしても override は書かれない。
        let item = makeItem(context: context, catId: "egg", amountMode: .count, quantity: 3, quantityTotal: 3, unit: "個")
        let model = EditSheetModel()
        model.begin(item: item, store: store, now: now(), calendar: cal())
        #expect(model.amountMode == .count)
        #expect(store.amountModeOverride(for: "egg") == nil) // 初期化中は override 非更新
        #expect(model.amountTouched == false)
    }

    @Test func saveAppliesPatchToItem() throws {
        let context = try TestSupport.makeContext()
        let store = makeStore()
        let item = makeItem(context: context, name: "トマト", days: 5,
                            amountMode: .count, quantity: 2, quantityTotal: 4, unit: "個")
        let model = EditSheetModel()
        model.begin(item: item, store: store, now: now(), calendar: cal())
        model.name = "ミニトマト"
        model.days = 9
        model.quantity = 6 // total(4) を超える → total も 6 へ
        model.save(item: item, context: context, now: now(), calendar: cal())
        #expect(item.name == "ミニトマト")
        #expect(item.daysLeft(now: now(), calendar: cal()) == 9)
        #expect(item.quantity == 6)
        #expect(item.quantityTotal == 6)
        #expect(item.amountIsSet == true) // quantity を触ったので set
    }
}


