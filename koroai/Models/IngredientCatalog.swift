// 食材プリセットの静的マスタ。10セクション × プリセットカード（計77枚）。
//
// 追加フローの「選ぶ」画面のタイル単位＝この IngredientPreset。
// セクション（見た目・色・アイコン・perishable）は FoodCategory（10件）が持ち、
// プリセットは sectionId でそれに紐づく。FoodItem の catId にはセクション id を入れる。
//
// id は「sectionId.スラッグ」形式の安定文字列。カスタム既定値（PresetCustomDefault）の
// 永続キーになるため、一度公開したら変えない（変えると過去のカスタム既定値が引けなくなる）。

import Foundation

/// 食材プリセット1件分の静的定義。
struct IngredientPreset: Identifiable, Hashable {
    /// 永続キー（例 "meat.chicken-breast"）。カスタム既定値の辞書キーなので安定させる。
    let id: String
    /// 所属セクション（FoodCategory）の id。
    let sectionId: String
    /// 既定アイテム名（commit 時の名前フォールバック・プレースホルダー）。
    let name: String
    /// タイル表示名（通常 name と同じ。汎用カードのみ「その他の◯◯」）。
    let label: String
    /// 既定のもち日数。
    let days: Int
    /// 既定の残量モード。
    let mode: AmountMode
    /// 既定の単位。
    let unit: String
    /// 汎用カード（各セクション末尾の「その他の◯◯」）か。
    let isGeneric: Bool

    init(
        _ id: String,
        section: String,
        name: String,
        label: String? = nil,
        days: Int,
        mode: AmountMode,
        unit: String,
        generic: Bool = false
    ) {
        self.id = id
        self.sectionId = section
        self.name = name
        self.label = label ?? name
        self.days = days
        self.mode = mode
        self.unit = unit
        self.isGeneric = generic
    }
}

enum IngredientCatalog {

