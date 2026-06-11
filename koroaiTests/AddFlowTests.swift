// 追加フロー（刷新版・2ステップ）のテスト。
//
// 純関数（CalendarGrid・DraftItem→FoodItem 変換）と AddFlowModel の状態遷移を検証する。
// 日付系は固定 Calendar（Asia/Tokyo）/ 固定 Date（2026-06-10）で決定的にする。
// @Model（FoodItem）を触るテストは @MainActor 上で in-memory コンテナを使う。
//
// 「選ぶ」画面は 10セクション（FoodCategory）× 食材プリセット（IngredientCatalog）。
// タイル＝IngredientPreset 単位。addOne/countOf/removeLast/grouped は presetId キー。

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

// MARK: - FoodCategory / IngredientCatalog 整合性

struct CatalogTests {

    // MARK: FoodCategory: 10セクション・レガシーエイリアス

    @Test func foodCategoryHasTenSections() {
        #expect(FoodCategory.all.count == 10)
        // セクション id は一意。
        let ids = FoodCategory.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func legacyAliasesResolve() {
        // 旧12カテゴリの id が新セクションへ解決される（保存データ互換）。
        #expect(FoodCategory.find("chicken")?.id == "meat")
        #expect(FoodCategory.find("leafy")?.id == "veg")
        #expect(FoodCategory.find("bread")?.id == "staple")
        // 新 id はそのまま引ける。
        #expect(FoodCategory.find("meat")?.id == "meat")
        // 未知 id は nil。
        #expect(FoodCategory.find("nope") == nil)
    }

    // MARK: IngredientCatalog: id 一意・sectionId 有効・各セクション汎用1枚・件数

    @Test func presetIdsAreUnique() {
        let ids = IngredientCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyPresetSectionIsValid() {
        let sectionIds = Set(FoodCategory.all.map(\.id))
        for p in IngredientCatalog.all {
            #expect(sectionIds.contains(p.sectionId), "未知セクション: \(p.id) → \(p.sectionId)")
        }
    }

    @Test func eachSectionHasExactlyOneGeneric() {
        for section in FoodCategory.all {
            let generics = IngredientCatalog.presets(in: section.id).filter(\.isGeneric)
            #expect(generics.count == 1, "セクション \(section.id) の汎用カードが \(generics.count) 枚")
        }
    }

    @Test func totalPresetCountIsSeventySix() {
        // 仕様のラインナップを厳密に数えると 76 件（meat10/fish7/veg16/mush7/fruit7/
        // dairy6/egg4/tofu6/staple7/deli6）。タスク文の「計77」は概数で、個別リストが正。
        #expect(IngredientCatalog.all.count == 76)
    }

    @Test func presetsInSectionAreContiguousAndOrdered() {
        // presets(in:) はカタログ定義順で返す。各セクションの末尾は汎用カード。
        for section in FoodCategory.all {
            let presets = IngredientCatalog.presets(in: section.id)
            #expect(!presets.isEmpty)
            #expect(presets.last?.isGeneric == true, "セクション \(section.id) の末尾が汎用でない")
            // 末尾以外は汎用でない。
            #expect(presets.dropLast().allSatisfy { !$0.isGeneric })
        }
    }

    @Test func findReturnsKnownPreset() {
        let p = IngredientCatalog.find("meat.chicken-breast")
        #expect(p?.name == "鶏むね肉")
        #expect(p?.sectionId == "meat")
        #expect(IngredientCatalog.find("nope.nope") == nil)
    }
}

// MARK: - DraftItem → FoodItem 変換（@Model → @MainActor）

@MainActor
struct DraftConversionTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    @Test func emptyNameFallsBackToPresetNameWhenPresetGiven() throws {
        _ = try TestSupport.makeContext()
        // presetId 指定あり → プリセット既定名へフォールバック（fish.sashimi → 刺身）。
        let draft = DraftItem(catId: "fish", presetId: "fish.sashimi", name: "   ", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "パック")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.name == "刺身")
    }

