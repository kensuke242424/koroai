// 日付計算の正準ヘルパー（純粋関数・テスト注入可能）。
//
// 設計の要: 残日数は「保存しない」。常に今日（now）と絶対期限（expiresAt）の
// 暦日差から算出することで、アプリを開かなくても実時間どおりに残日数が減る。
// FoodItem は expiresAt（絶対日付）だけを永続化し、表示のたびにここで計算する。
//
// 暦日差は時刻を無視する（startOfDay 同士の差）。これにより
// 「23:50 に登録 → 翌 00:10 が期限」でも 1 日と数えられる。
// now / calendar を引数で注入できるようにし、テストの決定性を担保する。

import Foundation

enum DateMath {
    /// 今日から expiresAt までの暦日差（時刻は無視。startOfDay 同士の差）。
    /// 期限が過去なら負値を返す。
    static func daysLeft(until expiresAt: Date, from now: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: expiresAt)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 「あと N 日」→ 期限日（now の startOfDay に N 日加算）。
    /// 不変条件: daysLeft(until: expiryDate(daysFromNow: n, from: t), from: t) == n。
    static func expiryDate(daysFromNow days: Int, from now: Date = .now, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }
}
