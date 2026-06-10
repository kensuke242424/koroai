// コピー辞書（責めないトーン）。gentle / simple / cheer の3トーン。既定 gentle。
// 文言はプロトタイプ準拠で一字一句変えない。

import Foundation

/// コピーのトーン。既定は gentle。
enum Tone: String, CaseIterable, Identifiable {
    case gentle
    case simple
    case cheer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle: return "やさしい"
        case .simple: return "シンプル"
        case .cheer: return "はげまし"
        }
    }

    /// このトーンのコピー一式。
    var copy: ToneCopy {
        switch self {
        case .gentle: return .gentle
        case .simple: return .simple
        case .cheer: return .cheer
        }
    }
}

/// 1トーン分のコピー。
struct ToneCopy {
    let homeKicker: String
    let eatThisWeek: String
    let plenty: String
    let plentyNote: String
    let empty: String
    let ate: String
    let tossed: String
    let heroVerb: String
    let addTitle: String
    let addHint: String

    static let gentle = ToneCopy(
        homeKicker: "おはようございます",
        eatThisWeek: "今週、食べきりたい",
        plenty: "ゆとりあり",
        plentyNote: "まだ慌てなくて大丈夫",
        empty: "いまは急ぎの食材はありません。ゆっくりどうぞ。",
        ate: "ごちそうさま！",
        tossed: "記録しました",
        heroVerb: "今日のうちに、食べきろう",
        addTitle: "何を買ってきた？",
        addHint: "カテゴリを選ぶだけ。日付は自動でつけておくね。"
    )

    static let simple = ToneCopy(
        homeKicker: "冷蔵庫",
        eatThisWeek: "今週食べきる",
        plenty: "ゆとり",
        plentyNote: "余裕あり",
        empty: "急ぎの食材はありません。",
        ate: "食べた",
        tossed: "捨てた",
        heroVerb: "今日中に使い切る",
        addTitle: "追加",
        addHint: "カテゴリを選択。日付は自動。"
    )

    static let cheer = ToneCopy(
        homeKicker: "きょうもいい日に",
        eatThisWeek: "いま食べごろの食材",
        plenty: "まだ平気なもの",
        plentyNote: "のんびりでだいじょうぶ",
        empty: "急ぎはなし！上手に使えてますね。",
        ate: "ナイス完食！",
        tossed: "つぎは食べきろう",
        heroVerb: "きょうが食べどき！",
        addTitle: "買ってきたものは？",
        addHint: "タップするだけ。日付はおまかせ。"
    )
}

extension Tone {
    /// 残り日数ラベル。トーンごとに表現を出し分ける。
    static func dayLabel(daysLeft: Int, tone: Tone) -> String {
        switch tone {
        case .gentle:
            if daysLeft <= 0 { return "今日中に" }
            if daysLeft == 1 { return "あすまで" }
            return "あと\(daysLeft)日"
        case .simple:
            if daysLeft <= 0 { return "今日" }
            return "\(daysLeft)日"
        case .cheer:
            if daysLeft <= 0 { return "いま食べごろ" }
            if daysLeft == 1 { return "そろそろ" }
            if daysLeft <= 3 { return "あと\(daysLeft)日" }
            return "ゆっくりでOK"
        }
    }
}
