// ローカル通知の計画（純関数）。在庫と設定から「いつ・なんの通知を出すか」を値型で算出する。
//
// 設計（CLAUDE.md / Step 7 の確定判断）:
//  - サーバープッシュは使わない。ここは計画を作るだけ。UNNotificationRequest 化と登録は
//    NotificationService（Services/）の責務。テストはこのプランナーに当てる。
//  - 計画は2系統:
//    1) 朝のまとめ（digest）: 設定時刻に先7日分を事前計算。各朝のスナップショット
//       （その朝時点の daysLeft）で DigestBuilder を回し、急ぎ（urgent）が無い朝はスキップ。
//    2) 期限前（item）: (expiresAt − leadDays) の夕方 17:00 に1件ずつ。過去の発火はスキップ。
//  - now/calendar は注入可能（テストの決定性）。enabled=false なら空配列。出力は fireDate 昇順。
//
// 文言は fk-digest.jsx（FKLockScreen）/ README サンプルから一字一句。

import Foundation

/// 登録予定の通知1件（値型・テスト容易）。
struct PlannedNotification: Equatable {
    /// 通知 id。朝のまとめ = "digest-YYYYMMDD" / 期限前 = "item-{uuid}"。
    let id: String
    /// 発火日時（ローカル）。
    let fireDate: Date
    let title: String
    let body: String
}

/// プランナーへの入力設定（AppStore 非依存に保つための軽量 struct）。
struct NotificationSettings: Equatable {
    /// うちのスケジューリングの ON/OFF。false なら計画は空。
    let enabled: Bool
    /// 朝のまとめ通知の発火時刻（時・分）。
    let digestHour: Int
    let digestMinute: Int
    /// 期限の何日前に期限前通知を出すか（0=当日）。
    let leadDays: Int
    /// コピーのトーン。
    let tone: Tone
}

/// プランナーが扱う食材1件（FoodItem からの写し）。
struct PlannerItem: Equatable {
    let id: UUID
    let catId: String
    let name: String
    let perishable: Bool
    let expiresAt: Date
}

enum NotificationPlanner {

    /// 期限前通知の発火時刻（夕方）。夕食準備の文脈に合わせて 17:00 固定。
    static let itemNotificationHour = 17
    static let itemNotificationMinute = 0

    /// 朝のまとめを事前計算する日数（今日を含めて先7日分）。
    static let digestHorizonDays = 7

    /// 在庫＋設定から通知計画を立てる純関数。
    /// - Parameters:
    ///   - items: 在庫（FoodItem からの写し）。
    ///   - settings: 通知設定。
    ///   - now: 計画を立てる基準時刻。
    ///   - calendar: 暦計算に使う Calendar。
    /// - Returns: fireDate 昇順の計画配列。enabled=false なら空。
    static func plan(
        items: [PlannerItem],
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard settings.enabled else { return [] }

        var planned: [PlannedNotification] = []
        planned.append(contentsOf: planItemNotifications(items: items, settings: settings, now: now, calendar: calendar))
        planned.append(contentsOf: planDigestNotifications(items: items, settings: settings, now: now, calendar: calendar))

        // fireDate 昇順（同時刻は id で安定化）。
        return planned.sorted {
            if $0.fireDate == $1.fireDate { return $0.id < $1.id }
            return $0.fireDate < $1.fireDate
        }
    }

    // MARK: - 期限前通知

    private static func planItemNotifications(
        items: [PlannerItem],
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        items.compactMap { item -> PlannedNotification? in
            // 発火日 = 期限日の startOfDay から leadDays 引いた日。その日の 17:00 に出す。
            let expiryDay = calendar.startOfDay(for: item.expiresAt)
            guard let fireDay = calendar.date(byAdding: .day, value: -settings.leadDays, to: expiryDay) else { return nil }
            var comps = calendar.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = itemNotificationHour
            comps.minute = itemNotificationMinute
            guard let fireDate = calendar.date(from: comps) else { return nil }
            // 過去の発火時刻はスキップ（now ちょうど以前は出さない）。
            guard fireDate > now else { return nil }

            // 通知時点の残日数（= 発火日と期限日の暦日差）で文言を出し分ける。
            let daysAtFire = calendar.dateComponents([.day], from: fireDay, to: expiryDay).day ?? 0
            return PlannedNotification(
                id: "item-\(item.id.uuidString)",
                fireDate: fireDate,
                title: itemTitle(),
                body: itemBody(name: item.name, days: daysAtFire)
            )
        }
    }

