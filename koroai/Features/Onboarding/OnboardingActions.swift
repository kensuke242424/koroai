// オンボーディング完了時の投入処理（テスト可能・in-memory コンテナで検証）。
//
// 確定済みの設計判断（Step 8）:
//  - 選択カテゴリだけを FoodItem.make の既定で投入する（プロトタイプのデモ用 fkSeedFridge は無視）。
//  - スキップ（選択 0 件）は何も投入しない（空状態のホームを見せる）。
//  - ConsumptionLog は一切作らない。

import Foundation
import SwiftData

enum OnboardingActions {

    /// 選択カテゴリを FoodItem.make の既定で投入する。空配列なら何もしない。
    /// 「使い方ガイド」再生時も同じ挙動でよい（既存の食材には触れず追加投入する）。
    @MainActor
    static func seedSelected(
        _ catIds: some Collection<String>,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard !catIds.isEmpty else { return }
        for id in catIds {
            guard let cat = FoodCategory.find(id) else { continue }
            context.insert(FoodItem.make(category: cat, now: now, calendar: calendar))
        }
        try? context.save()
    }
}
