// 追加フローの状態モデル。MV(VM) の VM 相当（@Observable・@MainActor）。
//
// かごは DraftItem の配列で保持する。詳細入力中のフィールドは編集用の一時 state として持ち、
// saveDetail() で DraftItem へ反映する（追加 or 更新）。確定（commit）時に初めて FoodItem を
// 生成して context に insert・save し、トーストを出す。
//
// 残量モードの記憶（README「選んだモードは記憶」）は AppStore.amountModeOverride を介して行い、
// openAdd で override を反映、詳細でモードを切り替えたら override を更新する。

import SwiftUI
import SwiftData

@Observable
@MainActor
final class AddFlowModel {

    /// シート内の表示。grid（カテゴリ選択）/ detail（詳細入力オーバーレイ）。
    enum DetailView {
        case grid
        case detail
    }

    // MARK: - 公開 state

    /// かご（確定前の下書き）。
    private(set) var cart: [DraftItem] = []
    var view: DetailView = .grid
    /// かご一覧の展開状態。
    var cartExpanded = false
    /// 閉じる確認オーバーレイの表示状態。
    var confirmClose = false
    /// 編集中の DraftItem id（nil なら新規追加）。
    private(set) var editingId: UUID?

    // MARK: - 詳細入力中フィールド

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
    var quantity: Int = 5 {
        didSet { if quantity != oldValue, !suppressTouch { amountTouched = true } }
    }
    var unit: String = "個"
    /// 残量に触れたか（モード切替・スライダー・個数ボタンのいずれか）。
    private(set) var amountTouched = false
    /// カレンダー展開状態。
    var calendarOpen = false

    /// 初期化中（openAdd/openEdit）の didSet 副作用（touched・override 更新）を抑止する。
    private var suppressTouch = false

    /// override 読み書きに使う AppStore（openAdd 時に受け取る）。
    private weak var store: AppStore?

    // MARK: - 派生

    var category: FoodCategory? { FoodCategory.find(catId) }
    var cartCount: Int { cart.count }
    /// 詳細入力中の表示用 DraftItem 名のプレースホルダー（カテゴリ既定名）。
    var defaultName: String { category?.defaultName ?? category?.name ?? "" }

    /// 指定カテゴリのかご内件数。
    func countOf(catId: String) -> Int {
        cart.reduce(0) { $0 + ($1.catId == catId ? 1 : 0) }
    }

    // MARK: - フロー操作

    /// シートを開いた直後の初期化（grid から開始・かご保持はセッション単位で呼び出し側が制御）。
    func reset() {
        cart = []
        cartExpanded = false
        confirmClose = false
        view = .grid
        editingId = nil
    }

    /// カテゴリタイルから詳細入力を開く（新規）。モード override を反映する。
    func openAdd(category: FoodCategory, store: AppStore) {
        self.store = store
        suppressTouch = true
        editingId = nil
        catId = category.id
        name = ""
        days = category.defaultDays
        calendarOpen = false
        unit = category.defaultUnit
        // 初期モード = override ?? カテゴリ既定。
        amountMode = store.amountModeOverride(for: category.id) ?? category.defaultAmountMode
        amount = 1
        quantity = 5
        amountTouched = false
        suppressTouch = false
        view = .detail
    }

    /// かご内の行から詳細入力を開く（編集）。
    func openEdit(draftId: UUID, store: AppStore) {
        guard let it = cart.first(where: { $0.id == draftId }) else { return }
        self.store = store
        suppressTouch = true
        editingId = draftId
        catId = it.catId
        name = it.name
        days = it.days
        calendarOpen = false
        unit = it.unit
        amount = it.amount
        quantity = it.quantity
        amountMode = it.amountMode
        amountTouched = it.amountTouched
        suppressTouch = false
        view = .detail
    }

    /// 詳細の内容をかごへ反映する（追加 or 更新）。name 空は defaultName へフォールバック。
    func saveDetail() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? defaultName : trimmed
        if let editingId, let idx = cart.firstIndex(where: { $0.id == editingId }) {
            cart[idx].name = resolvedName
            cart[idx].days = days
            cart[idx].amountMode = amountMode
            cart[idx].amount = amount
            cart[idx].quantity = quantity
            cart[idx].unit = unit
            cart[idx].amountTouched = amountTouched
        } else {
            cart.append(
                DraftItem(
                    catId: catId,
                    name: resolvedName,
                    days: days,
                    amountMode: amountMode,
                    amount: amount,
                    quantity: quantity,
                    unit: unit,
                    amountTouched: amountTouched
                )
            )
        }
        view = .grid
    }

    /// 編集中の下書きをかごから削除して grid へ戻る。
    func deleteEditing() {
        if let editingId {
            cart.removeAll { $0.id == editingId }
        }
        view = .grid
    }

    /// かごから1件取り消す。
    func removeFromCart(id: UUID) {
        cart.removeAll { $0.id == id }
    }

    /// 閉じる要求。かごが空でないときは確認オーバーレイを出す（呼び出し側が実際の閉じを担う）。
    /// - Returns: 即閉じてよいなら true（かご空）。確認待ちなら false。
    @discardableResult
    func requestClose() -> Bool {
        if cart.isEmpty {
            return true
        }
        confirmClose = true
        return false
    }

    /// かごの内容を確定する。FoodItem を生成・insert・save し、トーストを出す。
    /// - Returns: 確定した品数。
    @discardableResult
    func commit(context: ModelContext, toastCenter: ToastCenter, now: Date = .now, calendar: Calendar = .current) -> Int {
        let n = cart.count
        for draft in cart {
            context.insert(draft.makeFoodItem(now: now, calendar: calendar))
        }
        try? context.save()
        if n > 0 {
            toastCenter.show(.ate, "\(n)品を追加しました")
        }
        reset()
        return n
    }
}
