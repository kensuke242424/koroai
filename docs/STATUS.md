# 進捗ステータス（2026-06-12 時点）

> セッションを跨ぐときの現在地。詳細な経緯は git log（機能単位でコミット）を参照。
> 仕様の正は `design_handoff_koroai/README.md`（追加フローのみ `ADD_FLOW.md` が置き換え）。

## 完了

`docs/IMPLEMENTATION_PLAN.md` の **Step 1〜8 すべて実装済み**。その後の主な追加・変更：

- **追加フローを刷新版（ADD_FLOW.md）に置き換え**：選ぶ（タイル→即カゴ・カウントチップトレイ）→ 確認・編集（カテゴリ別カード）の2ステップ。横プッシュ遷移、中68%⇄大100%の2段 detent（ハンドルのドラッグ/タップ）、トレイは1品以上で段階出現（CTA→チップの順）
- ふりかえりは NavigationStack の push 遷移（エッジスワイプバックは下記の対応で有効）
- 編集シートは 保存＋食べた/そっと処分（「登録を取り消す」はユーザー判断で削除）
- ヘッダー挙動：キッカーはトップのみ・大タイトルが隠れてから小タイトルに入替
- **食材カタログ再編（ユーザー確定・design_handoff のカテゴリ表を置き換え）**：10セクション×76プリセット
  （`Models/IngredientCatalog.swift` が正）。旧 catId（chicken/leafy/bread）は `FoodCategory.find` の
  エイリアスで解決（エイリアスを消すと旧データが表示不能になるので注意）
- **カスタム既定値**：追加 commit 時にプリセット既定との差分を AppStore（UserDefaults）へ記憶し
  次回タイルタップで自動適用。既定値に戻すと記憶は削除
- 選ぶ画面：タイトル「何を買ってきた？」はスクロールで隠れ、インラインタイトル「食材をえらぶ」
  （シート上端一体・bg2 92%透過）に入替。閉じ確認は「空にして閉じる/キャンセル」の2択

- **エッジスワイプバック対応**：ナビバー非表示の push（ふりかえり・設定）でも画面端スワイプで戻れる
  （`EdgeSwipeBack.swift`、interactivePopGestureRecognizer の delegate 差し替え）
- **通知のシミュレータ E2E 確認済み**：権限許可→登録→SpringBoard 配達→バナー表示まで確認
  （`-digestAt HH:mm` で朝のまとめ時刻を上書きして実発火を観測する手順。実機でも同手順可）
- **Dynamic Type / VoiceOver 対応**：全体 AX2 キャップ＋合成表示（ステッパー・ヒーロー数字・
  確認ヘッダー・ホームカード）は xxxLarge 個別キャップ。スライダー/ステッパー/detent ハンドルに
  adjustableAction、スワイプ操作は accessibilityAction、装飾アイコンは hidden
- **App Store 仕上げ**：PrivacyInfo.xcprivacy（収集なし・CA92.1 のみ）・
  ITSAppUsesNonExemptEncryption=NO・提出チェックリストは `docs/APP_STORE.md`
- **フィードバック導線**：mailto で `koroai.dev@gmail.com`（ユーザー確定）。件名・診断行つき本文は
  `Services/FeedbackMail.swift`（テスト対象）。メールが開けない環境は宛先コピー＋トーストにフォールバック

テスト：**225件 / 33スイート green**（urgency・OKLCH 既知値・日付計算・分割・通知プランナー・追加フロー・カタログ整合性・カスタム既定値等）。

## 検証ハーネス

```sh
# ビルド
xcodebuild build -project koroai.xcodeproj -scheme koroai \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
# テスト（iPhone 17 Pro シミュレータ）
xcodebuild test -project koroai.xcodeproj -scheme koroai \
  -destination 'platform=iOS Simulator,id=D60460C9-48CF-4B19-93A3-386DDBCAD6A2' CODE_SIGNING_ALLOWED=NO
```

DEBUG 起動引数（スクショ・検証用。新規インストール直後でも onboarded を立てて直行する）:
`-seedPreviewData`（空DBにシード投入）/ `-noNotifyPrompt` / `-openAddSheet` / `-openAddConfirm` / `-openCloseConfirm`（カゴに3品積んで閉じ確認を表示）/
`-autoAddOne <catId>`（表示1.2秒後にタイルタップと同経路で1件追加・録画検証用）/
`-openEditFirst` / `-openDigest` / `-openReview` / `-openSettings` / `-openOnboarding` /
`-openReturn` / `-openMonthResult` / `-scrollHome` / `-scrollAddSelect`（追加シートの選ぶ画面を全展開してスクロール・インラインタイトル表示）/ `-openCardCalendar`（確認カードのカレンダー展開を初期表示）/ `-autoCloseSheet`（表示1.5秒後に追加シートを自動で閉じる・閉じアニメ録画用）/
`-digestAt HH:mm`（朝のまとめ時刻を上書き＋通知ON。実発火の検証用。権限ダイアログを出すので -noNotifyPrompt と併用しない）

Dynamic Type の拡大検証は `xcrun simctl ui <UDID> content_size <large|extra-extra-extra-large|accessibility-extra-large>` で切替→スクショ。終わったら `large` に戻す。

動きの検証は `xcrun simctl io <UDID> recordVideo` ＋フレーム分解（メモリ swiftui-pitfalls 参照）。

## 残課題・未決

- **レシピボタン**＝「準備中」トースト（機能仕様が来たら実装。ユーザー決定）
- 通知の**実機での発火確認**は未実施（シミュレータ E2E は確認済み。実機接続時に `-digestAt` で同手順）
- App Store 提出系の残り（プライバシーポリシー URL・スクショ・アイコン最終確認等）は `docs/APP_STORE.md` のチェックリスト

## 触るときの注意（要点のみ・詳細はメモリ）

- 実装の進め方：メインが仕様精読・設計確定→Opus サブエージェントに自己完結プロンプトで委譲→スクショ/テストで監査→メインがコミット
- SwiftUI の罠リスト（frame(max:) 膨張・withAnimation 必須・PreferenceKey 不発・ドラッグは .global 座標）はメモリ `swiftui-pitfalls` に集約
- `design_handoff_koroai/` は読み取り専用。push は必ずユーザー確認
