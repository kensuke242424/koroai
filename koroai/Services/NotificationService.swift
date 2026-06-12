// ローカル通知の登録サービス。NotificationPlanner の計画を UNNotificationRequest 化して登録するだけ。
//
// 設計（CLAUDE.md / Step 7 の確定判断）:
//  - ローカル通知のみ（UserNotifications）。サーバープッシュは使わない。
//  - 権限は遅延要求: 初めて実スケジュールを試みるときに requestAuthorization(.alert/.sound/.badge)。
//    拒否されたら以後 no-op（クラッシュ・エラー UI なし）。
//  - notificationsEnabled（AppStore）OFF のときは plan が空配列を返すので、全 pending を消すだけになる。
//  - 再スケジュール契機は koroaiApp 側（scenePhase の active→非active と起動時）が握る。
//
// テストはプランナー（NotificationPlanner）に当てる。UNUserNotificationCenter はテストしない。

import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// 在庫＋設定から計画を立て、全 pending を入れ替える。
    /// 権限が未確定なら遅延要求し、拒否済みなら何もしない（pending の掃除のみ）。
    func rescheduleAll(items: [FoodItem], store: AppStore) async {
        let settings = NotificationSettings(store: store)
        let planned = NotificationPlanner.plan(items: items, settings: settings)

        // 権限の確認・要求。許可されていなければ pending を掃除して終わり。
        guard await ensureAuthorized() else {
            center.removeAllPendingNotificationRequests()
            return
        }

        // 既存の pending を入れ替える（plan が空なら全消し）。
        center.removeAllPendingNotificationRequests()
        for p in planned {
            register(p)
        }
        #if DEBUG
        // 実発火検証・診断用（DEBUG のみ）。登録件数と直近の発火予定を残す。
        NSLog("[Notify] scheduled %d notifications; first=%@",
              planned.count,
              planned.first.map { "\($0.id) @ \($0.fireDate)" } ?? "none")
        #endif
    }

    /// うちのスケジューリングを全停止する（pending を全消し）。
    /// notificationsEnabled を false にしたときなどに使う。
    func disableAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - 権限（遅延要求）

    /// 通知許可を確認し、未確定なら要求する。許可されていれば true。
    private func ensureAuthorized() async -> Bool {
        #if DEBUG
        // スクショ時は権限ダイアログが UI に被るので、どの経路から来ても要求しない（本番挙動には影響なし）。
        if CommandLine.arguments.contains("-noNotifyPrompt") { return false }
        #endif
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            // 初回の実スケジュール時にだけダイアログを出す。
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted
        @unknown default:
            return false
        }
    }

    // MARK: - 登録

    private func register(_ p: PlannedNotification) {
        let content = UNMutableNotificationContent()
        content.title = p.title
        content.body = p.body
        content.sound = .default

        // 絶対日時で1回だけ発火する暦トリガ。
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: p.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: p.id, content: content, trigger: trigger)
        center.add(request) { _ in }
    }
}
