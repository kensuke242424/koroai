// 追加フローの状態モデル（刷新版・2ステップ: 選ぶ → 確認・編集）。MV(VM) の VM 相当（@Observable・@MainActor）。
//
// かごは DraftItem の配列で保持する。タイルタップで即 1件カゴに積み（詳細には飛ばない）、
// 確認画面でカード（ConfirmItemCard）から各項目を編集する。確定（commit）時に初めて FoodItem を
// 生成して context に insert・save し、トーストを出す。
//
// 残量モードの記憶（README「選んだモードは記憶」）は AppStore.amountModeOverride を介して行い、
// addOne で override を反映、確認画面でモードを切り替えたら override を更新する。

import SwiftUI
import SwiftData

@Observable
@MainActor
final class AddFlowModel {

    /// シート内の表示画面。select（選ぶ）/ confirm（確認・編集）。
    enum Screen: Equatable {
        case select
        case confirm
    }

    /// 確認画面のカテゴリ別セクション（grouped 用）。
    struct CartGroup: Identifiable {
        let catId: String
        let items: [DraftItem]
        /// このカテゴリ内の最新追加順（並べ替えキー）。
        let lastOrder: Int
        var id: String { catId }
        var count: Int { items.count }
    }

    // MARK: - 公開 state

    /// かご（確定前の下書き）。
    private(set) var cart: [DraftItem] = []
    /// 表示中の画面。
    var screen: Screen = .select
    /// 閉じる確認オーバーレイの表示状態。
    var confirmClose = false

    /// 追加順序の連番カウンタ（reset でゼロに戻す）。
    private var orderCounter = 0

    /// override 読み書きに使う AppStore（reset 時／操作時に受け取る）。
    private weak var store: AppStore?

    // MARK: - 派生

    var cartCount: Int { cart.count }

    /// 指定カテゴリのかご内件数（タイルのカウントバッジ用）。
    func countOf(catId: String) -> Int {
        cart.reduce(0) { $0 + ($1.catId == catId ? 1 : 0) }
    }

    /// カテゴリ別に集約したかご（最新追加が先頭＝追加順降順）。チップ・確認カードに使う。
    var grouped: [CartGroup] {
        var map: [String: [DraftItem]] = [:]
        for it in cart {
            map[it.catId, default: []].append(it)
        }
        return map.map { catId, items in
            let sorted = items.sorted { $0.addedOrder < $1.addedOrder }
            return CartGroup(catId: catId, items: sorted, lastOrder: sorted.last?.addedOrder ?? 0)
        }
        // 最新の選択が先頭（追加順降順）。
        .sorted { $0.lastOrder > $1.lastOrder }
    }

    // MARK: - フロー操作

    /// シートを開いた直後の初期化（select から開始・かごは空に）。
    func reset(store: AppStore? = nil) {
        if let store { self.store = store }
        cart = []
        screen = .select
        confirmClose = false
        orderCounter = 0
    }

    /// タイルタップ＝カゴに 1件追加する（詳細には飛ばない）。
    /// 既定: days=カテゴリ既定 / name="" / amount=0.72 / quantity=1 / unit=カテゴリ既定 /
    /// amountMode = override ?? カテゴリ既定（選んだモードを記憶） / amountTouched=false。
    func addOne(category: FoodCategory, store: AppStore) {
        self.store = store
        orderCounter += 1
        let mode = store.amountModeOverride(for: category.id) ?? category.defaultAmountMode
        cart.append(
            DraftItem(
                catId: category.id,
                name: "",
                days: category.defaultDays,
                amountMode: mode,
                amount: 0.72,
                quantity: 1,
                unit: category.defaultUnit,
                amountTouched: false,
                addedOrder: orderCounter
            )
        )
    }

    /// 指定カテゴリの「最後に追加された 1件」をカゴから取り除く（チップの ✕）。
    /// カウント 2 以上なら −1（チップは残る）、1 なら 0 へ（チップ消滅）。
    func removeLastOfCategory(_ catId: String) {
        guard let target = cart
            .filter({ $0.catId == catId })
            .max(by: { $0.addedOrder < $1.addedOrder })
        else { return }
        cart.removeAll { $0.id == target.id }
    }

    /// 確認画面でカードを除外する（個別 id 指定）。
    func removeItem(id: UUID) {
        cart.removeAll { $0.id == id }
    }

    // MARK: - 確認画面の編集（Binding 経由でカードから流す）

    /// 指定下書きの名前を更新する（残量には触れない＝touched しない）。
    func setName(id: UUID, _ name: String) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        cart[idx].name = name
    }

    /// 指定下書きのもち日数を更新する（残量には触れない＝touched しない）。
    func setDays(id: UUID, _ days: Int) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        cart[idx].days = max(0, days)
    }

    /// 指定下書きの残量モードを切り替える。touched=true・override も更新（既存挙動踏襲）。
    func setAmountMode(id: UUID, _ mode: AmountMode) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        guard cart[idx].amountMode != mode else { return }
        cart[idx].amountMode = mode
        cart[idx].amountTouched = true
        store?.setAmountModeOverride(mode, for: cart[idx].catId)
    }

    /// 指定下書きの残量（0...1）を更新する。touched=true。
    func setAmount(id: UUID, _ amount: Double) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        guard cart[idx].amount != amount else { return }
        cart[idx].amount = amount
        cart[idx].amountTouched = true
    }

    /// 指定下書きの個数を更新する。touched=true。
    func setQuantity(id: UUID, _ quantity: Int) {
        guard let idx = cart.firstIndex(where: { $0.id == id }) else { return }
        let q = max(0, quantity)
        guard cart[idx].quantity != q else { return }
        cart[idx].quantity = q
        cart[idx].amountTouched = true
    }

    // MARK: - 閉じる

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
    /// name 空→カテゴリ既定名、qtyTotal=max(qtyTotal, quantity)、amountIsSet=amountTouched は
    /// DraftItem.makeFoodItem 側で処理する。
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