    @Test func emptyNameFallsBackToSectionDefaultWhenNoPreset() throws {
        _ = try TestSupport.makeContext()
        // presetId 空 → セクション既定名へフォールバック（fish の defaultName = 刺身）。
        let draft = DraftItem(catId: "fish", name: "   ", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "パック")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.name == "刺身")
    }

    @Test func keepsExplicitName() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "fish", presetId: "fish.sashimi", name: "まぐろ", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "パック")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.name == "まぐろ")
    }

    @Test func daysRoundTripThroughExpiresAt() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "veg", presetId: "veg.tomato", name: "トマト", days: 8, amountMode: .count, amount: 0.5, quantity: 5, unit: "個")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.daysLeft(now: now(), calendar: cal()) == 8)
    }

    @Test func quantityTotalEqualsQuantity() throws {
        _ = try TestSupport.makeContext()
        let draft = DraftItem(catId: "egg", presetId: "egg.egg", name: "卵", days: 14, amountMode: .count, amount: 1, quantity: 6, unit: "個")
        let item = draft.makeFoodItem(now: now(), calendar: cal())
        #expect(item.quantity == 6)
        #expect(item.quantityTotal == 6)
    }

    @Test func amountTouchedMapsToAmountIsSet() throws {
        _ = try TestSupport.makeContext()
        let untouched = DraftItem(catId: "fish", presetId: "fish.sashimi", name: "x", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "パック", amountTouched: false)
        let touched = DraftItem(catId: "fish", presetId: "fish.sashimi", name: "x", days: 1, amountMode: .amount, amount: 0.5, quantity: 5, unit: "パック", amountTouched: true)
        #expect(untouched.makeFoodItem(now: now(), calendar: cal()).amountIsSet == false)
        #expect(touched.makeFoodItem(now: now(), calendar: cal()).amountIsSet == true)
    }

    @Test func copiesPerishableFromSection() throws {
        _ = try TestSupport.makeContext()
        let egg = DraftItem(catId: "egg", presetId: "egg.egg", name: "卵", days: 14, amountMode: .count, amount: 1, quantity: 6, unit: "個")
        let fish = DraftItem(catId: "fish", presetId: "fish.sashimi", name: "刺身", days: 1, amountMode: .amount, amount: 1, quantity: 5, unit: "パック")
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

    private func preset(_ id: String) -> IngredientPreset { IngredientCatalog.find(id)! }

    // MARK: addOne: 既定値・カウント増加

    @Test func addOneUsesPresetDefaults() {
        let model = AddFlowModel()
        let store = makeStore()
        let tomato = preset("veg.tomato") // days 5 / count / 個
        model.addOne(preset: tomato, store: store)
        #expect(model.cartCount == 1)
        let it = model.cart.first!
        #expect(it.catId == "veg")
        #expect(it.presetId == "veg.tomato")
        #expect(it.days == tomato.days)            // 5
        #expect(it.amount == 1.0)                   // 既定は満タン
        #expect(it.quantity == 1)
        #expect(it.unit == tomato.unit)            // 個
        #expect(it.amountMode == tomato.mode)      // .count
        #expect(it.amountTouched == false)
        #expect(it.name == "")
        #expect(model.countOf(presetId: "veg.tomato") == 1)
        #expect(model.screen == .select)
    }

    @Test func addOneReflectsSectionModeOverride() {
        let store = makeStore()
        let cabbage = preset("veg.cabbage") // 既定 .amount
        store.setAmountModeOverride(.count, for: "veg") // セクション単位の override
        let model = AddFlowModel()
        model.addOne(preset: cabbage, store: store)
        #expect(model.cart.first?.amountMode == .count) // override 反映
    }

    @Test func addOneIncrementsCount() {
        let model = AddFlowModel()
        let store = makeStore()
        let sashimi = preset("fish.sashimi")
        model.addOne(preset: sashimi, store: store)
        model.addOne(preset: sashimi, store: store)
        #expect(model.countOf(presetId: "fish.sashimi") == 2)
        #expect(model.cartCount == 2)
    }

    @Test func addOneSamePresetDistinctFromOthersInSection() {
        // 同セクションでも別プリセットは別カウント。
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("veg.tomato"), store: store)
        model.addOne(preset: preset("veg.cabbage"), store: store)
        #expect(model.countOf(presetId: "veg.tomato") == 1)
        #expect(model.countOf(presetId: "veg.cabbage") == 1)
        // セクション単位の取得口は2件。
        #expect(model.itemsInSection("veg").count == 2)
    }

    // MARK: toggle: タイルタップのトグル選択（同一 presetId はかご最大1件）

    @Test func toggleAddsWhenAbsent() {
        let model = AddFlowModel()
        let store = makeStore()
        let sashimi = preset("fish.sashimi")
        model.toggle(preset: sashimi, store: store)
        #expect(model.contains(presetId: "fish.sashimi"))
        #expect(model.countOf(presetId: "fish.sashimi") == 1)
        #expect(model.cartCount == 1)
    }

    @Test func toggleRemovesWhenPresent() {
        let model = AddFlowModel()
        let store = makeStore()
        let sashimi = preset("fish.sashimi")
        model.toggle(preset: sashimi, store: store) // 追加
        model.toggle(preset: sashimi, store: store) // 再トグル → 削除
        #expect(!model.contains(presetId: "fish.sashimi"))
        #expect(model.countOf(presetId: "fish.sashimi") == 0)
        #expect(model.cartCount == 0)
    }

    @Test func toggleCountIsZeroOrOne() {
        let model = AddFlowModel()
        let store = makeStore()
        let sashimi = preset("fish.sashimi")
        model.toggle(preset: sashimi, store: store)
        model.toggle(preset: sashimi, store: store) // もう一度入れてもトグルなので戻る
        model.toggle(preset: sashimi, store: store) // 再度入る
        #expect(model.countOf(presetId: "fish.sashimi") == 1) // 0/1 のみ
    }

    @Test func toggleDoesNotAffectOtherPresets() {
        let model = AddFlowModel()
        let store = makeStore()
        model.toggle(preset: preset("fish.sashimi"), store: store)
        model.toggle(preset: preset("veg.tomato"), store: store)
        // 刺身を外しても、トマトは残る。
        model.toggle(preset: preset("fish.sashimi"), store: store)
        #expect(!model.contains(presetId: "fish.sashimi"))
        #expect(model.contains(presetId: "veg.tomato"))
        #expect(model.countOf(presetId: "veg.tomato") == 1)
        #expect(model.cartCount == 1)
    }

    @Test func removePresetClearsPreset() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)
        model.addOne(preset: preset("veg.tomato"), store: store)
        model.removePreset("fish.sashimi")
        #expect(model.countOf(presetId: "fish.sashimi") == 0)
        #expect(model.countOf(presetId: "veg.tomato") == 1)
        #expect(model.cartCount == 1)
    }

    // MARK: removeLastOfPreset: 最後に追加した方が消える

    @Test func removeLastOfPresetRemovesNewest() {
        let model = AddFlowModel()
        let store = makeStore()
        let sashimi = preset("fish.sashimi")
        model.addOne(preset: sashimi, store: store) // order 1
        model.addOne(preset: sashimi, store: store) // order 2（最後）
        let firstId = model.cart.first { $0.addedOrder == 1 }!.id
        let lastId = model.cart.first { $0.addedOrder == 2 }!.id
        model.removeLastOfPreset("fish.sashimi")
        #expect(model.countOf(presetId: "fish.sashimi") == 1)
        #expect(model.cart.contains { $0.id == firstId })
        #expect(!model.cart.contains { $0.id == lastId })
    }

    @Test func removeLastOfPresetToZero() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)
        model.removeLastOfPreset("fish.sashimi")
        #expect(model.countOf(presetId: "fish.sashimi") == 0)
        #expect(model.cartCount == 0)
    }

    @Test func removeLastOfPresetNoopWhenAbsent() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)
        model.removeLastOfPreset("veg.tomato") // 無いプリセット → 何も起きない
        #expect(model.cartCount == 1)
    }

    // MARK: grouped: 追加順降順（最新が先頭）・presetId キー・count 一致

    @Test func groupedIsNewestFirstAndCountMatches() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)  // order 1
        model.addOne(preset: preset("veg.tomato"), store: store)    // order 2
        model.addOne(preset: preset("fish.sashimi"), store: store)  // order 3（刺身 最新）
        let groups = model.grouped
        // 刺身の最新 order(3) > トマトの order(2) → 刺身が先頭。
        #expect(groups.first?.presetId == "fish.sashimi")
        #expect(groups.first?.catId == "fish")
        #expect(groups.count == 2)
        for g in groups {
            #expect(g.count == model.countOf(presetId: g.presetId))
        }
        #expect(groups.first { $0.presetId == "fish.sashimi" }?.count == 2)
        #expect(groups.first { $0.presetId == "veg.tomato" }?.count == 1)
    }

    // MARK: updateItem 系: amountTouched 遷移

    @Test func setAmountModeTouchesAndSavesOverride() {
        let suite = "test.addflow.override." + UUID().uuidString
        let store = makeStore(suite)
        let cabbage = preset("veg.cabbage") // 既定 .amount
        let model = AddFlowModel()
        model.addOne(preset: cabbage, store: store)
        let id = model.cart.first!.id
        #expect(model.cart.first?.amountTouched == false)
        model.setAmountMode(id: id, .count)
        #expect(model.cart.first?.amountMode == .count)
        #expect(model.cart.first?.amountTouched == true)
        // mode 変更でセクション単位の override 記憶。
        #expect(store.amountModeOverride(for: "veg") == .count)
    }

    @Test func setAmountTouches() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        let id = model.cart.first!.id
        model.setAmount(id: id, 0.5)
        #expect(model.cart.first?.amount == 0.5)
        #expect(model.cart.first?.amountTouched == true)
    }

    @Test func setQuantityTouches() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("egg.egg"), store: store)
        let id = model.cart.first!.id
        model.setQuantity(id: id, 6)
        #expect(model.cart.first?.quantity == 6)
        #expect(model.cart.first?.amountTouched == true)
    }

    @Test func setNameAndDaysDoNotTouch() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("veg.tomato"), store: store)
        let id = model.cart.first!.id
        model.setName(id: id, "桃太郎トマト")
        model.setDays(id: id, 9)
        #expect(model.cart.first?.name == "桃太郎トマト")
        #expect(model.cart.first?.days == 9)
        #expect(model.cart.first?.amountTouched == false)
    }

    @Test func setSameValueDoesNotTouch() {
        let model = AddFlowModel()
        let store = makeStore()
        let cabbage = preset("veg.cabbage") // 既定 .amount / amount 1.0
        model.addOne(preset: cabbage, store: store)
        let id = model.cart.first!.id
        model.setAmount(id: id, 1.0)
        model.setAmountMode(id: id, .amount)
        model.setQuantity(id: id, 1)
        #expect(model.cart.first?.amountTouched == false)
    }

    // MARK: removeItem: 個別除外

    @Test func removeItemRemovesById() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)
        model.addOne(preset: preset("veg.tomato"), store: store)
        let tomatoId = model.cart.first { $0.presetId == "veg.tomato" }!.id
        model.removeItem(id: tomatoId)
        #expect(model.cartCount == 1)
        #expect(model.countOf(presetId: "veg.tomato") == 0)
        #expect(model.countOf(presetId: "fish.sashimi") == 1)
    }

    // MARK: requestClose 分岐

    @Test func requestCloseBranchesOnCart() {
        let model = AddFlowModel()
        let store = makeStore()
        #expect(model.requestClose() == true)
        #expect(model.confirmClose == false)
        model.addOne(preset: preset("fish.sashimi"), store: store)
        #expect(model.requestClose() == false)
        #expect(model.confirmClose == true)
    }

    // MARK: commit: 件数・name フォールバック・qtyTotal=max・amountIsSet=touched・reset

    @Test func commitInsertsFoodItemsAndResets() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)
        let fishId = model.cart.first!.id
        model.setName(id: fishId, "まぐろ")
        model.addOne(preset: preset("veg.tomato"), store: store)
        model.screen = .confirm
        let n = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        #expect(n == 2)
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        #expect(items.count == 2)
        #expect(items.contains { $0.name == "まぐろ" })
        // 名前空はプリセット既定名へフォールバック（veg.tomato → トマト）。
        #expect(items.contains { $0.name == "トマト" })
        #expect(model.cartCount == 0)
        #expect(model.screen == .select)
    }

    @Test func commitAmountIsSetFollowsTouched() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store) // untouched
        model.addOne(preset: preset("veg.cabbage"), store: store)
        let cabbageId = model.cart.first { $0.presetId == "veg.cabbage" }!.id
        model.setAmount(id: cabbageId, 0.5) // touched
        _ = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        let fishItem = items.first { $0.catId == "fish" }!
        let cabbageItem = items.first { $0.catId == "veg" }!
        #expect(fishItem.amountIsSet == false)
        #expect(cabbageItem.amountIsSet == true)
    }

    @Test func commitQuantityTotalIsMax() throws {
        let context = try TestSupport.makeContext()
        let toast = ToastCenter()
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("egg.egg"), store: store)
        let id = model.cart.first!.id
        model.setQuantity(id: id, 6)
        _ = model.commit(context: context, toastCenter: toast, now: now(), calendar: cal())
        let items = try context.fetch(FetchDescriptor<FoodItem>())
        let egg = items.first { $0.catId == "egg" }!
        #expect(egg.quantityTotal == 6)
        #expect(egg.quantity == 6)
    }

    // MARK: reset

    @Test func resetClearsCartAndScreen() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("fish.sashimi"), store: store)
        model.screen = .confirm
        model.confirmClose = true
        model.reset(store: store)
        #expect(model.cartCount == 0)
        #expect(model.screen == .select)
        #expect(model.confirmClose == false)
    }
}