    /// 全プリセット（カタログ定義順。各セクション末尾に汎用カード）。
    static let all: [IngredientPreset] = [
        // MARK: meat（肉）
        IngredientPreset("meat.chicken-breast", section: "meat", name: "鶏むね肉",          days: 2, mode: .amount, unit: "パック"),
        IngredientPreset("meat.chicken-thigh",  section: "meat", name: "鶏もも肉",          days: 2, mode: .amount, unit: "パック"),
        IngredientPreset("meat.ground",         section: "meat", name: "ひき肉",            days: 1, mode: .amount, unit: "パック"),
        IngredientPreset("meat.pork-komagire",  section: "meat", name: "豚こま",            days: 2, mode: .amount, unit: "パック"),
        IngredientPreset("meat.pork-belly",     section: "meat", name: "豚バラ",            days: 2, mode: .amount, unit: "パック"),
        IngredientPreset("meat.beef",           section: "meat", name: "牛肉（切り落とし等）", days: 3, mode: .amount, unit: "パック"),
        IngredientPreset("meat.bacon",          section: "meat", name: "ベーコン",          days: 7, mode: .amount, unit: "パック"),
        IngredientPreset("meat.ham",            section: "meat", name: "ハム",              days: 5, mode: .count,  unit: "枚"),
        IngredientPreset("meat.sausage",        section: "meat", name: "ソーセージ",        days: 7, mode: .count,  unit: "本"),
        IngredientPreset("meat.other",          section: "meat", name: "肉",                label: "その他の肉", days: 2, mode: .amount, unit: "パック", generic: true),

        // MARK: fish（魚介）
        IngredientPreset("fish.sashimi",        section: "fish", name: "刺身",                days: 1, mode: .amount, unit: "パック"),
        IngredientPreset("fish.fillet",         section: "fish", name: "切り身（鮭・タラ等）", days: 2, mode: .count,  unit: "切"),
        IngredientPreset("fish.blue",           section: "fish", name: "青魚（サバ・アジ等）", days: 1, mode: .amount, unit: "尾"),
        IngredientPreset("fish.shrimp",         section: "fish", name: "えび",                days: 2, mode: .amount, unit: "パック"),
        IngredientPreset("fish.shirasu",        section: "fish", name: "しらす",              days: 3, mode: .amount, unit: "パック"),
        IngredientPreset("fish.kamaboko",       section: "fish", name: "ちくわ・かまぼこ",     days: 5, mode: .count,  unit: "本"),
        IngredientPreset("fish.other",          section: "fish", name: "魚介",                label: "その他の魚介", days: 1, mode: .amount, unit: "パック", generic: true),

        // MARK: veg（野菜）
        IngredientPreset("veg.cabbage",         section: "veg", name: "キャベツ",          days: 7,  mode: .amount, unit: "玉"),
        IngredientPreset("veg.lettuce",         section: "veg", name: "レタス",            days: 4,  mode: .amount, unit: "玉"),
        IngredientPreset("veg.leafy-greens",    section: "veg", name: "ほうれん草・小松菜",  days: 3,  mode: .amount, unit: "束"),
        IngredientPreset("veg.tomato",          section: "veg", name: "トマト",            days: 5,  mode: .count,  unit: "個"),
        IngredientPreset("veg.cucumber",        section: "veg", name: "きゅうり",          days: 4,  mode: .count,  unit: "本"),
        IngredientPreset("veg.eggplant",        section: "veg", name: "なす",              days: 5,  mode: .count,  unit: "本"),
        IngredientPreset("veg.pepper",          section: "veg", name: "ピーマン",          days: 7,  mode: .count,  unit: "個"),
        IngredientPreset("veg.broccoli",        section: "veg", name: "ブロッコリー",      days: 4,  mode: .amount, unit: "株"),
        IngredientPreset("veg.daikon",          section: "veg", name: "大根",              days: 7,  mode: .amount, unit: "本"),
        IngredientPreset("veg.carrot",          section: "veg", name: "にんじん",          days: 7,  mode: .count,  unit: "本"),
        IngredientPreset("veg.onion",           section: "veg", name: "玉ねぎ",            days: 10, mode: .count,  unit: "個"),
        IngredientPreset("veg.potato",          section: "veg", name: "じゃがいも",        days: 10, mode: .count,  unit: "個"),
        IngredientPreset("veg.beansprout",      section: "veg", name: "もやし",            days: 2,  mode: .amount, unit: "袋"),
        IngredientPreset("veg.negi",            section: "veg", name: "ねぎ",              days: 5,  mode: .amount, unit: "本"),
        IngredientPreset("veg.cut",             section: "veg", name: "カット野菜",        days: 2,  mode: .amount, unit: "袋"),
        IngredientPreset("veg.other",           section: "veg", name: "野菜",              label: "その他の野菜", days: 5, mode: .amount, unit: "個", generic: true),

        // MARK: mush（きのこ）
        IngredientPreset("mush.shimeji",        section: "mush", name: "しめじ",            days: 4, mode: .amount, unit: "パック"),
        IngredientPreset("mush.enoki",          section: "mush", name: "えのき",            days: 3, mode: .amount, unit: "パック"),
        IngredientPreset("mush.shiitake",       section: "mush", name: "しいたけ",          days: 4, mode: .amount, unit: "パック"),
        IngredientPreset("mush.maitake",        section: "mush", name: "まいたけ",          days: 4, mode: .amount, unit: "パック"),
        IngredientPreset("mush.eringi",         section: "mush", name: "エリンギ",          days: 5, mode: .amount, unit: "パック"),
        IngredientPreset("mush.nameko",         section: "mush", name: "なめこ",            days: 3, mode: .amount, unit: "袋"),
        IngredientPreset("mush.other",          section: "mush", name: "きのこ",            label: "その他のきのこ", days: 4, mode: .amount, unit: "パック", generic: true),

        // MARK: fruit（果物）
        IngredientPreset("fruit.banana",        section: "fruit", name: "バナナ",           days: 4,  mode: .count, unit: "本"),
        IngredientPreset("fruit.apple",         section: "fruit", name: "りんご",           days: 10, mode: .count, unit: "個"),
        IngredientPreset("fruit.citrus",        section: "fruit", name: "みかん・柑橘",      days: 7,  mode: .count, unit: "個"),
        IngredientPreset("fruit.strawberry",    section: "fruit", name: "いちご",           days: 3,  mode: .amount, unit: "パック"),
        IngredientPreset("fruit.grape",         section: "fruit", name: "ぶどう",           days: 4,  mode: .amount, unit: "パック"),
        IngredientPreset("fruit.kiwi",          section: "fruit", name: "キウイ",           days: 7,  mode: .count, unit: "個"),
        IngredientPreset("fruit.other",         section: "fruit", name: "果物",             label: "その他の果物", days: 5, mode: .count, unit: "個", generic: true),

        // MARK: dairy（乳製品）
        IngredientPreset("dairy.milk",          section: "dairy", name: "牛乳",             days: 5,  mode: .amount, unit: "本"),
        IngredientPreset("dairy.yogurt",        section: "dairy", name: "ヨーグルト",       days: 7,  mode: .amount, unit: "パック"),
        IngredientPreset("dairy.cheese",        section: "dairy", name: "チーズ",           days: 14, mode: .amount, unit: "袋"),
        IngredientPreset("dairy.butter",        section: "dairy", name: "バター",           days: 21, mode: .amount, unit: "箱"),
        IngredientPreset("dairy.cream",         section: "dairy", name: "生クリーム",       days: 4,  mode: .amount, unit: "本"),
        IngredientPreset("dairy.other",         section: "dairy", name: "乳製品",           label: "その他の乳製品", days: 5, mode: .amount, unit: "本", generic: true),

        // MARK: egg（卵）
        IngredientPreset("egg.egg",             section: "egg", name: "卵",               days: 14, mode: .count, unit: "個"),
        IngredientPreset("egg.boiled",          section: "egg", name: "ゆで卵",           days: 3,  mode: .count, unit: "個"),
        IngredientPreset("egg.quail",           section: "egg", name: "うずらの卵",       days: 7,  mode: .count, unit: "個"),
        IngredientPreset("egg.other",           section: "egg", name: "卵",               label: "その他の卵", days: 14, mode: .count, unit: "個", generic: true),

        // MARK: tofu（大豆）
        IngredientPreset("tofu.tofu",           section: "tofu", name: "豆腐",             days: 4, mode: .count,  unit: "丁"),
        IngredientPreset("tofu.natto",          section: "tofu", name: "納豆",             days: 7, mode: .count,  unit: "パック"),
        IngredientPreset("tofu.aburaage",       section: "tofu", name: "油揚げ",           days: 5, mode: .count,  unit: "枚"),
        IngredientPreset("tofu.atsuage",        section: "tofu", name: "厚揚げ",           days: 4, mode: .count,  unit: "枚"),
        IngredientPreset("tofu.soymilk",        section: "tofu", name: "豆乳",             days: 5, mode: .amount, unit: "本"),
        IngredientPreset("tofu.other",          section: "tofu", name: "大豆製品",         label: "その他の大豆製品", days: 4, mode: .count, unit: "個", generic: true),

        // MARK: staple（主食）
        IngredientPreset("staple.rice",         section: "staple", name: "ごはん（冷蔵）",  days: 2,  mode: .amount, unit: "杯"),
        IngredientPreset("staple.bread",        section: "staple", name: "食パン",          days: 3,  mode: .count, unit: "枚"),
        IngredientPreset("staple.pastry",       section: "staple", name: "菓子パン・総菜パン", days: 2, mode: .count, unit: "個"),
        IngredientPreset("staple.mochi",        section: "staple", name: "もち",            days: 14, mode: .count, unit: "個"),
        IngredientPreset("staple.udon",         section: "staple", name: "ゆでうどん",      days: 4,  mode: .count, unit: "玉"),
        IngredientPreset("staple.fresh-noodle", section: "staple", name: "生麺・中華麺",     days: 5,  mode: .count, unit: "玉"),
        IngredientPreset("staple.other",        section: "staple", name: "主食",            label: "その他の主食", days: 3, mode: .count, unit: "個", generic: true),

        // MARK: deli（惣菜・その他）
        IngredientPreset("deli.osozai",         section: "deli", name: "お惣菜",            days: 1,  mode: .amount, unit: "パック"),
        IngredientPreset("deli.bento",          section: "deli", name: "お弁当",            days: 1,  mode: .count, unit: "個"),
        IngredientPreset("deli.tsukurioki",     section: "deli", name: "作り置き",          days: 3,  mode: .amount, unit: "個"),
        IngredientPreset("deli.tsukemono",      section: "deli", name: "漬物・キムチ",      days: 10, mode: .amount, unit: "パック"),
        IngredientPreset("deli.salad",          section: "deli", name: "サラダ",            days: 2,  mode: .amount, unit: "袋"),
        IngredientPreset("deli.other",          section: "deli", name: "その他",            label: "その他", days: 5, mode: .amount, unit: "個", generic: true),
    ]

    /// id 索引（高速 find 用）。
    private static let byId: [String: IngredientPreset] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    /// id からプリセットを引く。未知の id は nil。
    static func find(_ id: String) -> IngredientPreset? { byId[id] }

    /// 指定セクションのプリセット（カタログ定義順）。
    static func presets(in sectionId: String) -> [IngredientPreset] {
        all.filter { $0.sectionId == sectionId }
    }
}
