# 実装プラン（2026-06-10 合意）

状態：環境整備済み・実装未着手。仕様の正は `design_handoff_koroai/README.md`（読み方の優先順は CLAUDE.md 参照）。

## (a) プロジェクト構成 / View 分割

```
koroai/koroai/
├─ koroaiApp.swift                     // @main, ModelContainer, AppStore注入
├─ DesignSystem/                       // ★最初に一元化
│  ├─ Theme.swift                      // ThemeMode(light/night/dark)・解決ロジック(OS追従: OSダーク→night)
│  ├─ Tokens.swift                     // 色トークン(bg/surface/text/brand/accent…) light/dark/night
│  ├─ Urgency.swift                    // 純関数: 残日数→色(sage→amber→terracotta), tier, dayLabel(tone別)
│  ├─ Typography.swift                 // M PLUS Rounded 1c / Quicksand 登録 & Font拡張
│  ├─ Layout.swift                     // Spacing(8基調)・Radius・Shadow
│  └─ Tone.swift                       // gentle/simple/cheer コピー辞書
├─ Models/
│  ├─ FoodItem.swift                   // @Model（SwiftData）
│  ├─ ConsumptionLog.swift             // @Model（食べきり/処分の記録）
│  ├─ FoodCategory.swift               // 静的マスタ（fk-data.js 準拠の12種）
│  └─ AppStore.swift                   // @Observable 設定・派生状態（@AppStorage裏付け）
├─ Features/
│  ├─ Home/                            // HomeView, HeroCard, ItemRow, PlentySection,
│  │                                   //   AchievementCard, MetaRow, EmptyFridge, FAB
│  ├─ AddFlow/                         // AddSheet(カテゴリ・セクション・かご), DetailEntryView
│  ├─ Edit/                            // EditSheet
│  ├─ Components/                      // CategoryIcon, DayPill, AmountIndicator, DaysStepper,
│  │                                   //   CalendarPicker(双方向同期), AmountControl(slider/count), Toast, Sheet
│  ├─ Digest/  Review/  MonthResult/  Return/  Settings/  Onboarding/
├─ Services/
│  └─ NotificationService.swift        // UserNotifications（期限前・朝のまとめ）
└─ Assets.xcassets                     // AppIcon ← brand/koroai-icon-1024.png（α破棄）, AccentColor=テラコッタ
```

方針：MV(VM)。SwiftData は `@Query` で View 直結。複雑な一時状態（かご・カレンダー⇄ステッパー）だけ
`@Observable` の ViewModel を切る。過剰な抽象化はしない。

## (b) SwiftData モデル（README スキーマ対応）

```swift
@Model final class FoodItem {
    var id: UUID                 // README: id
    var catId: String            // README: catId（FoodCategory.id）
    var name: String             // README: name
    var purchasedAt: Date        // README: addedAt
    var expiresAt: Date          // README: days → 期限日に変換して保存（残日数の源）
    var perishable: Bool         // README: perishable（カテゴリ由来をコピー）
    var amountModeRaw: String    // README: amtMode（'amount' | 'count'）
    var amount: Double           // README: amt（0...1）
    var quantity: Int            // README: qty
    var quantityTotal: Int       // README: qtyTotal（編集時のピル表示）
    var unit: String             // README: unit
    var amountIsSet: Bool        // 「残量 未設定OK」を表現
    var note: String?            // データ土台の「メモ」
}
```
- 残日数は computed（`Calendar` で今日→`expiresAt` の暦日差）。保存しない＝実時間で減る。
- README `days` → `expiresAt` のみ非1:1。他は1:1対応。

```swift
@Model final class ConsumptionLog {   // 食べた/捨てた を1件ずつ記録
    var date: Date
    var catId: String
    var actionRaw: String   // ate | tossed
}
```
- 今月/先週/通算(lifetime)/連続月は ate 件数のクエリで導出。マイルストーン（1/3/7/12/20/40）は通算で判定。

`FoodCategory`（静的・SwiftData外）：`id, name, glyph, defaultDays, perishable, color,
defaultAmountMode, defaultUnit`。値は `prototype/fk-data.js` の `FK_CATEGORIES` / `FK_CAT_AMT_MODE` /
`FK_CAT_UNIT` / `FK_CAT_DEFAULT_NAME` をそのまま移植。

ホームの分割ロジック（fk-home.jsx `fkSplit` 準拠）：
`hero = perishable && 残日数≤6`（うち ≤2 がヒーローカード、3〜6 が「今週の食材」）、残りは「ゆとりあり」。

## (c) 実装順序（機能単位で小さくコミット）

1. **デザイントークン基盤＋scaffold整理** … DesignSystem/ 一式、bundle id → `app.koroai.ios`、
   表示名「ころあい」、AppIcon（brand/koroai-icon-1024.png、α破棄）、フォントバンドル（OFL）、`FreshKeep` 掃除
2. **SwiftData モデル＋カテゴリマスタ＋シード**（urgency/日付計算のユニットテストもここで）
3. **ホーム**（案C：ヒーロー／今週の食材／ゆとり／達成カード／メタ行／FAB／空状態）
4. **追加→詳細入力**（カテゴリセクション＋かご → ステッパー⇄カレンダー双方向・残量2モード）
5. **編集シート**（食べた／捨てた）
6. **ふりかえり**（マイルストーン）＋ **今朝のまとめ**
7. **設定**＋**ローカル通知**
8. **例外・自動表示**（月替わりリザルト・マイルストーン祝福・久しぶり起動）＋ **オンボーディング**

## 未決事項（着手時にユーザーへ確認）

- ヒーローカードの「レシピ」ボタン：レシピ機能は仕様未定義。v1 で外すか「準備中」プレースホルダーか。
- フォント取得：M PLUS Rounded 1c / Quicksand を Google Fonts からダウンロードする（外部取得のため一声かける）。
