// 今朝のまとめの導出ロジック。プロトタイプ fk-digest.jsx fkBuildDigest の純関数移植。
//
// 在庫（FoodItem）から「今日のうちに食べきりたいもの」を抽出し、トーン別の文言を組み立てる。
// 文言（verb / lead / sub / nudge）はプロトタイプから一字一句移植する。
// FoodItem を直接読まず、必要な値だけを写した DigestItem を入力にして純関数＆テスト容易にする。

import Foundation

/// まとめが扱う食材1件分（FoodItem からの写し）。
struct DigestItem: Identifiable, Equatable {
    let id: UUID
    let catId: String
    let name: String
    /// 生鮮かどうか（hero 抽出の条件）。
    let perishable: Bool
    /// 残日数（now 基準で算出済みの値を渡す）。
    let days: Int
}

/// まとめの導出結果。
struct DigestResult {
    /// 生鮮かつ残6日以下を days 昇順に並べたもの。
    let hero: [DigestItem]
    /// 残0日以下（今日のうちに）。
    let today: [DigestItem]
    /// 残1日（あすまでに）。
    let tomorrow: [DigestItem]
    /// 残2〜3日（そろそろ）。
    let soon: [DigestItem]
    /// today + tomorrow + soon を連結した「急ぎ」リスト（先頭4件を行表示に使う）。
    let urgent: [DigestItem]
    /// リード文（fs22 見出し）。
    let lead: String
    /// サブ文（空状態のセンターカード本文・通知の補足）。
    let sub: String
    /// やさしい一押し（対象がいないときは nil）。
    let nudge: String?
    /// lead 末尾に「。」を付けるか（today か tomorrow があるとき）。
    let leadEndsWithPeriod: Bool
}

enum DigestBuilder {

    /// 残日数 → トーン別の動詞ピル文言。出典: fk-digest.jsx verb。
    static func verb(days d: Int, tone: Tone) -> String {
        switch tone {
        case .simple:
            if d <= 0 { return "今日中" }
            if d == 1 { return "明日まで" }
            return "あと\(d)日"
        case .cheer:
            if d <= 0 { return "きょうが食べどき" }
            if d == 1 { return "そろそろ" }
            return "あと\(d)日"
        case .gentle:
            if d <= 0 { return "今日のうちに" }
            if d == 1 { return "あすまでに" }
            return "あと\(d)日"
        }
    }

    /// 在庫からまとめを導出する純関数。出典: fk-digest.jsx fkBuildDigest。
    /// - Parameters:
    ///   - items: まとめ対象の食材（days は呼び出し側で now/calendar から算出済みのもの）。
    ///   - tone: コピーのトーン。
    static func build(items: [DigestItem], tone: Tone) -> DigestResult {
        let hero = items
            .filter { $0.perishable && $0.days <= 6 }
            .sorted { $0.days < $1.days }
        let today = hero.filter { $0.days <= 0 }
        let tmrw = hero.filter { $0.days == 1 }
        let soon = hero.filter { $0.days >= 2 && $0.days <= 3 }
        let urgent = today + tmrw + soon

        let lead: String
        let sub: String
        if !today.isEmpty {
            switch tone {
            case .simple: lead = "今日中：\(today.count)品"
            case .cheer:  lead = "きょうが食べごろ、\(today.count)品！"
            case .gentle: lead = "今日のうちに食べきりたいものが \(today.count)品"
            }
            sub = today.map(\.name).joined(separator: "・")
        } else if !tmrw.isEmpty {
            switch tone {
            case .simple: lead = "明日まで：\(tmrw.count)品"
            case .cheer:  lead = "あすが食べごろ、\(tmrw.count)品"
            case .gentle: lead = "あすが食べどきのものが \(tmrw.count)品"
            }
            sub = tmrw.map(\.name).joined(separator: "・")
        } else if !soon.isEmpty {
            lead = tone == .cheer ? "そろそろのものが \(soon.count)品" : "近いうちに食べたいものが \(soon.count)品"
            sub = soon.map(\.name).joined(separator: "・")
        } else {
            lead = tone == .cheer ? "急ぎはなし、上手に使えてます！" : "今日は急ぎの食材はありません"
            sub = "ゆっくりどうぞ。"
        }

        // やさしい一押し（命令ではなく提案）。today[0] を優先、無ければ tomorrow[0]。
        var nudge: String? = nil
        if let pick = today.first ?? tmrw.first {
            switch tone {
            case .simple: nudge = "\(pick.name)を使い切る"
            case .cheer:  nudge = "\(pick.name)、今日おいしく食べきろう！"
            case .gentle: nudge = "\(pick.name)、今日のうちに使い切れます"
            }
        }

        return DigestResult(
            hero: hero,
            today: today,
            tomorrow: tmrw,
            soon: soon,
            urgent: urgent,
            lead: lead,
            sub: sub,
            nudge: nudge,
            leadEndsWithPeriod: !today.isEmpty || !tmrw.isEmpty
        )
    }

    /// FoodItem 配列を DigestItem に写してからまとめを導出する便宜オーバーロード。
    /// days は now/calendar から算出する。
    static func build(items: [FoodItem], tone: Tone, now: Date = .now, calendar: Calendar = .current) -> DigestResult {
        let mapped = items.map { it in
            DigestItem(
                id: it.id,
                catId: it.catId,
                name: it.name,
                perishable: it.perishable,
                days: it.daysLeft(now: now, calendar: calendar)
            )
        }
        return build(items: mapped, tone: tone)
    }
}
