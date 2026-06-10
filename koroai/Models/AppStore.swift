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

    private let defaults: UserDefaults

    /// - Parameter defaults: 注入可能（テスト・プレビュー用）。既定は .standard。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 既定値: themeMode .system / palette .hinoki / tone .gentle / showAchievementCard true
        themeMode = (defaults.string(forKey: Keys.themeMode)).flatMap(ThemeMode.init(rawValue:)) ?? .system
        palette = (defaults.string(forKey: Keys.palette)).flatMap(Palette.init(rawValue:)) ?? .hinoki
        tone = (defaults.string(forKey: Keys.tone)).flatMap(Tone.init(rawValue:)) ?? .gentle
        showAchievementCard = defaults.object(forKey: Keys.showAchievementCard) as? Bool ?? true
    }
}
