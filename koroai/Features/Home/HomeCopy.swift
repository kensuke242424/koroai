// ホームのコピー一式。プロトタイプから一字一句転記する（出典コメント付き）。
//
// - 日替わりタイトル（FK_DAILY_HEADLINES・季節フィルタ）… 出典: fk-app.jsx FK_DAILY_HEADLINES / fkDailyHeadline
// - 達成カードの一言（FK_PRAISE・直前重複回避）… 出典: fk-app.jsx FK_PRAISE / fkPickPraise
// - heroVerb（トーン別）… 出典: fk-home.jsx FKHomeC heroVerb
// - 空冷蔵庫コピー3トーン … 出典: fk-home.jsx FKEmptyFridge
// - 「急ぎなし」カード／「当分OK」… 出典: fk-home.jsx FKHomeC / FKPlenty

import Foundation

enum HomeCopy {

    // MARK: - 季節

    /// 月（1...12）→ 季節。12〜2冬 / 3〜5春 / 6〜8夏 / 9〜11秋。出典: fk-app.jsx fkSeason。
    enum Season: String {
        case winter, spring, summer, autumn
    }

    static func season(month: Int) -> Season {
        if month <= 2 || month == 12 { return .winter }
        if month <= 5 { return .spring }
        if month <= 8 { return .summer }
        return .autumn
    }

    // MARK: - 日替わりタイトル

    /// 1件の日替わりタイトル。season "all" は通年。出典: fk-app.jsx FK_DAILY_HEADLINES。
    struct Headline {
        let season: String // "all" or Season.rawValue
        let text: String
    }

    /// FK_DAILY_HEADLINES（19件）。文言・順序ともにプロトタイプ準拠。
    static let dailyHeadlines: [Headline] = [
        Headline(season: "all", text: "今日は何を食べきろう"),
        Headline(season: "all", text: "おいしく、むだなく"),
        Headline(season: "all", text: "きょうの一皿を、大切に"),
        Headline(season: "all", text: "冷蔵庫と、なかよく"),
        Headline(season: "all", text: "食べきりは小さなごちそう"),
        Headline(season: "all", text: "いただきますの前に"),
        Headline(season: "spring", text: "春の芽吹きを食卓に"),
        Headline(season: "spring", text: "やわらかな旬、いまだけ"),
        Headline(season: "spring", text: "あたらしい季節の味"),
        Headline(season: "summer", text: "夏野菜、いまが食べごろ"),
        Headline(season: "summer", text: "暑い日は、さっぱりと"),
        Headline(season: "summer", text: "みずみずしい旬を食卓へ"),
        Headline(season: "summer", text: "冷たい一品で涼もう"),
        Headline(season: "autumn", text: "実りの秋、よくばりに"),
        Headline(season: "autumn", text: "秋の味覚、こんがりと"),
        Headline(season: "autumn", text: "食欲の秋、上手に"),
        Headline(season: "winter", text: "あたたかい一皿で、ほっと"),
        Headline(season: "winter", text: "寒い日は、ことこと煮込み"),
        Headline(season: "winter", text: "鍋で、あたたまろう"),
    ]

    /// 指定日の日替わりタイトル。季節フィルタ後のプール内で「年内通算日 % プール数」。
    /// 出典: fk-app.jsx fkDailyHeadline（doy = 年初0日からの経過日）。
    static func dailyHeadline(date: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        let s = season(month: month).rawValue
        let pool = dailyHeadlines.filter { $0.season == "all" || $0.season == s }.map(\.text)
        guard !pool.isEmpty else { return "おいしく、むだなく" }
        let doy = dayOfYear(date: date, calendar: calendar)
        let idx = ((doy % pool.count) + pool.count) % pool.count
        return pool[idx]
    }

