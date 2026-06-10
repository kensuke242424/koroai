// 詳細入力フォーム（追加・編集共通の内容）。プロトタイプ FKAddSheet の詳細パネル本体の移植。
//
// CategoryIcon 64 ＋カテゴリ名 ＋名前 TextField → 「今日 M/D（曜）」行 → もち日数カード（DaysStepper）→
// CalendarToggle → 開いてれば CalendarPicker → AmountSection(add) → CTA「かごに追加」/「更新する」→
// 「やめる」/「かごから削除」。

import SwiftUI

struct DetailForm: View {
    @Bindable var model: AddFlowModel
    var isEditing: Bool

    @Environment(\.tokens) private var tokens

    private static let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryRow
            todayRow
            daysCard
            CalendarToggle(isOpen: $model.calendarOpen)
                .padding(.bottom, 12)
            if model.calendarOpen {
                CalendarPicker(days: $model.days)
                    .padding(.bottom, 12)
            }
            Color.clear.frame(height: 6)
            AmountSection(
                mode: $model.amountMode,
                frac: $model.amount,
                count: $model.quantity,
                unit: model.unit,
                context: .add,
                total: model.quantity
            )
            .padding(.bottom, 12)
            Color.clear.frame(height: 8)
            ctaButtons
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 24)
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

    private var namePrompt: Text {
        Text("\(model.defaultName)（名前は任意）")
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

    // もち日数カード
    private var daysCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("もち日数")
                    .font(AppFont.rounded(size: 15.5, weight: .bold))
                    .foregroundStyle(tokens.text)
                Text("必要なら調整")
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

    // CTA
    private var ctaButtons: some View {
        VStack(spacing: 0) {
            Button {
                model.saveDetail()
            } label: {
                Text(isEditing ? "更新する" : "かごに追加")
                    .font(AppFont.rounded(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            Button {
                if isEditing {
                    model.deleteEditing()
                } else {
                    model.view = .grid
                }
            } label: {
                Text(isEditing ? "かごから削除" : "やめる")
                    .font(AppFont.rounded(size: 15, weight: .bold))
                    .foregroundStyle(isEditing ? tokens.accent : tokens.textSec)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
    }
}
