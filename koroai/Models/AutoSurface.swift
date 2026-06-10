// 起動時に自動表示する画面の判定（純関数・テスト可能）。
//
// 確定済みの設計判断（Step 8・判断2）の優先順:
//  (a) onboarded == false                          → オンボーディング
//  (b) awayDays >= 5（lastOpenedAt との暦日差）       → 復帰画面
//  (c) 月替わりリザルト（MonthResultTrigger）         → リザルト
//  (b) が出た場合 (c) は復帰フロー解決後に再評価する（ここでは「復帰」を返すだけ）。
//
// awayDays は lastOpenedAt が nil なら 0 扱い（＝復帰画面は出さない）。

import Foundation

/// 起動時に最初に出すべき自動表示。
enum AutoSurfaceDecision: Equatable {
    case onboarding
    case returning(daysAway: Int)
    case monthResult(MonthResultData)
    case none
}

enum AutoSurface {

    /// 久しぶり起動とみなす最小日数。出典: fk-app.jsx awayDays >= 5。
    static let awayThreshold = 5

    /// lastOpenedAt と now の暦日差（lastOpenedAt が nil なら 0）。
    static func awayDays(lastOpenedAt: Date?, now: Date, calendar: Calendar) -> Int {
        guard let last = lastOpenedAt else { return 0 }
        let start = calendar.startOfDay(for: last)
        let end = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// 起動時に最初に出す画面を判定する。
    static func decide(
        onboarded: Bool,
        lastOpenedAt: Date?,
        logs: [ConsumptionLog],
        monthResultShownFor: String?,
        monthlyResultEnabled: Bool,
        now: Date,
        calendar: Calendar
    ) -> AutoSurfaceDecision {
        // (a) 未オンボーディング。
        if !onboarded { return .onboarding }

        // (b) 久しぶり起動。
        let away = awayDays(lastOpenedAt: lastOpenedAt, now: now, calendar: calendar)
        if away >= awayThreshold { return .returning(daysAway: away) }

        // (c) 月替わりリザルト。
        if let data = MonthResultTrigger.evaluate(
            lastOpenedAt: lastOpenedAt,
            logs: logs,
            shownFor: monthResultShownFor,
            enabled: monthlyResultEnabled,
            now: now,
            calendar: calendar
        ) {
            return .monthResult(data)
        }

        return .none
    }
}
