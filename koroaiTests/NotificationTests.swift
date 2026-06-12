// Step 7（通知）の純関数テスト。
//
// 対象は NotificationPlanner（純関数）。UNUserNotificationCenter は触らない。
// 固定 now（2026-06-10 09:00 Asia/Tokyo）・固定 Calendar で決定的にする。
// 文言は README サンプル / fk-digest.jsx FKLockScreen 準拠（一字一句）。

import Testing
import Foundation
@testable import koroai

@MainActor
struct NotificationPlannerTests {

    // MARK: - 固定環境

    private func cal() -> Calendar { TestSupport.tokyoCalendar() }
    private func now() -> Date { TestSupport.fixedNow(cal()) } // 2026-06-10 09:00 JST

    /// daysLeft が n になる expiresAt を持つ食材を作る。
    private func item(_ name: String, daysLeft n: Int, perishable: Bool = true, catId: String = "fish") -> PlannerItem {
        let expires = DateMath.expiryDate(daysFromNow: n, from: now(), calendar: cal())
        return PlannerItem(id: UUID(), catId: catId, name: name, perishable: perishable, expiresAt: expires)
    }

    /// 指定の年月日時分の Date。
    private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal().date(from: c)!
    }

    private func settings(
        enabled: Bool = true,
        digestHour: Int = 8,
        digestMinute: Int = 0,
        leadDays: Int = 1,
        tone: Tone = .gentle
    ) -> NotificationSettings {
        NotificationSettings(enabled: enabled, digestHour: digestHour, digestMinute: digestMinute, leadDays: leadDays, tone: tone)
    }

    private func itemNotifications(_ planned: [PlannedNotification]) -> [PlannedNotification] {
        planned.filter { $0.id.hasPrefix("item-") }
    }

    private func digestNotifications(_ planned: [PlannedNotification]) -> [PlannedNotification] {
        planned.filter { $0.id.hasPrefix("digest-") }
    }

    // MARK: - 期限前通知の発火日時

    @Test func itemFireDateDaysLeft3Lead1IsTwoDaysBeforeAt1700() {
        // daysLeft 3（期限 6/13）・lead1 → 6/12 17:00。
        let planned = NotificationPlanner.plan(items: [item("刺身", daysLeft: 3)], settings: settings(leadDays: 1), now: now(), calendar: cal())
        let items = itemNotifications(planned)
        #expect(items.count == 1)
        #expect(items.first?.fireDate == at(2026, 6, 12, 17, 0))
    }

    @Test func itemFireDateDaysLeft3Lead0IsExpiryDayAt1700() {
        // daysLeft 3（期限 6/13）・lead0（当日） → 6/13 17:00。
        let planned = NotificationPlanner.plan(items: [item("刺身", daysLeft: 3)], settings: settings(leadDays: 0), now: now(), calendar: cal())
        let items = itemNotifications(planned)
        #expect(items.count == 1)
        #expect(items.first?.fireDate == at(2026, 6, 13, 17, 0))
    }

    @Test func itemDaysLeft0Lead1IsSkippedBecauseFireIsPast() {
        // daysLeft 0（期限 6/10）・lead1 → 発火 6/9 17:00（過去）→ スキップ。
        let planned = NotificationPlanner.plan(items: [item("豆腐", daysLeft: 0)], settings: settings(leadDays: 1), now: now(), calendar: cal())
        #expect(itemNotifications(planned).isEmpty)
    }

    @Test func itemDaysLeft1Lead1IsTonightAt1700AndIncluded() {
        // daysLeft 1（期限 6/11）・lead1 → 発火 6/10 17:00（今日の夕方・now 09:00 より未来）→ 含む。
        let planned = NotificationPlanner.plan(items: [item("納豆", daysLeft: 1)], settings: settings(leadDays: 1), now: now(), calendar: cal())
        let items = itemNotifications(planned)
        #expect(items.count == 1)
        #expect(items.first?.fireDate == at(2026, 6, 10, 17, 0))
    }

    // MARK: - 期限前通知の文言（README サンプル準拠・gentle・一字一句）

    @Test func itemBodyLead1() {
        // 通知時点の残日数 1（= lead1 で daysLeft>=2 のとき）。
        #expect(NotificationPlanner.itemBody(name: "ほうれん草", days: 1)
            == "ほうれん草、あと1日でおいしい食べ頃。今日のごはんに、どうですか？")
    }

    @Test func itemBodyToday() {
        // 通知時点の残日数 0（= 当日 lead0 など）。
        #expect(NotificationPlanner.itemBody(name: "刺身", days: 0)
            == "刺身、今日がおいしい食べ頃。今日のごはんに、どうですか？")
    }

    @Test func itemBodyDaysTwoOrMore() {
        #expect(NotificationPlanner.itemBody(name: "トマト", days: 2)
            == "トマト、あと2日でおいしい食べ頃。")
        #expect(NotificationPlanner.itemBody(name: "トマト", days: 3)
            == "トマト、あと3日でおいしい食べ頃。")
    }

    @Test func itemTitleIsGentleConstant() {
        #expect(NotificationPlanner.itemTitle() == "そろそろ食べ頃")
    }

    /// plan 経由でも本文が正しく組まれる（daysAtFire = leadDays）。
    @Test func itemPlannedBodyMatchesDaysAtFire() {
        // daysLeft 3・lead1 → 発火時の残日数は 1 → 「あと1日…」。
        let p1 = NotificationPlanner.plan(items: [item("豆腐", daysLeft: 3)], settings: settings(leadDays: 1), now: now(), calendar: cal())
        #expect(itemNotifications(p1).first?.body == "豆腐、あと1日でおいしい食べ頃。今日のごはんに、どうですか？")
        #expect(itemNotifications(p1).first?.title == "そろそろ食べ頃")

        // lead0（当日通知）は発火日 = 期限日なので残日数は常に 0 → 「今日が…」。
        let p2 = NotificationPlanner.plan(items: [item("ジャム", daysLeft: 5)], settings: settings(leadDays: 0), now: now(), calendar: cal())
        #expect(itemNotifications(p2).first?.body == "ジャム、今日がおいしい食べ頃。今日のごはんに、どうですか？")

        // daysLeft 5・lead3 → 発火時の残日数は 3 → 「あと3日…」（lead 日数ぶん手前で出る）。
        let p3 = NotificationPlanner.plan(items: [item("ジャム", daysLeft: 5)], settings: settings(leadDays: 3), now: now(), calendar: cal())
        #expect(itemNotifications(p3).first?.body == "ジャム、あと3日でおいしい食べ頃。")
    }

    // MARK: - 朝のまとめ通知

    @Test func digestPlansAtMostSevenDays() {
        // 毎朝 urgent が残るよう、daysLeft 3（soon）の生鮮を1件。
        // 6/10 朝(8:00)は now(9:00) より過去なのでスキップ。
        // 6/11(残2)..以降は soon→tmrw→today と毎朝 urgent → horizon 7日内に収まる。
        let planned = NotificationPlanner.plan(items: [item("刺身", daysLeft: 3)], settings: settings(digestHour: 8), now: now(), calendar: cal())
        let digests = digestNotifications(planned)
        #expect(digests.count <= 7)
        #expect(!digests.isEmpty)
        // 各 id は "digest-YYYYMMDD" 形式。
        for d in digests {
            #expect(d.id.hasPrefix("digest-"))
            #expect(d.id.count == "digest-".count + 8)
        }
    }

    @Test func digestSkipsMorningsWithoutUrgent() {
        // daysLeft 10 の食材だけ → どの朝も hero(<=6) に入らず urgent なし → まとめは0件。
        let planned = NotificationPlanner.plan(items: [item("保存食", daysLeft: 10)], settings: settings(digestHour: 8), now: now(), calendar: cal())
        #expect(digestNotifications(planned).isEmpty)
    }

    @Test func digestFireTimeMatchesDigestHourMinute() {
        // digestHour/Minute が反映され、最初の朝は 6/11（今日の朝は過去）。
        // 毎朝 urgent が残るよう daysLeft 3（6/11 朝に残2=soon）。
        let planned = NotificationPlanner.plan(items: [item("刺身", daysLeft: 3)], settings: settings(digestHour: 7, digestMinute: 30), now: now(), calendar: cal())
        let digests = digestNotifications(planned).sorted { $0.fireDate < $1.fireDate }
        #expect(digests.first?.fireDate == at(2026, 6, 11, 7, 30))
        // すべて 7:30 発火。
        for d in digests {
            let c = cal().dateComponents([.hour, .minute], from: d.fireDate)
            #expect(c.hour == 7 && c.minute == 30)
        }
    }

    @Test func digestTitleGentleIsLeadOnly() {
        // 6/11 の朝: daysLeft 6 の食材は 6/11 時点で残5 → soon ではないので urgent でない…
        // urgent を確実にするため、6/11 朝に「あと2日（soon）」になる食材を置く（期限 6/13）。
        let planned = NotificationPlanner.plan(items: [item("刺身", daysLeft: 3)], settings: settings(digestHour: 8, tone: .gentle), now: now(), calendar: cal())
        let digests = digestNotifications(planned).sorted { $0.fireDate < $1.fireDate }
        let first = digests.first
        // 6/11 朝、期限 6/13 → 残2日 → soon。lead = 「近いうちに食べたいものが 1品」。
        // タイトルは全トーン lead のみ（ユーザー決定 2026-06-12。挨拶前置はロック画面で見切れるため廃止）。
        #expect(first?.fireDate == at(2026, 6, 11, 8, 0))
        #expect(first?.title == "近いうちに食べたいものが 1品")
    }

    @Test func digestTitleSimpleIsLeadOnly() {
        let planned = NotificationPlanner.plan(items: [item("刺身", daysLeft: 3)], settings: settings(digestHour: 8, tone: .simple), now: now(), calendar: cal())
        let first = digestNotifications(planned).sorted { $0.fireDate < $1.fireDate }.first
        // simple も lead のみ（simple の soon lead は "近いうちに食べたいものが 1品"）。
        #expect(first?.title == "近いうちに食べたいものが 1品")
    }

    @Test func digestBodyUsesNudgeWhenSingleTodayElseSub() {
        // today が1件 → nudge を body に使う。6/11 朝に「今日（残0）」になる食材 = 期限 6/11。
        let planned = NotificationPlanner.plan(items: [item("豆腐", daysLeft: 1)], settings: settings(digestHour: 8, tone: .gentle), now: now(), calendar: cal())
        let first = digestNotifications(planned).sorted { $0.fireDate < $1.fireDate }.first
        // 6/11 朝、期限 6/11 → 残0 → today 1件 → body は nudge。
        #expect(first?.fireDate == at(2026, 6, 11, 8, 0))
        #expect(first?.body == "豆腐、今日のうちに使い切れます")
    }

    @Test func digestBodyUsesSubWhenMultipleToday() {
        // today が2件 → nudge を使わず sub（名前の連結）。期限 6/11 の食材を2件。
        // 同 days のソート順は安定保証されないため、両名が含まれることで検証する。
        let planned = NotificationPlanner.plan(
            items: [item("豆腐", daysLeft: 1), item("納豆", daysLeft: 1)],
            settings: settings(digestHour: 8, tone: .gentle), now: now(), calendar: cal()
        )
        let body = digestNotifications(planned).sorted { $0.fireDate < $1.fireDate }.first?.body
        #expect(body?.contains("豆腐") == true)
        #expect(body?.contains("納豆") == true)
        #expect(body?.contains("・") == true)
        // 単一 today の nudge 文言（「使い切れます」）ではないこと。
        #expect(body?.contains("使い切れます") == false)
    }

    // MARK: - 全体の挙動

    @Test func disabledYieldsEmptyPlan() {
        let planned = NotificationPlanner.plan(
            items: [item("刺身", daysLeft: 1), item("豆腐", daysLeft: 3)],
            settings: settings(enabled: false), now: now(), calendar: cal()
        )
        #expect(planned.isEmpty)
    }

    @Test func planIsSortedByFireDateAscending() {
        let planned = NotificationPlanner.plan(
            items: [item("a", daysLeft: 5), item("b", daysLeft: 1), item("c", daysLeft: 3)],
            settings: settings(digestHour: 8, leadDays: 1), now: now(), calendar: cal()
        )
        let dates = planned.map(\.fireDate)
        #expect(dates == dates.sorted())
        #expect(!planned.isEmpty)
    }

    @Test func emptyInventoryYieldsEmptyPlan() {
        let planned = NotificationPlanner.plan(items: [PlannerItem](), settings: settings(), now: now(), calendar: cal())
        #expect(planned.isEmpty)
    }
}

