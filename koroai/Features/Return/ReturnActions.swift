// 復帰フローの SwiftData 操作を一箇所に集約（テスト可能・in-memory コンテナで検証）。
//
// 確定済みの設計判断（Step 8）:
//  - 期限切れ片付け: 復帰画面を出す時点で daysLeft<0 の食材を「ログを書かずに」削除する
//    （「そっと片付けておきました」が事実になる。捨てたカウントには入れない）。
//  - リセット（復帰画面の「リセットしてまっさらに」）: 食材のみ全削除（ConsumptionLog は保持）。
//    設定画面の全消去（FoodItem＋ConsumptionLog 両方）とは別物。
//  - 入れ直し: 残存食材を全削除（ログなし）→ 選択カテゴリを FoodItem.make で投入。
//
// いずれも ConsumptionLog を一切作らない（食べきり集計を汚さない）。

import Foundation
import SwiftData

enum ReturnActions {

    /// daysLeft<0（期限切れ）の食材だけを削除する。ログは書かない。
    /// - Returns: 削除した件数。
    @discardableResult
    @MainActor
    static func purgeExpired(context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Int {
        let items = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        var removed = 0
        for item in items where item.daysLeft(now: now, calendar: calendar) < 0 {
            context.delete(item)
            removed += 1
        }
        if removed > 0 { try? context.save() }
        return removed
    }

    /// 食材のみ全削除（記録ログは保持）。復帰画面「リセットしてまっさらに」。
    @MainActor
    static func resetItemsOnly(context: ModelContext) {
        for item in (try? context.fetch(FetchDescriptor<FoodItem>())) ?? [] {
            context.delete(item)
        }
        try? context.save()
    }

    /// 残存食材を全削除（ログなし）→ 指定カテゴリを FoodItem.make の既定で投入する。
    /// 入れ直し（ReenterSheet 確定）。
    @MainActor
    static func replaceAllItems(
        with catIds: some Collection<String>,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        for item in (try? context.fetch(FetchDescriptor<FoodItem>())) ?? [] {
            context.delete(item)
        }
        for id in catIds {
            guard let cat = FoodCategory.find(id) else { continue }
            context.insert(FoodItem.make(category: cat, now: now, calendar: calendar))
        }
        try? context.save()
    }
}
