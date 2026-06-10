// 編集シートの状態モデル。MV(VM) の VM 相当（@Observable・@MainActor）。
// プロトタイプ fk-flows.jsx FKEditSheet のロジック移植。
//
// 既存 FoodItem を編集する。begin(item:store:) で各フィールドへ読み込み、save(item:context:...) で
// パッチを適用する。残量に触れたかの追跡（amountTouched）と override 記憶は AddFlowModel と同じ
// suppressTouch パターンを踏襲する。
//
// パッチ計算（名前フォールバック・expiresAt 算出・quantityTotal=max・amountIsSet 遷移）は
// テスト可能なよう純構造体 EditPatch に切り出す。

import SwiftUI
import SwiftData

// MARK: - 編集パッチ（純関数ロジック・テスト可能）

/// 編集フォームの入力値から FoodItem への適用内容を計算する純構造体。
/// FKEditSheet onSave の挙動を正とする:
/// - name 空 → カテゴリ name へフォールバック（defaultName ではない点に注意）。
/// - days → DateMath.expiryDate で絶対 expiresAt へ変換。
/// - quantityTotal = max(旧 quantityTotal, quantity)（個数を初期より増やしたら total も増える）。
/// - amountIsSet は amountTouched のときだけ true へ。触れていなければ既存値を維持。
struct EditPatch {
    var catId: String
    var name: String
    var days: Int
    var amountMode: AmountMode
    var amount: Double
    var quantity: Int
    var unit: String
    /// 残量に触れたか（モード切替・スライダー・個数ボタンのいずれか）。
    var amountTouched: Bool

    /// 名前空フォールバック後の確定名。プロトタイプ `name.trim() || cat.name`。
    func resolvedName() -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        // FKEditSheet は cat.name（カテゴリ表示名）へフォールバック。defaultName ではない。
        return FoodCategory.find(catId)?.name ?? ""
    }

    /// パッチを既存 FoodItem へ適用する。
    func apply(to item: FoodItem, now: Date = .now, calendar: Calendar = .current) {
        item.name = resolvedName()
        item.expiresAt = DateMath.expiryDate(daysFromNow: days, from: now, calendar: calendar)
        item.amountMode = amountMode
        item.amount = amount
        item.quantity = quantity
        // 個数を初期より増やしたら total も追従。減らした場合は据え置き。
        item.quantityTotal = max(item.quantityTotal, quantity)
        // 触れていなければ既存の amountIsSet を維持する（未設定OK のまま）。
        if amountTouched {
            item.amountIsSet = true
        }
    }
}

// MARK: - EditSheetModel

@Observable
@MainActor
final class EditSheetModel {

    // MARK: - 編集中フィールド

    private(set) var catId: String = ""
    var name: String = ""
    var days: Int = 3
    var amountMode: AmountMode = .amount {
        // モード切替も「残量に触れた」とみなし、override も更新する（初期化中は suppressTouch で抑止）。
        didSet {
            guard amountMode != oldValue, !suppressTouch else { return }
            amountTouched = true
            store?.setAmountModeOverride(amountMode, for: catId)
        }
    }
    var amount: Double = 1 {
        didSet { if amount != oldValue, !suppressTouch { amountTouched = true } }
    }
    var quantity: Int = 1 {
        didSet { if quantity != oldValue, !suppressTouch { amountTouched = true } }
    }
    /// 初期個数（差分ピップ・total 表示用）。
    private(set) var quantityTotal: Int = 1
    var unit: String = "個"
    /// 残量に触れたか（モード切替・スライダー・個数ボタンのいずれか）。
    private(set) var amountTouched = false
    /// カレンダー展開状態。
    var calendarOpen = false

    /// 初期化中（begin）の didSet 副作用（touched・override 更新）を抑止する。
    private var suppressTouch = false

    /// override 読み書きに使う AppStore（begin 時に受け取る）。
    private weak var store: AppStore?

    // MARK: - 派生

    var category: FoodCategory? { FoodCategory.find(catId) }

    // MARK: - フロー操作

    /// 既存 FoodItem を読み込んで編集を開始する。初期化中は touched 副作用を抑止する。
    func begin(item: FoodItem, store: AppStore, now: Date = .now, calendar: Calendar = .current) {
        self.store = store
        suppressTouch = true
        catId = item.catId
        name = item.name
        days = item.daysLeft(now: now, calendar: calendar)
        calendarOpen = false
        unit = item.unit
        amount = item.amount
        quantity = item.quantity
        quantityTotal = item.quantityTotal
        amountMode = item.amountMode
        amountTouched = false
        suppressTouch = false
    }

    /// 現在のフィールドからパッチを作る。
    func currentPatch() -> EditPatch {
        EditPatch(
            catId: catId,
            name: name,
            days: days,
            amountMode: amountMode,
            amount: amount,
            quantity: quantity,
            unit: unit,
            amountTouched: amountTouched
        )
    }

    /// パッチを item へ適用して保存する。
    func save(item: FoodItem, context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        currentPatch().apply(to: item, now: now, calendar: calendar)
        try? context.save()
    }
}
