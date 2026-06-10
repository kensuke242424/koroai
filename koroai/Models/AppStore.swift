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
        static let amountModeOverrides = "settings.amountModeOverrides"
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
        amountModeOverrides = (defaults.dictionary(forKey: Keys.amountModeOverrides) as? [String: String]) ?? [:]
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
