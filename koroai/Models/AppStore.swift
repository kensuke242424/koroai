// 最小設定ストア。テーマ・パレット・トーン・達成カード表示の4設定を保持し UserDefaults に永続化する。
//
// @Observable と @AppStorage は併用できない（@AppStorage は ObservableObject 前提）。
// そのため didSet で UserDefaults へ書き、init で読み込む素朴な実装にする。
// Step 4 以降で設定画面を作るときも、この型をそのまま使えるようにしておく。

import Foundation
import SwiftUI

/// 食材プリセット（IngredientCatalog）の既定値に対する、ユーザーのカスタム上書き。
/// プリセット既定と異なる入力だけを保存し、次回タイルタップ時に自動適用する。
/// 各フィールドは nil = カスタムなし（プリセット既定のまま）を意味する。
struct PresetCustomDefault: Codable, Equatable {
    /// プリセット名と異なる入力名（trim 済み・空は nil）。
    var name: String?
    var days: Int?
    /// AmountMode.rawValue（"amount" / "count"）。
    var amountMode: String?
    var amount: Double?
    var quantity: Int?

    /// 全フィールド nil なら「カスタムなし」。
    var isEmpty: Bool {
        name == nil && days == nil && amountMode == nil && amount == nil && quantity == nil
    }
}

@Observable
@MainActor
final class AppStore {

    /// UserDefaults キーは名前空間付きで衝突を避ける。
    private enum Keys {
        static let themeMode = "settings.themeMode"
        static let palette = "settings.palette"
        static let tone = "settings.tone"
        static let showAchievementCard = "settings.showAchievementCard"
        static let showWeeklySummary = "settings.showWeeklySummary"
        static let amountModeOverrides = "settings.amountModeOverrides"
        static let presetCustomDefaults = "settings.presetCustomDefaults"
        static let recentPresetIds = "settings.recentPresetIds"
        static let confirmAmountShown = "settings.confirmAmountShown"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let digestHour = "settings.digestHour"
        static let digestMinute = "settings.digestMinute"
        static let leadDays = "settings.leadDays"
        static let showMonthlyResult = "settings.showMonthlyResult"
        static let showResultRank = "settings.showResultRank"
        static let lastOpenedAt = "app.lastOpenedAt"
        static let monthResultShownFor = "app.monthResultShownFor"
        static let onboarded = "app.onboarded"
    }

    var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    var palette: Palette {
        didSet { defaults.set(palette.rawValue, forKey: Keys.palette) }
    }

    var tone: Tone {
        didSet { defaults.set(tone.rawValue, forKey: Keys.tone) }
    }

    var showAchievementCard: Bool {
        didSet { defaults.set(showAchievementCard, forKey: Keys.showAchievementCard) }
    }

    /// ふりかえり内の週次サマリー（先週のふりかえり）を表示するか。既定 true。
    /// 設定 UI は Step 7。
    var showWeeklySummary: Bool {
        didSet { defaults.set(showWeeklySummary, forKey: Keys.showWeeklySummary) }
    }

    // MARK: - 通知設定（Step 7）

    /// うちのスケジューリングの ON/OFF（OS の権限とは別）。既定 true。
    /// false にしたら全 pending を取り消す（再スケジュール契機で空 plan が登録される）。
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    /// 朝のまとめ通知の発火時刻（時）。既定 8。
    var digestHour: Int {
        didSet { defaults.set(digestHour, forKey: Keys.digestHour) }
    }

    /// 朝のまとめ通知の発火時刻（分）。既定 0。
    var digestMinute: Int {
        didSet { defaults.set(digestMinute, forKey: Keys.digestMinute) }
    }

    /// 期限前通知を「何日前」に出すか。0=当日 / 1 / 2 / 3。既定 1。
    var leadDays: Int {
        didSet { defaults.set(leadDays, forKey: Keys.leadDays) }
    }

    /// 月替わりリザルトを表示するか。既定 true。UI は Step 7 で先行、使用は Step 8。
    var showMonthlyResult: Bool {
        didSet { defaults.set(showMonthlyResult, forKey: Keys.showMonthlyResult) }
    }

    /// 月替わりリザルトに称号（ランクバッジ）を表示するか。既定 true。
    /// 出典: tweaks-panel.jsx「月替わりリザルトに称号を表示」(showRank)。
    /// showMonthlyResult（リザルト自体の ON/OFF）とは別物。
    var showResultRank: Bool {
        didSet { defaults.set(showResultRank, forKey: Keys.showResultRank) }
    }

    // MARK: - 自動表示の進行状態（Step 8）

    /// 最後にアプリを開いた日時。月替わり判定（暦月比較）と久しぶり起動判定（暦日差）に使う。
    /// 更新は koroaiApp の scenePhase 監視（active→非active）と起動チェック完了後。
    var lastOpenedAt: Date? {
        didSet { defaults.set(lastOpenedAt, forKey: Keys.lastOpenedAt) }
    }

    /// 月替わりリザルトを最後に見せた対象月キー（"YYYY-MM"）。二重表示を防ぐ。
    var monthResultShownFor: String? {
        didSet { defaults.set(monthResultShownFor, forKey: Keys.monthResultShownFor) }
    }

    /// オンボーディング済みか。既定 false。完了/スキップで true。
    var onboarded: Bool {
        didSet { defaults.set(onboarded, forKey: Keys.onboarded) }
    }

