// 設定「フィードバックを送る」の mailto URL 組み立てのテスト。
//
// 宛先・件名・本文（診断行）が正しくエンコードされ、復元できることを検証する。

import Testing
import Foundation
@testable import koroai

struct FeedbackMailTests {

    @Test func mailtoURLBasics() throws {
        let url = try #require(FeedbackMail.mailtoURL(appVersion: "1.0", osVersion: "17.5"))
        #expect(url.scheme == "mailto")

        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.path == "koroai.dev@gmail.com")
    }

    @Test func subjectAndBodyRoundTrip() throws {
        let url = try #require(FeedbackMail.mailtoURL(appVersion: "1.2.3", osVersion: "18.0"))
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(comps.queryItems)

        let subject = items.first { $0.name == "subject" }?.value
        #expect(subject == "ころあいへのフィードバック")

        let body = try #require(items.first { $0.name == "body" }?.value)
        // 診断行にアプリ/OS バージョンが入る。
        #expect(body.contains("ころあい v1.2.3"))
        #expect(body.contains("iOS 18.0"))
    }

    @Test func addressIsStable() {
        // SettingsScreen のコピー用フォールバックが参照する公開アドレス。
        #expect(FeedbackMail.address == "koroai.dev@gmail.com")
    }
}
