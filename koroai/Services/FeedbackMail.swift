// 設定「フィードバックを送る」の mailto URL 組み立て（純関数・テスト対象）。
//
// 方式はユーザー決定: mailto でメールアプリを開く。サーバー・フォームは使わない。
// 本文末尾にアプリ/OS バージョンの診断行を添える（ユーザーが消してもよい）。
// メールが開けない環境のフォールバック（宛先コピー）は SettingsScreen 側の責務。

import Foundation

enum FeedbackMail {

    /// フィードバックの宛先アドレス。
    static let address = "koroai.dev@gmail.com"

    /// 件名・本文テンプレート付きの mailto URL。
    /// - Parameters:
    ///   - appVersion: CFBundleShortVersionString。
    ///   - osVersion: iOS のバージョン文字列。
    static func mailtoURL(appVersion: String, osVersion: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = address
        comps.queryItems = [
            URLQueryItem(name: "subject", value: "ころあいへのフィードバック"),
            URLQueryItem(
                name: "body",
                value: "\n\n――――――――\nころあい v\(appVersion) / iOS \(osVersion)\n"
            ),
        ]
        return comps.url
    }
}
