// 通算（lifetime）での到達バッジ＝ごほうびの道のり。プロトタイプ fk-review.jsx FK_MILESTONES の移植。
//
// 序盤に密、後半はゆるやかに置く設計。文言はプロトタイプから一字一句転記。
// crossed(prev:next:) は prev→next で新たに跨いだ「最上位」を返す純関数（祝福オーバーレイは Step 8）。

import Foundation

/// 通算到達バッジ1件分。
struct Milestone: Identifiable, Equatable {
    /// 安定 id（"first" など）。
    let id: String
    /// 到達に必要な通算食べきり品数。
    let at: Int
    /// バッジ名。
    let name: String
    /// 補足コピー。
    let note: String
}

enum Milestones {
    /// 全マイルストーン（昇順）。出典: fk-review.jsx FK_MILESTONES。
    static let all: [Milestone] = [
        Milestone(id: "first",  at: 1,  name: "はじめての食べきり", note: "最初の一品。ここから。"),
        Milestone(id: "three",  at: 3,  name: "3品 食べきり",        note: "いい入りかた"),
        Milestone(id: "week",   at: 7,  name: "ムダなし、1週間",     note: "1週間ぶんを使いきり"),
        Milestone(id: "twelve", at: 12, name: "食べきり上手",        note: "習慣になってきた"),
        Milestone(id: "twenty", at: 20, name: "ムダなしの達人",      note: "冷蔵庫がいつもすっきり"),
        Milestone(id: "forty",  at: 40, name: "食べきりマイスター",  note: "もう、ムダ知らず"),
    ]

    /// prev→next で新たに跨いだ「最上位」マイルストーン（なければ nil）。
    /// 条件: m.at が prev より大きく next 以下（prev < m.at <= next）。
    /// 複数該当する場合は all が昇順なので最後に当たったもの＝最上位を返す。
    static func crossed(prev: Int, next: Int) -> Milestone? {
        var hit: Milestone? = nil
        for m in all where m.at > prev && m.at <= next {
            hit = m
        }
        return hit
    }
}
