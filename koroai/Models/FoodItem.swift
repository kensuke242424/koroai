// 冷蔵庫の食材1件。SwiftData の永続モデル。
//
// 期限は絶対日付 expiresAt を保存し、残日数は保存しない（DateMath で算出）。
// カテゴリ由来の値（perishable・unit・amountMode）は登録時にコピーする。
// これはカテゴリマスタを後から改定しても既存の食材の挙動が変わらないようにするため。
// 残量は未設定OK（必須にしない）。amountIsSet でユーザーが残量を指定したかを表す。

import Foundation
import SwiftData

@Model
final class FoodItem {
    @Attribute(.unique) var id: UUID
    /// 所属カテゴリの id（FoodCategory.find で解決）。
    var catId: String
    var name: String
    /// 追加日時（README 表記では addedAt）。
    var purchasedAt: Date
    /// 絶対期限日。残日数はここから算出する（保存しない）。
    var expiresAt: Date
    /// 生鮮かどうか。登録時にカテゴリからコピー（以後カテゴリ改定の影響を受けない）。
    var perishable: Bool
    /// 残量モードの生値。amountMode 経由で読み書きする。
    var amountModeRaw: String
    /// 残量（0...1）。amount モード時に使う。
    var amount: Double
    /// 現在個数。count モード時に使う。
    var quantity: Int
    /// 初期個数（編集時のピル表示用）。
    var quantityTotal: Int
    var unit: String
    /// ユーザーが残量を明示設定したか。未設定OK（必須にしない）を表現する。
    var amountIsSet: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        catId: String,
        name: String,
        purchasedAt: Date = .now,
        expiresAt: Date,
        perishable: Bool,
        amountMode: AmountMode = .amount,
        amount: Double = 1,
        quantity: Int = 1,
        quantityTotal: Int = 1,
        unit: String,
        amountIsSet: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.catId = catId
        self.name = name
        self.purchasedAt = purchasedAt
        self.expiresAt = expiresAt
        self.perishable = perishable
        self.amountModeRaw = amountMode.rawValue
        self.amount = amount
        self.quantity = quantity
        self.quantityTotal = quantityTotal
        self.unit = unit
        self.amountIsSet = amountIsSet
        self.note = note
    }

    // MARK: - 非保存の計算プロパティ／メソッド

    /// 残量モード。未知の生値は .amount にフォールバックする。
    var amountMode: AmountMode {
        get { AmountMode(rawValue: amountModeRaw) ?? .amount }
        set { amountModeRaw = newValue.rawValue }
    }

    /// 所属カテゴリ。未知の catId なら nil。
    var category: FoodCategory? {
        FoodCategory.find(catId)
    }

    /// 残日数（今日との暦日差）。保存せず常に算出する。
    func daysLeft(now: Date = .now, calendar: Calendar = .current) -> Int {
        DateMath.daysLeft(until: expiresAt, from: now, calendar: calendar)
    }

    // MARK: - 便利ファクトリ

    /// カテゴリ既定から食材を作る。
    /// - name 省略時は category.defaultName。
    /// - daysLeft 省略時は category.defaultDays。
    /// - expiresAt は DateMath.expiryDate で算出。
    /// - perishable / unit / amountMode はカテゴリ既定をコピー。
    /// - purchasedAt は now。
    static func make(
        category: FoodCategory,
        name: String? = nil,
        daysLeft: Int? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FoodItem {
        let days = daysLeft ?? category.defaultDays
        return FoodItem(
            catId: category.id,
            name: name ?? category.defaultName,
            purchasedAt: now,
            expiresAt: DateMath.expiryDate(daysFromNow: days, from: now, calendar: calendar),
            perishable: category.perishable,
            amountMode: category.defaultAmountMode,
            unit: category.defaultUnit
        )
    }
}