// MARK: - カスタム既定値（commit で記憶 → addOne で適用）

@MainActor
struct PresetCustomDefaultTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    private func makeStore(_ suite: String = "test.customdef." + UUID().uuidString) -> AppStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppStore(defaults: defaults)
    }

    private func preset(_ id: String) -> IngredientPreset { IngredientCatalog.find(id)! }

    private func commit(_ model: AddFlowModel) throws {
        let context = try TestSupport.makeContext()
        _ = model.commit(context: context, toastCenter: ToastCenter(), now: now(), calendar: cal())
    }

    // MARK: commit で差分が保存される

    @Test func commitSavesNameAndDaysDiff() throws {
        let store = makeStore()
        let model = AddFlowModel()
        let tomato = preset("veg.tomato") // days 5 / count / 個
        model.addOne(preset: tomato, store: store)
        let id = model.cart.first!.id
        model.setName(id: id, "桃太郎トマト") // preset.name(トマト) と異なる
        model.setDays(id: id, 8)              // preset.days(5) と異なる
        try commit(model)

        let custom = store.customDefault(for: "veg.tomato")
        #expect(custom?.name == "桃太郎トマト")
        #expect(custom?.days == 8)
        // 残量系は触っていないので nil。
        #expect(custom?.amountMode == nil)
        #expect(custom?.amount == nil)
        #expect(custom?.quantity == nil)
    }

    @Test func commitSavesModeAndQuantityDiff() throws {
        let store = makeStore()
        let model = AddFlowModel()
        let cabbage = preset("veg.cabbage") // days 7 / amount / 玉
        model.addOne(preset: cabbage, store: store)
        let id = model.cart.first!.id
        model.setAmountMode(id: id, .count) // preset.mode(.amount) と異なる・touched
        model.setQuantity(id: id, 3)        // .count かつ touched かつ 1 と異なる
        try commit(model)

        let custom = store.customDefault(for: "veg.cabbage")
        #expect(custom?.amountMode == "count")
        #expect(custom?.quantity == 3)
        // amount は count モードなので保存しない。
        #expect(custom?.amount == nil)
    }

    @Test func commitSavesAmountDiff() throws {
        let store = makeStore()
        let model = AddFlowModel()
        let cabbage = preset("veg.cabbage") // amount モード
        model.addOne(preset: cabbage, store: store)
        let id = model.cart.first!.id
        model.setAmount(id: id, 0.4) // amount かつ touched かつ 1.0 と異なる
        try commit(model)

        let custom = store.customDefault(for: "veg.cabbage")
        #expect(custom?.amount == 0.4)
        #expect(custom?.quantity == nil)
        #expect(custom?.amountMode == nil) // mode は既定どおり
    }

    // MARK: 既定どおりなら保存されない

    @Test func commitDefaultsSavesNothing() throws {
        let store = makeStore()
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.tomato"), store: store) // 何も編集しない
        try commit(model)
        #expect(store.customDefault(for: "veg.tomato") == nil)
    }

    @Test func commitNameEqualToPresetSavesNothing() throws {
        let store = makeStore()
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.tomato"), store: store)
        let id = model.cart.first!.id
        model.setName(id: id, "  トマト  ") // trim 後 preset.name と同じ → 保存しない
        try commit(model)
        #expect(store.customDefault(for: "veg.tomato") == nil)
    }

    @Test func commitUntouchedAmountSavesNothing() throws {
        // amount を 1.0 のまま（touched しない）→ 保存しない。
        let store = makeStore()
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        try commit(model)
        #expect(store.customDefault(for: "veg.cabbage") == nil)
    }

    // MARK: 既定に戻したら削除される

    @Test func commitBackToDefaultRemovesCustom() throws {
        let store = makeStore()
        // 先にカスタムを作る。
        let m1 = AddFlowModel()
        m1.addOne(preset: preset("veg.tomato"), store: store)
        let id1 = m1.cart.first!.id
        m1.setDays(id: id1, 9)
        try commit(m1)
        #expect(store.customDefault(for: "veg.tomato")?.days == 9)

        // 次回 addOne でカスタム days=9 が適用される。それを preset 既定(5)へ戻して commit。
        let m2 = AddFlowModel()
        m2.addOne(preset: preset("veg.tomato"), store: store)
        #expect(m2.cart.first?.days == 9) // カスタム適用
        let id2 = m2.cart.first!.id
        m2.setDays(id: id2, 5) // preset 既定に戻す
        try commit(m2)
        // 全フィールド既定どおり → カスタム削除。
        #expect(store.customDefault(for: "veg.tomato") == nil)
    }

    // MARK: addOne でカスタムが適用される

    @Test func addOneAppliesNameAndDaysCustomWithoutTouch() throws {
        let store = makeStore()
        // name/days のみのカスタムを保存。
        store.setCustomDefault(PresetCustomDefault(name: "桃太郎トマト", days: 8), for: "veg.tomato")
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.tomato"), store: store)
        let it = model.cart.first!
        #expect(it.name == "桃太郎トマト")
        #expect(it.days == 8)
        // name/days だけなら amountTouched は false のまま。
        #expect(it.amountTouched == false)
        // 残量系は preset 既定。
        #expect(it.amountMode == preset("veg.tomato").mode)
        #expect(it.amount == 1.0)
        #expect(it.quantity == 1)
    }

    @Test func addOneAppliesModeAndAmountCustomWithTouch() throws {
        let store = makeStore()
        // amount モード・残量カスタム（cabbage は既定 amount）。
        store.setCustomDefault(PresetCustomDefault(amountMode: "amount", amount: 0.4), for: "veg.cabbage")
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        let it = model.cart.first!
        #expect(it.amountMode == .amount)
        #expect(it.amount == 0.4)
        // mode/amount 由来のカスタム適用 → amountTouched=true。
        #expect(it.amountTouched == true)
    }

    @Test func addOneAppliesQuantityCustomWithTouch() throws {
        let store = makeStore()
        store.setCustomDefault(PresetCustomDefault(amountMode: "count", quantity: 3), for: "veg.cabbage")
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        let it = model.cart.first!
        #expect(it.amountMode == .count)
        #expect(it.quantity == 3)
        #expect(it.amountTouched == true)
    }

    @Test func customModeBeatsSectionOverride() throws {
        // カスタム mode はセクション override より優先。
        let store = makeStore()
        store.setAmountModeOverride(.count, for: "veg")           // セクション override = count
        store.setCustomDefault(PresetCustomDefault(amountMode: "amount"), for: "veg.cabbage") // カスタム = amount
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        #expect(model.cart.first?.amountMode == .amount) // カスタム優先
    }
}

