// 最小設定ストア。テーマ・パレット・トーン・達成カード表示の4設定を保持し UserDefaults に永続化する。
//
// @Observable と @AppStorage は併用できない（@AppStorage は ObservableObject 前提）。
// そのため didSet で UserDefaults へ書き、init で読み込む素朴な実装にする。
// Step 4 以降で設定画面を作るときも、この型をそのまま使えるようにしておく。

import Foundation
import SwiftUI

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
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let digestHour = "settings.digestHour"
        static let digestMinute = "settings.digestMinute"
        static let leadDays = "settings.leadDays"
        static let showMonthlyResult = "settings.showMonthlyResult"
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

    /// 残量モードのカテゴリ別上書き（README「選んだモードは記憶」）。
    /// catId → AmountMode.rawValue の辞書として UserDefaults に永続化する。
    /// 詳細を開くときの初期モード = override ?? カテゴリ既定。詳細でモードを切り替えたら更新する。
    private var amountModeOverrides: [String: String] {
        didSet { defaults.set(amountModeOverrides, forKey: Keys.amountModeOverrides) }
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
        // 通知設定の既定: notificationsEnabled true / digest 8:00 / leadDays 1 / showMonthlyResult true
        notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        digestHour = defaults.object(forKey: Keys.digestHour) as? Int ?? 8
        digestMinute = defaults.object(forKey: Keys.digestMinute) as? Int ?? 0
        leadDays = defaults.object(forKey: Keys.leadDays) as? Int ?? 1
        showMonthlyResult = defaults.object(forKey: Keys.showMonthlyResult) as? Bool ?? true
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
}