    /// 年内通算日（fk-app.jsx の doy 計算 `floor((date - Jan 0) / 86400000)` 相当。1/1 が 1）。
    private static func dayOfYear(date: Date, calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    // MARK: - 達成カードの一言（praise）

    /// FK_PRAISE（12件）。{n} は当月件数に置換。出典: fk-app.jsx FK_PRAISE。
    static let praisePool: [String] = [
        "その調子、食べきり上手！",
        "上手に使いきれています",
        "ナイス！ムダなしキープ中",
        "今月{n}品、いいペースです",
        "食材を活かす達人ですね",
        "おみごと、また1品すくえた",
        "コツコツ続いていますね",
        "冷蔵庫が喜んでいます",
        "今日もきれいに使えました",
        "いい習慣、育っています",
        "すばらしい、{n}品達成！",
        "むだなく、かしこく。さすが",
    ]

    /// 直前と重複しない praise をランダムに引く。出典: fk-app.jsx fkPickPraise。
    /// テスト用に rng を注入できる。
    static func pickPraise(avoiding prev: String?, using rng: inout some RandomNumberGenerator) -> String {
        let pool = praisePool.filter { $0 != prev }
        guard let pick = pool.randomElement(using: &rng) else { return praisePool[0] }
        return pick
    }

    static func pickPraise(avoiding prev: String?) -> String {
        var rng = SystemRandomNumberGenerator()
        return pickPraise(avoiding: prev, using: &rng)
    }

    /// {n} を当月件数に置換した表示用 praise。
    static func renderPraise(_ template: String, count: Int) -> String {
        template.replacingOccurrences(of: "{n}", with: String(count))
    }

    /// 達成カードのサブ文（固定）。出典: FK_TWEAK_DEFAULTS achieveSub。
    static let achievementSub = "今月の「食べきり」記録"

    // MARK: - heroVerb（トーン別）

    /// ヒーローの「食べきり」促し文。出典: fk-home.jsx FKHomeC heroVerb。
    static func heroVerb(tone: Tone, daysLeft d: Int) -> String {
        switch tone {
        case .simple:
            if d <= 0 { return "今日中に使い切る" }
            if d == 1 { return "明日まで" }
            return "あと\(d)日"
        case .cheer:
            if d <= 0 { return "きょうが食べどき！" }
            if d == 1 { return "そろそろ食べごろ" }
            return "あと\(d)日、楽しみに"
        case .gentle:
            if d <= 0 { return "今日のうちに、食べきろう" }
            if d == 1 { return "あすまでに、食べきりたい" }
            return "あと\(d)日、おいしいうちに"
        }
    }

    // MARK: - 「今週の食材」見出し（固定）

    /// calm 見出し。出典: FK_TWEAK_DEFAULTS calmLabel/calmEmptyLabel（ともに固定「今週の食材」）。
    static let calmLabel = "今週の食材"

    // MARK: - 「急ぎなし」カード（urgent なし・hero あり）

    /// urgent（きょうの食べ頃）が空＝今日まで期限の食材がないときのカード。
    /// urgent を「今日まで（daysLeft<=0）」に変更したのに合わせ「明日」を外す
    /// （今週の食材に「あすまで」が残りうるため・ユーザー指定 2026-06）。
    static let noUrgentTitle = "今日の急ぎはありません"
    static let noUrgentSub = "下の食材を、ゆっくり使いきっていきましょう。"

    // MARK: - 「当分OK」ラベル（plenty・daysLeft>13）

    /// 出典: fk-home.jsx FKPlenty（it.days > 13 ? '当分OK' : `あと${it.days}日`）。
    static let plentyLongLabel = "当分OK"

    // MARK: - ヒーローのデッキ補足

    /// 「急ぎはほかにN品・スワイプで切替」。出典: fk-home.jsx FKHomeC。
    static func moreUrgent(_ n: Int) -> String {
        "急ぎはほかに\(n)品・スワイプで切替"
    }

    // MARK: - 空冷蔵庫コピー（3トーン）

    /// 空冷蔵庫の文言。出典: fk-home.jsx FKEmptyFridge。
    struct EmptyFridgeCopy {
        let title: String
        let sub: String
        let cta: String
    }

    static func emptyFridge(tone: Tone) -> EmptyFridgeCopy {
        switch tone {
        case .simple:
            return EmptyFridgeCopy(
                title: "登録された食材はありません",
                sub: "買ってきた食材を ＋ から追加してください。",
                cta: "食材を追加"
            )
        case .cheer:
            return EmptyFridgeCopy(
                title: "さあ、はじめましょう！",
                sub: "買ってきた食材を入れると、食べきりをやさしくお手伝いします。",
                cta: "最初の食材を追加"
            )
        case .gentle:
            return EmptyFridgeCopy(
                title: "冷蔵庫は、まだ空っぽ",
                sub: "買ってきた食材を追加すると、傷んでしまう前にそっとお知らせします。",
                cta: "食材を追加する"
            )
        }
    }

    /// 空冷蔵庫の補足（FAB 案内）。出典: fk-home.jsx FKEmptyFridge。
    static let emptyFridgeFabHint = "下の ＋ ボタンからも追加できます"

    // MARK: - メタ行の日付

    /// 「M月D日（曜）」。出典: fk-app.jsx meta row。
    static func dateLabel(date: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date) // 1=日
        let names = ["日", "月", "火", "水", "木", "金", "土"]
        let wd = names[(weekday - 1 + 7) % 7]
        return "\(month)月\(day)日（\(wd)）"
    }
}
