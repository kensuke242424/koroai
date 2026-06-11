// 食材カテゴリの静的マスタ。SwiftData の外（プレーンな値型）で持つ。
// カテゴリ定義はアプリ同梱の固定データであり、ユーザーデータではないため永続化しない。
// 食材（FoodItem）は catId を保持し、表示時に find(_:) で解決する。
// アイコンは絵文字を使わず、カテゴリ色の円＋漢字1字グリフで表現する設計。

import SwiftUI

/// 残量の入力モード。`amount` は 0...1 の吸着スライダー、`count` は個数。
enum AmountMode: String, Codable, CaseIterable {
    case amount
    case count
}

/// 食材カテゴリ1件分の静的定義。
struct FoodCategory: Identifiable, Hashable {
    let id: String
    /// 表示名（例: 魚・刺身）。
    let name: String
    /// アイコン用の漢字1文字グリフ（絵文字不使用）。
    let glyph: String
    /// 既定のもち日数。追加時の初期 expiresAt 算出に使う。
    let defaultDays: Int
    /// 生鮮かどうか。true = 生鮮（ホームで前面化）/ false = 保存寄り。
    let perishable: Bool
    /// カテゴリ色（既存の Color(hex:) で生成）。
    let color: Color
    /// 既定の残量モード。ユーザーが上書き可。
    let defaultAmountMode: AmountMode
    /// 既定の単位（例: 切 / パック / 個）。
    let defaultUnit: String
    /// 追加プレースホルダー／シード用の代表名（例: 刺身）。
    let defaultName: String

    /// 全カテゴリ（=10セクション。順序は仕様確定の並び。タイル＝食材プリセットは IngredientCatalog）。
    static let all: [FoodCategory] = [
        FoodCategory(id: "meat",   name: "肉",          glyph: "肉", defaultDays: 2,  perishable: true,  color: Color(hex: 0xc06a5a), defaultAmountMode: .amount, defaultUnit: "パック", defaultName: "豚こま"),
        FoodCategory(id: "fish",   name: "魚介",        glyph: "魚", defaultDays: 1,  perishable: true,  color: Color(hex: 0x5f93a2), defaultAmountMode: .amount, defaultUnit: "パック", defaultName: "刺身"),
        FoodCategory(id: "veg",    name: "野菜",        glyph: "野", defaultDays: 5,  perishable: true,  color: Color(hex: 0x8aa86e), defaultAmountMode: .amount, defaultUnit: "個",     defaultName: "トマト"),
        FoodCategory(id: "mush",   name: "きのこ",      glyph: "茸", defaultDays: 4,  perishable: true,  color: Color(hex: 0xab8d68), defaultAmountMode: .amount, defaultUnit: "パック", defaultName: "しめじ"),
        FoodCategory(id: "fruit",  name: "果物",        glyph: "果", defaultDays: 5,  perishable: true,  color: Color(hex: 0xd6a04f), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "バナナ"),
        FoodCategory(id: "dairy",  name: "乳製品",      glyph: "乳", defaultDays: 5,  perishable: true,  color: Color(hex: 0xc9b487), defaultAmountMode: .amount, defaultUnit: "本",     defaultName: "牛乳"),
        FoodCategory(id: "egg",    name: "卵",          glyph: "卵", defaultDays: 14, perishable: false, color: Color(hex: 0xcbb06f), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "卵"),
        FoodCategory(id: "tofu",   name: "大豆",        glyph: "豆", defaultDays: 4,  perishable: true,  color: Color(hex: 0xb3ad74), defaultAmountMode: .count,  defaultUnit: "丁",     defaultName: "豆腐"),
        FoodCategory(id: "staple", name: "主食",        glyph: "飯", defaultDays: 3,  perishable: true,  color: Color(hex: 0xcaa06a), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "食パン"),
        FoodCategory(id: "deli",   name: "惣菜・その他", glyph: "惣", defaultDays: 1,  perishable: true,  color: Color(hex: 0xc98a4f), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "お惣菜"),
    ]

    /// 旧カテゴリ id → 新セクション id のエイリアス。
    /// 旧12カテゴリ時代に保存された FoodItem.catId / ConsumptionLog.catId を解決するために必須
    /// （カタログ再編前のユーザーデータと後方互換を保つ）。
    private static let legacyAliases: [String: String] = [
        "chicken": "meat",  // 旧「鶏肉」→「肉」へ統合
        "leafy": "veg",     // 旧「葉物野菜」→「野菜」へ統合
        "bread": "staple",  // 旧「パン」→「主食」へ統合
    ]

    /// id からカテゴリを引く。未知の id はレガシーエイリアスで解決を試み、なお無ければ nil。
    static func find(_ id: String) -> FoodCategory? {
        if let cat = all.first(where: { $0.id == id }) { return cat }
        if let aliased = legacyAliases[id] { return all.first { $0.id == aliased } }
        return nil
    }
}
