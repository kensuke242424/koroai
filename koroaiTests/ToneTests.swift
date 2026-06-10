// Tone.dayLabel の全マトリクス検証。文言はプロトタイプ準拠で一字一句固定。

import Testing
@testable import koroai

struct ToneTests {

    @Test(arguments: [
        (0, "今日中に"),
        (-1, "今日中に"),
        (1, "あすまで"),
        (2, "あと2日"),
        (5, "あと5日"),
    ])
    func gentle(daysLeft: Int, expected: String) {
        #expect(Tone.dayLabel(daysLeft: daysLeft, tone: .gentle) == expected)
    }

    @Test(arguments: [
        (0, "今日"),
        (3, "3日"),
    ])
    func simple(daysLeft: Int, expected: String) {
        #expect(Tone.dayLabel(daysLeft: daysLeft, tone: .simple) == expected)
    }

    @Test(arguments: [
        (0, "いま食べごろ"),
        (1, "そろそろ"),
        (2, "あと2日"),
        (3, "あと3日"),
        (4, "ゆっくりでOK"),
    ])
    func cheer(daysLeft: Int, expected: String) {
        #expect(Tone.dayLabel(daysLeft: daysLeft, tone: .cheer) == expected)
    }
}
