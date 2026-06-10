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

    /// 全カテゴリ（順序は仕様確定の並び）。
    static let all: [FoodCategory] = [
        FoodCategory(id: "fish",    name: "魚・刺身",    glyph: "魚", defaultDays: 1,  perishable: true,  color: Color(hex: 0x5f93a2), defaultAmountMode: .amount, defaultUnit: "切",     defaultName: "刺身"),
        FoodCategory(id: "chicken", name: "鶏肉",        glyph: "鶏", defaultDays: 2,  perishable: true,  color: Color(hex: 0xd98a66), defaultAmountMode: .amount, defaultUnit: "パック", defaultName: "鶏むね肉"),
        FoodCategory(id: "meat",    name: "豚・牛肉",    glyph: "肉", defaultDays: 3,  perishable: true,  color: Color(hex: 0xc06a5a), defaultAmountMode: .amount, defaultUnit: "パック", defaultName: "豚こま"),
        FoodCategory(id: "leafy",   name: "葉物野菜",    glyph: "菜", defaultDays: 3,  perishable: true,  color: Color(hex: 0x7fa257), defaultAmountMode: .amount, defaultUnit: "束",     defaultName: "ほうれん草"),
        FoodCategory(id: "veg",     name: "野菜",        glyph: "野", defaultDays: 5,  perishable: true,  color: Color(hex: 0x8aa86e), defaultAmountMode: .amount, defaultUnit: "個",     defaultName: "トマト"),
        FoodCategory(id: "mush",    name: "きのこ",      glyph: "茸", defaultDays: 4,  perishable: true,  color: Color(hex: 0xab8d68), defaultAmountMode: .amount, defaultUnit: "パック", defaultName: "しめじ"),
        FoodCategory(id: "fruit",   name: "果物",        glyph: "果", defaultDays: 5,  perishable: true,  color: Color(hex: 0xd6a04f), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "バナナ"),
        FoodCategory(id: "dairy",   name: "牛乳・乳製品", glyph: "乳", defaultDays: 5,  perishable: true,  color: Color(hex: 0xc9b487), defaultAmountMode: .amount, defaultUnit: "本",     defaultName: "牛乳"),
        FoodCategory(id: "tofu",    name: "豆腐・納豆",  glyph: "豆", defaultDays: 4,  perishable: true,  color: Color(hex: 0xb3ad74), defaultAmountMode: .count,  defaultUnit: "丁",     defaultName: "絹ごし豆腐"),
        FoodCategory(id: "deli",    name: "惣菜・弁当",  glyph: "惣", defaultDays: 1,  perishable: true,  color: Color(hex: 0xc98a4f), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "お惣菜"),
        FoodCategory(id: "bread",   name: "パン",        glyph: "パ", defaultDays: 3,  perishable: true,  color: Color(hex: 0xcaa06a), defaultAmountMode: .count,  defaultUnit: "枚",     defaultName: "食パン"),
        FoodCategory(id: "egg",     name: "卵",          glyph: "卵", defaultDays: 14, perishable: false, color: Color(hex: 0xcbb06f), defaultAmountMode: .count,  defaultUnit: "個",     defaultName: "卵"),
    ]

    /// id からカテゴリを引く。未知の id は nil。
    static func find(_ id: String) -> FoodCategory? {
        all.first { $0.id == id }
    }
}
