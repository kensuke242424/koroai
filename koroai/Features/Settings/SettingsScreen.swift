// 設定（全画面オーバーレイ）。プロトタイプ fk-settings.jsx の移植。
//
// 流儀は ReviewScreen と同じ（bg ベタ・戻るチェブロン・ZStack 最上位に重ねる）。
// セクション: 通知 / 表示 / ふりかえり / データ / サポート。文言はプロトタイプから一字一句転記。
// 絵文字不使用・SF Symbols（bell / clock / calendar / moon / leaf.fill / trash / info.circle /
//   envelope / questionmark.circle / chevron）。
//
// 設計（Step 7 確定判断）:
//  - 表示するのはテーマ3択のみ（パレット・トーンの UI は出さない＝プロトタイプ準拠）。
//  - テーマ変更はアプリ全体へ即時反映（AppStore.themeMode 直結）。
//  - 通知トグル/時刻/タイミングは AppStore に書き、変更のたびに再スケジュールする。
//  - リセットは FoodItem と ConsumptionLog を全件削除＋トースト＋設定を閉じる。

import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Binding var isPresented: Bool

    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.modelContext) private var context

    @Query private var items: [FoodItem]

    /// 朝のまとめ時刻のインライン DatePicker を開いているか。
    @State private var digestTimeExpanded = false
    /// リセット確認オーバーレイ。
    @State private var confirmReset = false

    /// アプリのバージョン（CFBundleShortVersionString）。
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        notificationSection
                        displaySection
                        reviewSection
                        dataSection
                        supportSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
            }

            if confirmReset {
                resetConfirm
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: confirmReset)
    }

    // MARK: - トップバー

    private var topBar: some View {
        HStack(spacing: 4) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tokens.text)
                    .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Text("設定")
                .font(AppFont.rounded(size: 17, weight: .heavy))
                .foregroundStyle(tokens.text)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.bottom, 8)
    }

    // MARK: - 通知

    @ViewBuilder
    private var notificationSection: some View {
        @Bindable var store = store
        sectionHeader("通知")
        SettingsCard {
            SettingsToggleRow(
                icon: "bell",
                label: "プッシュ通知",
                sub: "期限が近づいたらお知らせ",
                isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { on in
                        store.notificationsEnabled = on
                        // OFF で全停止、ON で再スケジュール。
                        if on {
                            reschedule()
                        } else {
                            NotificationService.shared.disableAll()
                        }
                    }
                )
            )

            // 朝のまとめ通知（タップで時刻 DatePicker を行下に展開）。
            VStack(spacing: 0) {
                SettingsTapRow(
                    icon: "clock",
                    label: "朝のまとめ通知",
                    sub: "毎朝 \(timeLabel(hour: store.digestHour, minute: store.digestMinute))",
                    rightText: timeLabel(hour: store.digestHour, minute: store.digestMinute),
                    showChevron: false
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { digestTimeExpanded.toggle() }
                }
                if digestTimeExpanded {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { digestDate(hour: store.digestHour, minute: store.digestMinute) },
                            set: { newDate in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                store.digestHour = c.hour ?? 8
                                store.digestMinute = c.minute ?? 0
                                reschedule()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 140)
                    .padding(.bottom, 6)
                }
            }

            // 通知のタイミング（Menu で当日/1/2/3日前）。
            SettingsMenuRow(
                icon: "calendar",
                label: "通知のタイミング",
                sub: "期限の何日前に知らせるか",
                rightText: leadLabel(store.leadDays),
                isLast: true
            ) {
                ForEach([0, 1, 2, 3], id: \.self) { d in
                    Button {
                        store.leadDays = d
                        reschedule()
                    } label: {
                        if store.leadDays == d {
                            Label(leadLabel(d), systemImage: "checkmark")
                        } else {
                            Text(leadLabel(d))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 表示

    @ViewBuilder
    private var displaySection: some View {
        @Bindable var store = store
        sectionHeader("表示")
        SettingsCard {
            ThemeSegmentRow(selection: $store.themeMode)
        }
    }

    // MARK: - ふりかえり

    @ViewBuilder
    private var reviewSection: some View {
        @Bindable var store = store
        sectionHeader("ふりかえり")
        SettingsCard {
            SettingsToggleRow(
                icon: "leaf.fill",
                label: "食べきり記録を表示",
                sub: "ホームに達成カードを出す",
                isOn: $store.showAchievementCard
            )
            SettingsToggleRow(
                icon: nil,
                label: "月替わりリザルトを表示",
                sub: "月初に先月の結果をポップアップ",
                isOn: $store.showMonthlyResult,
                isLast: true
            )
        }
    }

    // MARK: - データ

    private var dataSection: some View {
        Group {
            sectionHeader("データ")
            SettingsCard {
                SettingsTapRow(
                    icon: "trash",
                    label: "冷蔵庫をリセット",
                    sub: "すべての食材と記録を消去",
                    danger: true,
                    isLast: true
                ) {
                    confirmReset = true
                }
            }
        }
    }

    // MARK: - サポート

    private var supportSection: some View {
        Group {
            sectionHeader("サポート")
            SettingsCard {
                SettingsTapRow(
                    icon: "questionmark.circle",
                    label: "使い方ガイド",
                    sub: "オンボーディングをもう一度"
                ) {
                    // TODO(Step 8): オンボーディング再生。
                    toast.show(.toss, "準備中です")
                }
                SettingsTapRow(
                    icon: "envelope",
                    label: "フィードバックを送る"
                ) {
                    // TODO(Step 8): フィードバック導線（mailto など）。
                    toast.show(.toss, "準備中です")
                }
                // 情報行（タップ不可）。
                SettingsInfoRow(
                    icon: "info.circle",
                    label: "このアプリについて",
                    sub: "ころあい v\(version)",
                    isLast: true
                )
            }
        }
    }

    // MARK: - フッター

    private var footer: some View {
        Text("ころあい v\(version)\n食品ロスを、やさしく減らす")
            .font(AppFont.rounded(size: 12, weight: .bold))
            .foregroundStyle(tokens.textTer)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
    }

    // MARK: - リセット確認

    private var resetConfirm: some View {
        ZStack {
            // スクリム rgba(20,14,6,0.42)。
            Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.42)
                .ignoresSafeArea()
                .onTapGesture { confirmReset = false }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(mixWithTransparent(tokens.accent, fractionOfFirst: 0.16))
                        .frame(width: 56, height: 56)
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(tokens.accent)
                }
                .padding(.bottom, 16)

                Text("本当にリセットしますか？")
                    .font(AppFont.rounded(size: 18, weight: .heavy))
                    .foregroundStyle(tokens.text)

                Text("すべての食材と食べきり記録が消去されます。この操作は取り消せません。")
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(tokens.textSec)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                VStack(spacing: 9) {
                    Button {
                        performReset()
                    } label: {
                        Text("リセットする")
                            .font(AppFont.rounded(size: 15.5, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(tokens.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        confirmReset = false
                    } label: {
                        Text("やめる")
                            .font(AppFont.rounded(size: 14.5, weight: .bold))
                            .foregroundStyle(tokens.textSec)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 26)
            .padding(.bottom, 22)
            .frame(maxWidth: 300)
            .background(tokens.bg2, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.4),
                    radius: 25, x: 0, y: 18)
            .padding(.horizontal, 26)
        }
    }

    // MARK: - 共通レイアウト

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.rounded(size: 13, weight: .heavy))
            .foregroundStyle(tokens.textTer)
            .tracking(0.6)
            .padding(.leading, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    // MARK: - アクション

    /// FoodItem と ConsumptionLog を全件削除し、トーストを出して設定を閉じる。
    private func performReset() {
        for item in (try? context.fetch(FetchDescriptor<FoodItem>())) ?? [] {
            context.delete(item)
        }
        for log in (try? context.fetch(FetchDescriptor<ConsumptionLog>())) ?? [] {
            context.delete(log)
        }
        try? context.save()
        // 在庫が空になったので通知も再スケジュール（= 全消し）。
        reschedule()
        confirmReset = false
        isPresented = false
        // 出典: fk-app.jsx onReset。
        toast.show(.toss, "リセットしました。ゆっくり始めましょう")
    }

    /// 現在の在庫＋設定で通知を再スケジュールする。
    private func reschedule() {
        let snapshot = items
        Task { await NotificationService.shared.rescheduleAll(items: snapshot, store: store) }
    }

    // MARK: - ラベル

    /// 「H:mm」（プロトタイプの「8:00」表記に合わせて時はゼロ詰めしない）。
    private func timeLabel(hour: Int, minute: Int) -> String {
        String(format: "%d:%02d", hour, minute)
    }

    private func leadLabel(_ days: Int) -> String {
        days == 0 ? "当日" : "\(days)日前"
    }

    /// digestHour/Minute を今日の Date に組み立て（DatePicker のバインド用）。
    private func digestDate(hour: Int, minute: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        c.hour = hour
        c.minute = minute
        return Calendar.current.date(from: c) ?? .now
    }
}

// MARK: - カード

/// 行をまとめる surface 角丸18 カード。最終行の下線が出ないよう最後の hairline は親で隠す。
private struct SettingsCard<Content: View>: View {
    @Environment(\.tokens) private var tokens
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        // 最終行の hairline を隠すためのマスク（角丸内でクリップ）。
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - アイコンチップ

/// 行頭の 34pt 角丸10 アイコンチップ。danger は accent 16% 塗り＋accent グリフ。
private struct SettingsIconChip: View {
    let systemName: String
    var danger: Bool = false
    @Environment(\.tokens) private var tokens

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(danger ? tokens.accent : tokens.textSec)
            .frame(width: 34, height: 34)
            .background(
                danger ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.16) : tokens.surface2,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }
}

// MARK: - 行ラベル本文

private struct SettingsRowLabel: View {
    let label: String
    var sub: String?
    var danger: Bool = false
    @Environment(\.tokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(AppFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(danger ? tokens.accent : tokens.text)
            if let sub {
                Text(sub)
                    .font(AppFont.rounded(size: 12.5, weight: .semibold))
                    .foregroundStyle(tokens.textTer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - hairline 区切り

private struct SettingsHairline: View {
    @Environment(\.tokens) private var tokens
    var body: some View {
        Rectangle().fill(tokens.hair).frame(height: 1)
    }
}

// MARK: - トグル行

private struct SettingsToggleRow: View {
    let icon: String?
    let label: String
    var sub: String?
    @Binding var isOn: Bool
    var isLast: Bool = false
    @Environment(\.tokens) private var tokens

    var body: some View {
        HStack(spacing: 13) {
            if let icon { SettingsIconChip(systemName: icon) }
            SettingsRowLabel(label: label, sub: sub)
            BrandToggle(isOn: $isOn)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { if !isLast { SettingsHairline() } }
    }
}

// MARK: - brand 塗りトグル（50×30）

/// プロトタイプ FKSettingsToggle 準拠の自作トグル（brand 塗り・26pt つまみ）。
private struct BrandToggle: View {
    @Binding var isOn: Bool
    @Environment(\.tokens) private var tokens

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? tokens.brand : tokens.surface2)
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel(Text(isOn ? "オン" : "オフ"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - タップ行（右にテキスト＋任意の chevron）

private struct SettingsTapRow: View {
    let icon: String?
    let label: String
    var sub: String?
    var rightText: String?
    var danger: Bool = false
    var showChevron: Bool = true
    var isLast: Bool = false
    let action: () -> Void
    @Environment(\.tokens) private var tokens

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                if let icon { SettingsIconChip(systemName: icon, danger: danger) }
                SettingsRowLabel(label: label, sub: sub, danger: danger)
                if let rightText {
                    Text(rightText)
                        .font(AppFont.rounded(size: 13, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tokens.textTer)
                        .opacity(0.4)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { if !isLast { SettingsHairline() } }
    }
}

// MARK: - Menu 行（右にテキスト＋chevron、タップで Menu 展開）

private struct SettingsMenuRow<MenuContent: View>: View {
    let icon: String?
    let label: String
    var sub: String?
    let rightText: String
    var isLast: Bool = false
    @ViewBuilder var menuContent: () -> MenuContent
    @Environment(\.tokens) private var tokens

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 13) {
                if let icon { SettingsIconChip(systemName: icon) }
                SettingsRowLabel(label: label, sub: sub)
                Text(rightText)
                    .font(AppFont.rounded(size: 13, weight: .bold))
                    .foregroundStyle(tokens.textSec)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tokens.textTer)
                    .opacity(0.4)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { if !isLast { SettingsHairline() } }
    }
}

// MARK: - 情報行（タップ不可）

private struct SettingsInfoRow: View {
    let icon: String?
    let label: String
    var sub: String?
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: 13) {
            if let icon { SettingsIconChip(systemName: icon) }
            SettingsRowLabel(label: label, sub: sub)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { if !isLast { SettingsHairline() } }
    }
}

// MARK: - テーマセグメント行

/// 「テーマ」セグメント（OS設定/ライト/ナイト）。surface2 トレイ・選択は surface 塗り＋影。
private struct ThemeSegmentRow: View {
    @Binding var selection: ThemeMode
    @Environment(\.tokens) private var tokens

    var body: some View {
        HStack(spacing: 13) {
            SettingsIconChip(systemName: "moon")
            Text("テーマ")
                .font(AppFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(tokens.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(ThemeMode.allCases) { mode in
                    let on = selection == mode
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selection = mode }
                    } label: {
                        Text(mode.displayName)
                            .font(AppFont.rounded(size: 12, weight: .heavy))
                            .foregroundStyle(on ? tokens.text : tokens.textTer)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 11)
                            .background {
                                if on {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(tokens.surface)
                                        .shadow(color: Shadows.card.color, radius: 3, x: 0, y: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(tokens.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 14)
        // テーマは「表示」カードで唯一の行なので下線なし。
    }
}
