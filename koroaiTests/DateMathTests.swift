// DateMath（残日数の算出と期限日の生成）の決定性テスト。
// Date() / Calendar.current には依存せず、固定 Calendar + 固定 Date を使う。

import Testing
import Foundation
@testable import koroai

struct DateMathTests {

    /// Asia/Tokyo 固定の gregorian カレンダー。
    static func tokyoCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }

    /// 指定タイムゾーンの gregorian カレンダー。
    static func calendar(_ tzID: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tzID)!
        return cal
    }

    /// components から固定 Date を作る。
    static func date(_ cal: Calendar, _ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    // MARK: - 往復（不変条件）

    @Test(arguments: [0, 1, 7, 14, 30])
    func roundTrip(n: Int) {
        let cal = Self.tokyoCalendar()
        let now = Self.date(cal, 2026, 6, 10, 9, 30)
        let expiry = DateMath.expiryDate(daysFromNow: n, from: now, calendar: cal)
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == n)
    }

    // MARK: - 時刻無視（startOfDay 差）

    @Test func ignoresTimeAcrossMidnight() {
        let cal = Self.tokyoCalendar()
        let now = Self.date(cal, 2026, 6, 10, 23, 50)
        let expiry = Self.date(cal, 2026, 6, 11, 0, 10)
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == 1)
    }

    @Test func ignoresTimeSameDay() {
        let cal = Self.tokyoCalendar()
        let now = Self.date(cal, 2026, 6, 10, 0, 10)
        let expiry = Self.date(cal, 2026, 6, 10, 23, 50)
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == 0)
    }

    // MARK: - 月跨ぎ・年跨ぎ

    @Test func crossesMonthBoundary() {
        let cal = Self.tokyoCalendar()
        let now = Self.date(cal, 2026, 1, 30)
        let expiry = Self.date(cal, 2026, 2, 2)
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == 3)
    }

    @Test func crossesYearBoundary() {
        let cal = Self.tokyoCalendar()
        let now = Self.date(cal, 2026, 12, 30)
        let expiry = Self.date(cal, 2027, 1, 2)
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == 3)
    }

    // MARK: - 過去

    @Test func pastExpiryIsNegative() {
        let cal = Self.tokyoCalendar()
        let now = Self.date(cal, 2026, 6, 10)
        let expiry = Self.date(cal, 2026, 6, 9)
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == -1)
    }

    // MARK: - DST（春の繰り上げを跨ぐ）

    @Test func dstSpringForward() {
        let cal = Self.calendar("America/Los_Angeles")
        let now = Self.date(cal, 2026, 3, 7, 12, 0)
        let expiry = Self.date(cal, 2026, 3, 9, 12, 0)   // 3/8 spring forward を跨ぐ
        #expect(DateMath.daysLeft(until: expiry, from: now, calendar: cal) == 2)
    }
}