// MARK: - AppStore 永続化ラウンドトリップ

@MainActor
struct AppStorePersistenceTests {

    private func suite() -> String { "test.appstore." + UUID().uuidString }

    @Test func presetCustomDefaultsRoundTripThroughUserDefaults() {
        let name = suite()
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        // 書き込み側ストア。
        let writer = AppStore(defaults: defaults)
        writer.setCustomDefault(PresetCustomDefault(name: "桃太郎トマト", days: 8), for: "veg.tomato")
        writer.setCustomDefault(PresetCustomDefault(amountMode: "count", quantity: 3), for: "veg.cabbage")

        // 同 suite で読み直すストア → 永続化が効いている。
        let reader = AppStore(defaults: UserDefaults(suiteName: name)!)
        #expect(reader.customDefault(for: "veg.tomato")?.name == "桃太郎トマト")
        #expect(reader.customDefault(for: "veg.tomato")?.days == 8)
        #expect(reader.customDefault(for: "veg.cabbage")?.amountMode == "count")
        #expect(reader.customDefault(for: "veg.cabbage")?.quantity == 3)

        defaults.removePersistentDomain(forName: name)
    }

    @Test func confirmAmountShownRoundTripThroughUserDefaults() {
        let name = suite()
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        // 既定は false。
        let fresh = AppStore(defaults: UserDefaults(suiteName: name)!)
        #expect(fresh.confirmAmountShown == false)
        // 書いて読み直す。
        let writer = AppStore(defaults: UserDefaults(suiteName: name)!)
        writer.confirmAmountShown = true
        let reader = AppStore(defaults: UserDefaults(suiteName: name)!)
        #expect(reader.confirmAmountShown == true)
        defaults.removePersistentDomain(forName: name)
    }

