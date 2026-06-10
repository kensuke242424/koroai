// かごに溜める下書き食材（値型）。
//
// 確定済みの設計判断: かごは DraftItem の配列で保持し、「まとめて登録」確定時に初めて
// FoodItem を生成して insert する。amountTouched が true のとき（モード切替・スライダー・
// 個数ボタンのいずれかに触れた）だけ、生成 FoodItem の amountIsSet を true にする。

import Foundation

struct DraftItem: Identifiable, Equatable {
    let id: UUID
    var catId: String
    var name: String
    /// もち日数（today からの相対）。expiresAt は commit 時に DateMath で絶対日付へ変換。
    var days: Int
    var amountMode: AmountMode
    /// 残量（0...1）。amount モード時に使う。
    var amount: Double
    /// 現在個数。count モード時に使う。
    var quantity: Int
    var unit: String
    /// ユーザーが残量に触れたか（モード切替・スライダー・個数ボタンのいずれか）。
    var amountTouched: Bool

    init(
        id: UUID = UUID(),
        catId: String,
        name: String,
        days: Int,
        amountMode: AmountMode,
        amount: Double,
        quantity: Int,
        unit: String,
        amountTouched: Bool = false
    ) {
        self.id = id
        self.catId = catId
        self.name = name
        self.days = days
        self.amountMode = amountMode
        self.amount = amount
        self.quantity = quantity
        self.unit = unit
        self.amountTouched = amountTouched
    }

    /// この下書きから FoodItem を生成する（commit 用の純関数ロジック）。
    /// - name 空 → カテゴリ既定名へフォールバック。
    /// - days → DateMath.expiryDate で絶対 expiresAt へ変換。
    /// - perishable はカテゴリからコピー。
    /// - quantityTotal = quantity（追加時は初期個数 = 現在個数）。
    /// - amountIsSet = amountTouched。
    func makeFoodItem(now: Date = .now, calendar: Calendar = .current) -> FoodItem {
        let category = FoodCategory.find(catId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? (category?.defaultName ?? category?.name ?? "") : trimmed
        return FoodItem(
            catId: catId,
            name: resolvedName,
            purchasedAt: now,
            expiresAt: DateMath.expiryDate(daysFromNow: days, from: now, calendar: calendar),
            perishable: category?.perishable ?? true,
            amountMode: amountMode,
            amount: amount,
            quantity: quantity,
            quantityTotal: quantity,
            unit: unit,
            amountIsSet: amountTouched
        )
    }
}
