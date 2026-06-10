// 編集シート（ホームのカード/行タップで開く）。プロトタイプ fk-flows.jsx FKEditSheet の移植。
//
// native .sheet は使わず SheetContainer（height auto・maxHeight 88%・スクロール可）内に組む。
// 構成: キャプション → カテゴリアイコン+名前 → 今日行 → もち日数カード → カレンダートグル/ピッカー →
//   残量セクション(edit) → クイックアクション行（食べた / そっと処分）→ 保存 → キャンセル/登録を取り消す。
//
// 「食べた / そっと処分」は HomeView の既存 ate/toss を closure で受け、ConsumptionLog 記録＋削除＋トーストは
// 呼び出し側に委ねる。「登録を取り消す」はログを残さず削除（誤登録用）。

import SwiftUI
import SwiftData

struct EditSheet: View {
    @Binding var isPresented: Bool
    /// 編集対象。nil なら空シート（プロトタイプの !item フォールバック相当）。
    var item: FoodItem?
    /// 「食べた」: HomeView の ate()。ConsumptionLog 記録＋削除＋トーストは呼び出し側。
    var onAte: (FoodItem) -> Void
    /// 「そっと処分」: HomeView の toss()。
    var onToss: (FoodItem) -> Void

    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.modelContext) private var context

    @State private var model = EditSheetModel()

    private static let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        SheetContainer(
            isPresented: $isPresented,
            heightFraction: nil,
            onDismissRequest: { isPresented = false }
        ) {
            if item != nil {
                ScrollView {
                    formBody
                }
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented, let item {
                model.begin(item: item, store: store)
            }
        }
        #if DEBUG
        .onAppear {
            if isPresented, let item {
                model.begin(item: item, store: store)
            }
        }
        #endif
    }

    // MARK: - フォーム本体

    @ViewBuilder
    private var formBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("アイテムを編集")
                .font(AppFont.rounded(size: 13, weight: .heavy))
                .foregroundStyle(tokens.textTer)
                .padding(.bottom, 14)

            categoryRow
            todayRow
            daysCard
            CalendarToggle(isOpen: $model.calendarOpen)
                .padding(.bottom, 12)
            if model.calendarOpen {
                CalendarPicker(days: $model.days)
                    .padding(.bottom, 12)
            }
            AmountSection(
                mode: $model.amountMode,
                frac: $model.amount,
                count: $model.quantity,
                unit: model.unit,
                context: .edit,
                total: model.quantityTotal
            )
            .padding(.bottom, 12)

            quickActions
                .padding(.bottom, 12)
            saveButton
            cancelButton
            removeButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 26)
    }

    // カテゴリアイコン＋名前
    private var categoryRow: some View {
        HStack(spacing: 15) {
            if let cat = model.category {
                CategoryIcon(category: cat, size: 64)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(model.category?.name ?? "")
                    .font(AppFont.rounded(size: 13, weight: .bold))
                    .foregroundStyle(tokens.textTer)
                TextField("", text: $model.name, prompt: namePrompt)
                    .font(AppFont.rounded(size: 21, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .textInputAutocapitalization(.never)
                Rectangle()
                    .fill(tokens.hair)
                    .frame(height: 2)
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
        }
        .padding(.bottom, 20)
    }

    /// プロトタイプ FKEditSheet は placeholder = cat.name。
    private var namePrompt: Text {
        Text(model.category?.name ?? "")
            .font(AppFont.rounded(size: 21, weight: .heavy))
            .foregroundColor(tokens.textTer)
    }

    // 「今日 M/D（曜）」行
    private var todayRow: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tokens.accent)
                .frame(width: 7, height: 7)
            Text("今日 \(todayString)")
                .font(AppFont.rounded(size: 15, weight: .heavy))
                .foregroundStyle(tokens.text)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 8)
    }

    private var todayString: String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .day, .weekday], from: .now)
        let wd = Self.weekdayLabels[(comps.weekday ?? 1) - 1]
        return "\(comps.month ?? 0)/\(comps.day ?? 0)（\(wd)）"
    }

    // もち日数カード（サブ文言は「残りを調整」）
    private var daysCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("もち日数")
                    .font(AppFont.rounded(size: 15.5, weight: .bold))
                    .foregroundStyle(tokens.text)
                Text("残りを調整")
                    .font(AppFont.rounded(size: 12.5, weight: .semibold))
                    .foregroundStyle(tokens.textTer)
            }
            Spacer()
            DaysStepper(days: $model.days)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 10)
    }

    // MARK: - クイックアクション行（食べた / そっと処分）

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                guard let item else { return }
                onAte(item)
                isPresented = false
            } label: {
                quickLabel(
                    systemImage: "checkmark.circle.fill",
                    title: "食べた",
                    foreground: tokens.accent
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("食べた")

            Button {
                guard let item else { return }
                onToss(item)
                isPresented = false
            } label: {
                quickLabel(
                    systemImage: "trash",
                    title: "そっと処分",
                    foreground: tokens.textSec
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("そっと処分")
        }
    }

    private func quickLabel(systemImage: String, title: String, foreground: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(AppFont.rounded(size: 15, weight: .heavy))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.vertical, 6)
        .background(
            ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.06),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button {
            guard let item else { return }
            model.save(item: item, context: context)
            toast.show(.ate, "更新しました")
            isPresented = false
        } label: {
            Text("保存")
                .font(AppFont.rounded(size: 16.5, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }

    // MARK: - キャンセル / 登録を取り消す

    private var cancelButton: some View {
        Button {
            isPresented = false
        } label: {
            Text("キャンセル")
                .font(AppFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(tokens.textSec)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    /// 誤登録用。ログを残さず item を削除する（ConsumptionLog は書かない）。
    private var removeButton: some View {
        Button {
            guard let item else { return }
            context.delete(item)
            try? context.save()
            toast.show(.toss, "取り消しました")
            isPresented = false
        } label: {
            Text("登録を取り消す")
                .font(AppFont.rounded(size: 13, weight: .bold))
                .foregroundStyle(tokens.textTer)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}
