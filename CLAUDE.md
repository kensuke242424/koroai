# CLAUDE.md — ころあい（Koroai）

> 全プロジェクト共通方針（関西弁・push前確認・依存追加前に相談・xcodes 運用）は `~/.claude/CLAUDE.md`。
> ここには **koroai 固有** のことだけ書く。

## 概要
「ころあい（Koroai）」＝冷蔵庫の食材を **食べ頃のうちに使いきる** ことを応援する iOS アプリ。
食品ロスを罪悪感ではなく **やさしさ** で減らす。体験ループは「足す → 食べ頃を知る → 食べきりを記録する」。
正式名称は「ころあい」。旧称 **`FreshKeep` をコード・コピーに残さない**。

## 仕様の正（優先順）
1. **`design_handoff_koroai/README.md`** … 仕様の正。画面・state machine・スキーマ・カテゴリ・トークン・原則はまずここ。
2. **`design_handoff_koroai/prototype/fk-data.js`** … README 表で「—」になっている値（既定もち日数・残量モード・単位など）の正。
3. **`design_handoff_koroai/screenshots/`** … 最終的な見た目。**ホームはスクショ01＝プロトタイプ案C**
   （ヒーローカード1枚＋「今週の食材」リスト＋折りたたみ「ゆとりあり」）が確定形。

- `prototype/` は見た目と挙動の **参照のみ**。`window.FKT/FKD`・localStorage 直書き・ブラウザ内 Babel は
  デモの都合。SwiftUI / SwiftData で作り直す。
- README と prototype が食い違う・解釈に迷う → **実装を進める前に質問**。

## ターゲット環境（確定・ブレさせない）
- Swift / SwiftUI、最低サポート **iOS 17**。Bundle ID **`app.koroai.ios`**、表示名「ころあい」。
- アーキ：**MV(VM)**（`@Observable`/`@State`、SwiftData は `@Query` 直結）。過剰な抽象化はしない。
- 永続化：**SwiftData**。食べきり集計（今月/先週/通算/連続月）は記録ログから **クエリで導出**（カウンタ直持ちしない）。
- 通知：**ローカル通知のみ（UserNotifications）**。サーバープッシュは使わない。
- **外部ライブラリはゼロ依存**。追加が要るなら理由とトレードオフを先に相談。

## ビルド検証（シミュレータ・署名回避）
```sh
xcodebuild build -project koroai.xcodeproj -scheme koroai \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
実機向けに署名が要るときだけ DEVELOPMENT_TEAM を指定する。

## 不変ルール（デザイン原則）
- **期限の色に赤を使わない。** urgency は「残日数 → 色」の **純粋関数で一元管理**
  （セージグリーン→アンバー→テラコッタ／OKLCH／hue = 34 + clamp(days,0,7)/7 × (150−34)）。
- 期限は **絶対日付 `expiresAt` を保存**し、残日数は今日との暦日差で **算出**（保存しない＝実時間で減る）。
- もち日数は **ステッパー⇄カレンダー双方向同期**。**過去日は選択不可**。
- 残量は **未設定OK（必須にしない）**。`amount`（吸着スライダー）/ `count`（個数）の2モード。
  カテゴリで初期モードを出し分け、ユーザー上書き可。
- 食材アイコンに **絵文字を使わない**（カテゴリ色の円＋単色の漢字1字グリフ）。
- コピーは **責めないトーン**（gentle / simple / cheer、既定 gentle）。空状態・通知も急かさない。

## コード方針
- デザイントークン（色・タイポ・角丸・間隔・urgency 関数・トーン辞書）は **`DesignSystem/` に一元化**してから画面を組む。
- 構成の目安：`DesignSystem/` `Models/` `Features/<画面>/` `Components/` `Services/`。
- 間隔は 8 基調、タップ領域は最低 44px。テーマは OS設定 / ライト / ナイトの3択（OS がダーク時は**ナイト**）。パレットは hinoki 既定。
- 和文 **M PLUS Rounded 1c**・欧文 **Quicksand** は**システムフォントではない**（Google Fonts / OFL）。
  使うならフォントファイルのバンドルが必要。バンドルしない間は SF Rounded（`.rounded`）でフォールバック。

## リポジトリの注意
- `design_handoff_koroai/` は **内部に独自の `.git` を持つ**参照資料。そのまま `git add` すると gitlink 化して
  事故る。コミットするか除外するかは未決 — **触る前にユーザーに確認**。

## 進め方
- **機能単位で小さくコミット。** 各ステップで「何を作るか」を短く宣言してから着手する。