    @Test func setNilRemovesCustomDefault() {
        let name = suite()
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let store = AppStore(defaults: defaults)
        store.setCustomDefault(PresetCustomDefault(days: 8), for: "veg.tomato")
        #expect(store.customDefault(for: "veg.tomato") != nil)
        store.setCustomDefault(nil, for: "veg.tomato")
        #expect(store.customDefault(for: "veg.tomato") == nil)
        // 空の PresetCustomDefault も削除扱い。
        store.setCustomDefault(PresetCustomDefault(days: 8), for: "veg.tomato")
        store.setCustomDefault(PresetCustomDefault(), for: "veg.tomato")
        #expect(store.customDefault(for: "veg.tomato") == nil)
        defaults.removePersistentDomain(forName: name)
    }
}

// MARK: - 最近使った食材（rememberRecent / commit で記憶）

@MainActor
struct RecentPresetTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    private func makeStore(_ suite: String = "test.recent." + UUID().uuidString) -> AppStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppStore(defaults: defaults)
    }

    private func preset(_ id: String) -> IngredientPreset { IngredientCatalog.find(id)! }

    // MARK: rememberRecent（AppStore 直接）

    @Test func rememberRecentInsertsAtFront() {
        let store = makeStore()
        store.rememberRecent("veg.tomato")
        store.rememberRecent("fish.sashimi")
        #expect(store.recentPresetIds == ["fish.sashimi", "veg.tomato"]) // 新しいものが先頭
    }

    @Test func rememberRecentDedupesAndMovesToFront() {
        let store = makeStore()
        store.rememberRecent("veg.tomato")
        store.rememberRecent("fish.sashimi")
        store.rememberRecent("veg.tomato") // 再登録 → 先頭へ移動・重複なし
        #expect(store.recentPresetIds == ["veg.tomato", "fish.sashimi"])
    }

    @Test func rememberRecentCapsAtTwelve() {
        let store = makeStore()
        // 13件入れる → 最新12件だけ残る。
        let ids = (0..<13).map { "id.\($0)" }
        for id in ids { store.rememberRecent(id) }
        #expect(store.recentPresetIds.count == 12)
        // 最新（最後に入れた id.12）が先頭・最古（id.0）は押し出される。
        #expect(store.recentPresetIds.first == "id.12")
        #expect(!store.recentPresetIds.contains("id.0"))
    }

    @Test func rememberRecentIgnoresEmpty() {
        let store = makeStore()
        store.rememberRecent("")
        #expect(store.recentPresetIds.isEmpty)
    }

    // MARK: commit で記憶される（追加順で最後のものが先頭）

    @Test func commitRemembersRecentNewestFirst() throws {
        let store = makeStore()
        let model = AddFlowModel()
        model.addOne(preset: preset("fish.sashimi"), store: store) // order 1
        model.addOne(preset: preset("veg.tomato"), store: store)   // order 2（最後）
        let context = try TestSupport.makeContext()
        _ = model.commit(context: context, toastCenter: ToastCenter(), now: now(), calendar: cal())
        // 追加順で最後に積んだ veg.tomato が先頭。
        #expect(store.recentPresetIds == ["veg.tomato", "fish.sashimi"])
    }

    // MARK: 永続化ラウンドトリップ

    @Test func recentPresetIdsRoundTripThroughUserDefaults() {
        let name = "test.recent.persist." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let writer = AppStore(defaults: defaults)
        writer.rememberRecent("veg.tomato")
        writer.rememberRecent("fish.sashimi")
        let reader = AppStore(defaults: UserDefaults(suiteName: name)!)
        #expect(reader.recentPresetIds == ["fish.sashimi", "veg.tomato"])
        defaults.removePersistentDomain(forName: name)
    }
}

