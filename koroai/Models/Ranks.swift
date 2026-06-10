// 通算（lifetime）での称号ティア。プロトタイプ fk-result.jsx FK_TIERS / fkRankFor の移植。
//
// ふりかえりヒーローの称号バッジに使う（リザルト画面自体は Step 8）。
// 文言はプロトタイプから一字一句転記。

import Foundation

/// 称号ティア1件分。
struct Rank: Equatable {
    /// このティアに到達する最小の通算食べきり品数。
    let min: Int
    /// 称号名。
    let name: String
    /// 補足コピー。
    let note: String
}

enum Ranks {
    /// 全ティア（min 昇順）。出典: fk-result.jsx FK_TIERS。
    static let tiers: [Rank] = [
        Rank(min: 0,  name: "はじめの一歩",     note: "記録のはじまり"),
        Rank(min: 5,  name: "食べきり上手",     note: "いい習慣が育っています"),
        Rank(min: 12, name: "ムダなしの達人",   note: "冷蔵庫がいつもすっきり"),
        Rank(min: 20, name: "食べきりマイスター", note: "もう、ムダ知らず"),
    ]

    /// count に対応する称号（count >= min を満たす最上位）。
    /// tiers は昇順なので count 以上の最後のティアを返す。空集合になりえないため必ず1件返る。
    static func rank(for count: Int) -> Rank {
        var t = tiers[0]
        for x in tiers where count >= x.min {
            t = x
        }
        return t
    }
}
