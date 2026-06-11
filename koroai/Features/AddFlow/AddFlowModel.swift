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

    /// チップ・タイルバッジ用のプリセット別集約（grouped 用）。
    struct CartGroup: Identifiable {
        /// 集約キー＝プリセット id（タイル単位）。
        let presetId: String
        /// このプリセットが属するセクション（FoodCategory）の id。チップ色・確認セクション分けに使う。
        let catId: String
        let items: [DraftItem]
        /// このプリセット内の最新追加順（並べ替えキー）。
        let lastOrder: Int
        var id: String { presetId }
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

    /// 指定プリセットのかご内件数（タイルのカウントバッジ用）。
    func countOf(presetId: String) -> Int {
        cart.reduce(0) { $0 + ($1.presetId == presetId ? 1 : 0) }
    }

    /// プリセット別に集約したかご（最新追加が先頭＝追加順降順）。チップ・タイルバッジに使う。
    var grouped: [CartGroup] {
        var map: [String: [DraftItem]] = [:]
        for it in cart {
            map[it.presetId, default: []].append(it)
        }
        return map.map { presetId, items in
            let sorted = items.sorted { $0.addedOrder < $1.addedOrder }
            return CartGroup(
                presetId: presetId,
                catId: sorted.first?.catId ?? "",
                items: sorted,
                lastOrder: sorted.last?.addedOrder ?? 0
            )
        }
        // 最新の選択が先頭（追加順降順）。
        .sorted { $0.lastOrder > $1.lastOrder }
    }

    /// 指定セクション（catId）に属するかご内アイテム（追加順昇順）。確認画面のセクション分けに使う。
    func itemsInSection(_ catId: String) -> [DraftItem] {
        cart.filter { $0.catId == catId }.sorted { $0.addedOrder < $1.addedOrder }
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
    /// 初期値の優先順位:
    ///  1. カスタム既定値（store.customDefault）があれば各フィールドへ適用。
    ///     mode/amount/quantity 由来を適用したら amountTouched=true（残量に手を入れた状態として扱う）。
    ///     name/days だけのカスタムなら amountTouched は false のまま。
    ///  2. mode は カスタム > store.amountModeOverride(for: sectionId) > preset.mode。
    ///  3. それ以外は preset の値（amount 初期 0.72・quantity 1 は現行踏襲）。
    func addOne(preset: IngredientPreset, store: AppStore) {
        self.store = store
        orderCounter += 1

        let custom = store.customDefault(for: preset.id)

        // mode: カスタム > セクションの override > preset 既定。
        let customMode = custom?.amountMode.flatMap(AmountMode.init(rawValue:))
        let mode = customMode
            ?? store.amountModeOverride(for: preset.sectionId)
            ?? preset.mode

        let name = custom?.name ?? ""
        let days = custom?.days ?? preset.days
        let amount = custom?.amount ?? 0.72
        let quantity = custom?.quantity ?? 1

        // 残量系（mode/amount/quantity）にカスタムがあれば touched 扱い。name/days のみなら false。
        let touched = customMode != nil || custom?.amount != nil || custom?.quantity != nil

        cart.append(
            DraftItem(
                catId: preset.sectionId,
                presetId: preset.id,
                name: name,
                days: days,
                amountMode: mode,
                amount: amount,
                quantity: quantity,
                unit: preset.unit,
                amountTouched: touched,
                addedOrder: orderCounter
            )
        )
    }

    /// 指定プリセットの「最後に追加された 1件」をカゴから取り除く（チップの ✕）。
    /// カウント 2 以上なら −1（チップは残る）、1 なら 0 へ（チップ消滅）。
    func removeLastOfPreset(_ presetId: String) {
        guard let target = cart
            .filter({ $0.presetId == presetId })
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
            rememberCustomDefault(for: draft)
            context.insert(draft.makeFoodItem(now: now, calendar: calendar))
        }
        try? context.save()
        if n > 0 {
            toastCenter.show(.ate, "\(n)品を追加しました")
        }
        reset()
        return n
    }

    /// commit 時の記憶。プリセット既定と異なるフィールドだけをカスタム既定値として保存する。
    /// 全フィールド一致なら既存カスタムを削除（既定へ戻したらリセット）。
    /// 比較規則（仕様）:
    ///  - name: trim 後、空でなく preset.name と異なる → 保存
    ///  - days: preset.days と異なる → 保存
    ///  - mode: preset.mode と異なる → 保存
    ///  - amount: mode==.amount かつ touched かつ 0.72 と異なる → 保存
    ///  - quantity: mode==.count かつ touched かつ 1 と異なる → 保存
    private func rememberCustomDefault(for draft: DraftItem) {
        // presetId 非空のみ対象（プリセット非由来の直接生成は記憶しない）。
        guard !draft.presetId.isEmpty, let preset = IngredientCatalog.find(draft.presetId) else { return }

        var custom = PresetCustomDefault()

        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != preset.name { custom.name = trimmed }
        if draft.days != preset.days { custom.days = draft.days }
        if draft.amountMode != preset.mode { custom.amountMode = draft.amountMode.rawValue }
        if draft.amountMode == .amount, draft.amountTouched, draft.amount != 0.72 {
            custom.amount = draft.amount
        }
        if draft.amountMode == .count, draft.amountTouched, draft.quantity != 1 {
            custom.quantity = draft.quantity
        }

        // 空（＝全フィールド既定どおり）なら setCustomDefault(nil) 相当で既存カスタムを削除。
        store?.setCustomDefault(custom.isEmpty ? nil : custom, for: draft.presetId)
    }
}