    /// 残量モードのカテゴリ別上書き（README「選んだモードは記憶」）。
    /// catId → AmountMode.rawValue の辞書として UserDefaults に永続化する。
    /// 詳細を開くときの初期モード = override ?? カテゴリ既定。詳細でモードを切り替えたら更新する。
    private var amountModeOverrides: [String: String] {
        didSet { defaults.set(amountModeOverrides, forKey: Keys.amountModeOverrides) }
    }

    /// 食材プリセット別のカスタム既定値（key=presetId）。
    /// プリセット既定と異なる入力で追加すると commit 時に記憶し、次回タイルタップで自動適用する。
    /// 辞書全体を JSONEncoder で Data 1本にして UserDefaults へ書く（amountModeOverrides と同じ didSet 流儀）。
    private var presetCustomDefaults: [String: PresetCustomDefault] {
        didSet {
            if let data = try? JSONEncoder().encode(presetCustomDefaults) {
                defaults.set(data, forKey: Keys.presetCustomDefaults)
            }
        }
    }

    /// 最近 commit したプリセット id（新しいものが先頭・最大12件）。
    /// 「選ぶ」画面先頭の「最近使った食材」セクションに使う。commit 時に rememberRecent で更新。
    private(set) var recentPresetIds: [String] {
        didSet { defaults.set(recentPresetIds, forKey: Keys.recentPresetIds) }
    }

    /// 確認画面で残量エリアを表示するか。既定 false（畳んだ状態）。
    /// 確認画面ヘッダーの「残量」トグルで切替・永続化する（値自体は畳んでいても生きている）。
    var confirmAmountShown: Bool {
        didSet { defaults.set(confirmAmountShown, forKey: Keys.confirmAmountShown) }
    }

    private let defaults: UserDefaults

    /// - Parameter defaults: 注入可能（テスト・プレビュー用）。既定は .standard。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 既定値: themeMode .system / palette .hinoki / tone .gentle / showAchievementCard true
        themeMode = (defaults.string(forKey: Keys.themeMode)).flatMap(ThemeMode.init(rawValue:)) ?? .system
        palette = (defaults.string(forKey: Keys.palette)).flatMap(Palette.init(rawValue:)) ?? .hinoki
        tone = (defaults.string(forKey: Keys.tone)).flatMap(Tone.init(rawValue:)) ?? .gentle
        showAchievementCard = defaults.object(forKey: Keys.showAchievementCard) as? Bool ?? true
        showWeeklySummary = defaults.object(forKey: Keys.showWeeklySummary) as? Bool ?? true
        amountModeOverrides = (defaults.dictionary(forKey: Keys.amountModeOverrides) as? [String: String]) ?? [:]
        presetCustomDefaults = (defaults.data(forKey: Keys.presetCustomDefaults))
            .flatMap { try? JSONDecoder().decode([String: PresetCustomDefault].self, from: $0) } ?? [:]
        recentPresetIds = (defaults.array(forKey: Keys.recentPresetIds) as? [String]) ?? []
        confirmAmountShown = defaults.object(forKey: Keys.confirmAmountShown) as? Bool ?? false
        // 通知設定の既定: notificationsEnabled true / digest 8:00 / leadDays 1 / showMonthlyResult true
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        digestHour = defaults.object(forKey: Keys.digestHour) as? Int ?? 8
        digestMinute = defaults.object(forKey: Keys.digestMinute) as? Int ?? 0
        leadDays = defaults.object(forKey: Keys.leadDays) as? Int ?? 1
        showMonthlyResult = defaults.object(forKey: Keys.showMonthlyResult) as? Bool ?? true
        showResultRank = defaults.object(forKey: Keys.showResultRank) as? Bool ?? true
        // Step 8: 自動表示の進行状態。lastOpenedAt は未起動なら nil。
        lastOpenedAt = defaults.object(forKey: Keys.lastOpenedAt) as? Date
        monthResultShownFor = defaults.string(forKey: Keys.monthResultShownFor)
        onboarded = defaults.object(forKey: Keys.onboarded) as? Bool ?? false
    }

    // MARK: - 残量モードの記憶

    /// 指定カテゴリのユーザー上書き残量モード（未設定なら nil）。
    func amountModeOverride(for catId: String) -> AmountMode? {
        amountModeOverrides[catId].flatMap(AmountMode.init(rawValue:))
    }

    /// 指定カテゴリの残量モード上書きを保存する。
    func setAmountModeOverride(_ mode: AmountMode, for catId: String) {
        amountModeOverrides[catId] = mode.rawValue
    }

    // MARK: - プリセット別カスタム既定値

    /// 指定プリセットのカスタム既定値（未設定なら nil）。
    func customDefault(for presetId: String) -> PresetCustomDefault? {
        presetCustomDefaults[presetId]
    }

    /// 指定プリセットのカスタム既定値を保存する。nil または全フィールド空なら辞書から削除（既定へ戻したらリセット）。
    func setCustomDefault(_ value: PresetCustomDefault?, for presetId: String) {
        if let value, !value.isEmpty {
            presetCustomDefaults[presetId] = value
        } else {
            presetCustomDefaults.removeValue(forKey: presetId)
        }
    }

    // MARK: - 最近使った食材

    /// 指定プリセット id を「最近使った食材」の先頭へ挿入する。
    /// 既存の同 id は除去（重複なしで先頭へ移動）・最大12件にキャップ。空 id は無視。
    func rememberRecent(_ presetId: String) {
        guard !presetId.isEmpty else { return }
        var list = recentPresetIds
        list.removeAll { $0 == presetId }
        list.insert(presetId, at: 0)
        if list.count > 12 { list = Array(list.prefix(12)) }
        recentPresetIds = list
    }
}