// MARK: - AppStore 新キー（既定値・永続化）

@MainActor
struct AppStoreNotificationSettingsTests {

    /// テスト用に独立した UserDefaults suite を作る。
    private func freshDefaults() -> UserDefaults {
        let name = "test.koroai.notif.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsAreNotificationDefaults() {
        let store = AppStore(defaults: freshDefaults())
        #expect(store.notificationsEnabled == true)
        #expect(store.digestHour == 8)
        #expect(store.digestMinute == 0)
        #expect(store.leadDays == 1)
        #expect(store.showMonthlyResult == true)
    }

    @Test func valuesPersistAcrossReinit() {
        let defaults = freshDefaults()
        do {
            let store = AppStore(defaults: defaults)
            store.notificationsEnabled = false
            store.digestHour = 7
            store.digestMinute = 30
            store.leadDays = 2
            store.showMonthlyResult = false
        }
        // 同じ defaults で作り直すと永続値が読み込まれる。
        let reloaded = AppStore(defaults: defaults)
        #expect(reloaded.notificationsEnabled == false)
        #expect(reloaded.digestHour == 7)
        #expect(reloaded.digestMinute == 30)
        #expect(reloaded.leadDays == 2)
        #expect(reloaded.showMonthlyResult == false)
    }

    @Test func settingsStructMapsFromStore() {
        let defaults = freshDefaults()
        let store = AppStore(defaults: defaults)
        store.digestHour = 9
        store.leadDays = 3
        store.tone = .cheer
        let s = NotificationSettings(store: store)
        #expect(s.enabled == true)
        #expect(s.digestHour == 9)
        #expect(s.leadDays == 3)
        #expect(s.tone == .cheer)
    }
}
