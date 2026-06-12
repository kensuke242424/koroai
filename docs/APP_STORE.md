# App Store 提出メモ

> 提出時に App Store Connect 側で入力する内容の控え。アプリ内の実装と齟齬が出ないようここで管理する。

## プライバシー（App Privacy）

アプリ内の `koroai/PrivacyInfo.xcprivacy` が正。実態は以下の通り：

- **データ収集: なし**（App Store Connect の質問「データを収集していますか？」→ **いいえ**）
  - 食材・記録は端末内の SwiftData、設定は UserDefaults のみ。外部送信ゼロ。
  - ネットワーク通信を行うコードが存在しない（サーバープッシュなし・解析 SDK なし・広告なし）。
- **トラッキング: なし**
- **required reason API**: UserDefaults（CA92.1）のみ。
- 外部ライブラリ: ゼロ依存（サードパーティ SDK のマニフェスト合算は不要）。

## 提出前チェックリスト（残作業）

- [ ] プライバシーポリシー URL（App Store Connect で必須。ホスティング先未定）
- [ ] App アイコン（マーケティング用 1024px 含む）の最終確認
- [ ] スクリーンショット（6.9" / 6.5" 必須サイズ）
- [ ] サポート URL・マーケティング URL
- [ ] 設定「フィードバックを送る」の宛先確定（アプリ内実装と合わせる）
- [ ] 通知の実機発火確認（シミュレータでは確認済み → STATUS.md）
- [ ] Dynamic Type / アクセシビリティ対応
- [ ] 暗号化輸出コンプライアンス: 独自暗号なし → `ITSAppUsesNonExemptEncryption = NO` を Info.plist に追加予定

## 審査観点のメモ

- 通知はローカルのみ・遅延要求（初回スケジュール時にダイアログ）。Push Notifications entitlement 不要。
- 課金・アカウント・年齢制限対象コンテンツなし。
