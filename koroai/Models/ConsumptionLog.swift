// 食べきり／廃棄の記録ログ。SwiftData の永続モデル。
//
// 食べきり集計（今月／先週／通算／連続月など）はカウンタを直持ちせず、
// このログのクエリで導出する方針（実装は後続 Step）。
// カウンタを持たないことで、記録の追加・削除が常に集計と整合する。

import Foundation
import SwiftData

/// 記録のアクション。食べきり or 廃棄。
enum ConsumptionAction: String, Codable, CaseIterable {
    case ate
    case tossed
}

@Model
final class ConsumptionLog {
    var date: Date
    /// 記録対象だった食材のカテゴリ id（カテゴリ別集計用）。
    var catId: String
    /// アクションの生値。action 経由で読み書きする。
    var actionRaw: String

    init(date: Date = .now, catId: String, action: ConsumptionAction) {
        self.date = date
        self.catId = catId
        self.actionRaw = action.rawValue
    }

    /// アクション。未知の生値は .ate にフォールバックする
    /// （壊れた生値を「廃棄」と誤って数えないため。集計はポジティブ寄りに倒す）。
    var action: ConsumptionAction {
        get { ConsumptionAction(rawValue: actionRaw) ?? .ate }
        set { actionRaw = newValue.rawValue }
    }
}