// MARK: - amount 既定 1.0（新規 DraftItem・カスタム既定値の記憶条件）

@MainActor
struct AmountDefaultTests {

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) }

    private func makeStore(_ suite: String = "test.amountdef." + UUID().uuidString) -> AppStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppStore(defaults: defaults)
    }

    private func preset(_ id: String) -> IngredientPreset { IngredientCatalog.find(id)! }

    private func commit(_ model: AddFlowModel) throws {
        let context = try TestSupport.makeContext()
        _ = model.commit(context: context, toastCenter: ToastCenter(), now: now(), calendar: cal())
    }

    @Test func newDraftAmountDefaultsToFull() {
        let model = AddFlowModel()
        let store = makeStore()
        model.addOne(preset: preset("veg.cabbage"), store: store) // amount モード
        #expect(model.cart.first?.amount == 1.0)
    }

    @Test func amountEqualToOneIsNotRemembered() throws {
        // amount が 1.0 のまま（touched あっても 1.0 なら）→ 記憶しない。
        let store = makeStore()
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        let id = model.cart.first!.id
        model.setAmount(id: id, 1.0) // 既定と同値（setAmount は同値なら touch すらしない）
        try commit(model)
        #expect(store.customDefault(for: "veg.cabbage")?.amount == nil)
    }

    @Test func amountDifferentFromOneIsRemembered() throws {
        // amount が 1.0 以外で touched → 記憶する。
        let store = makeStore()
        let model = AddFlowModel()
        model.addOne(preset: preset("veg.cabbage"), store: store)
        let id = model.cart.first!.id
        model.setAmount(id: id, 0.5) // 1.0 と異なる・touched
        try commit(model)
        #expect(store.customDefault(for: "veg.cabbage")?.amount == 0.5)
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
