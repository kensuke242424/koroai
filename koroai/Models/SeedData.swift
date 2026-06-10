// プレビュー／開発用フィクスチャ。
//
// 本番起動時の自動投入はしない（初期データはオンボーディングで入れる方針）。
// SwiftUI Preview と開発時にホームを賑やかすための固定データ。
// プロトタイプの fkSeedFridge 準拠の7品。

import Foundation

enum SeedData {
    /// プレビュー用の食材7件。残量指定があるものは amountIsSet = true。
    static func previewItems(now: Date = .now, calendar: Calendar = .current) -> [FoodItem] {
        /// カテゴリ既定から作り、残量・名前・残日数を上書きする小ヘルパー。
        func item(
            _ catId: String,
            name: String,
            daysLeft: Int,
            amount: Double? = nil,
            quantity: Int? = nil,
            quantityTotal: Int? = nil,
            amountMode: AmountMode? = nil
        ) -> FoodItem {
            let category = FoodCategory.find(catId)!
            let fi = FoodItem.make(category: category, name: name, daysLeft: daysLeft, now: now, calendar: calendar)
            if let amountMode { fi.amountMode = amountMode }
            if let amount {
                fi.amount = amount
                fi.amountIsSet = true
            }
            if let quantity {
                fi.quantity = quantity
                fi.amountIsSet = true
            }
            if let quantityTotal { fi.quantityTotal = quantityTotal }
            return fi
        }

        return [
            item("fish",    name: "刺身（まぐろ）", daysLeft: 0,  amount: 0.5),
            item("chicken", name: "鶏むね肉",       daysLeft: 1,  amount: 0.72),
            item("leafy",   name: "ほうれん草",     daysLeft: 2,  amount: 0.3),
            item("tofu",    name: "絹ごし豆腐",     daysLeft: 3,  quantity: 1, quantityTotal: 3),
            item("dairy",   name: "牛乳",           daysLeft: 4,  amount: 0.72),
            // veg のカテゴリ既定は amount だが、個数指定の意図なので count に明示上書き。
            item("veg",     name: "ミニトマト",     daysLeft: 5,  quantity: 4, quantityTotal: 6, amountMode: .count),
            item("egg",     name: "卵（10個）",     daysLeft: 12, quantity: 8, quantityTotal: 10),
        ]
    }
}