    /// 期限前通知のタイトル。出典: README「例外・空状態」やさしいお知らせ。
    static func itemTitle() -> String { "そろそろ食べ頃" }

    /// 期限前通知の本文。出典: README サンプル（gentle）。
    /// - days: 通知が出る時点での残日数（0=当日 / 1=あと1日 / N>=2=あとN日）。
    static func itemBody(name: String, days: Int) -> String {
        if days <= 0 {
            return "\(name)、今日がおいしい食べ頃。今日のごはんに、どうですか？"
        }
        if days == 1 {
            return "\(name)、あと1日でおいしい食べ頃。今日のごはんに、どうですか？"
        }
        return "\(name)、あと\(days)日でおいしい食べ頃。"
    }

    // MARK: - 朝のまとめ通知

    private static func planDigestNotifications(
        items: [PlannerItem],
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        let today = calendar.startOfDay(for: now)
        var result: [PlannedNotification] = []

        for dayOffset in 0..<digestHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            // その朝の発火時刻。
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = settings.digestHour
            comps.minute = settings.digestMinute
            guard let fireDate = calendar.date(from: comps) else { continue }
            // 過去（now 以前）の朝はスキップ。
            guard fireDate > now else { continue }

            // その朝時点の daysLeft でまとめを導出。
            let digestItems = items.map { item in
                DigestItem(
                    id: item.id,
                    catId: item.catId,
                    name: item.name,
                    perishable: item.perishable,
                    days: DateMath.daysLeft(until: item.expiresAt, from: fireDate, calendar: calendar)
                )
            }
            let dg = DigestBuilder.build(items: digestItems, tone: settings.tone)

            // 急ぎが無い朝はスキップ（README「通知も急かさない」）。
            guard !dg.urgent.isEmpty else { continue }

            result.append(PlannedNotification(
                id: digestId(for: day, calendar: calendar),
                fireDate: fireDate,
                title: digestTitle(lead: dg.lead, tone: settings.tone),
                body: digestBody(result: dg)
            ))
        }
        return result
    }

    /// 朝のまとめ通知の id（"digest-YYYYMMDD"）。
    static func digestId(for day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "digest-%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// まとめ通知のタイトル。全トーン lead のみ（ユーザー決定 2026-06-12）。
    /// ロック画面のタイトルは全角18字程度で切れるため、「おはようございます。」を前置すると
    /// 肝心の情報（今日/あす・品数）が見切れる。挨拶はアプリ内のまとめ画面にだけ残す。
    /// （fk-digest.jsx FKLockScreen の「おはようございます。{lead}」から通知のみ変更）
    static func digestTitle(lead: String, tone: Tone) -> String {
        lead
    }

    /// まとめ通知の本文。出典: fk-digest.jsx FKLockScreen 本文。
    /// today が1件かつ nudge あり → nudge、なければ sub。
    static func digestBody(result dg: DigestResult) -> String {
        if dg.today.count == 1, let nudge = dg.nudge {
            return nudge
        }
        return dg.sub
    }

    // MARK: - FoodItem からの便宜オーバーロード

    /// FoodItem 配列から計画を立てる便宜版。
    static func plan(
        items: [FoodItem],
        settings: NotificationSettings,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        let mapped = items.map {
            PlannerItem(id: $0.id, catId: $0.catId, name: $0.name, perishable: $0.perishable, expiresAt: $0.expiresAt)
        }
        return plan(items: mapped, settings: settings, now: now, calendar: calendar)
    }
}

extension NotificationSettings {
    /// AppStore から設定を写す（プランナーを AppStore 非依存に保つための変換）。
    @MainActor
    init(store: AppStore) {
        self.init(
            enabled: store.notificationsEnabled,
            digestHour: store.digestHour,
            digestMinute: store.digestMinute,
            leadDays: store.leadDays,
            tone: store.tone
        )
    }
}
