// 確認・編集画面の各カード（名前・もち日数＋カレンダー・残量）。プロトタイプ FKConfirmItem の移植。
//
// surface 角丸16・影(0 1 3 rgba(80,65,40,0.10))・padding 12/14。
// 上段: CategoryIcon 44 ＋（カテゴリ名 fs11 w700 textTer / 名前 TextField placeholder「{既定名}（任意）」
//   fs18 w800 / 2pt hairline 下線）＋右に ✕（28pt 丸・中立背景）。
// 中段:「もち日数」fs14.5 w700 ＋右に［カレンダーボタン 34pt 角丸11 ＋ DaysStepper］。
//   カレンダー開時は下に CalendarPicker をインライン展開（高さアニメ＝常設コンテナ＋if＋.animation・clipped）。
// 下段: AmountSection(context .add, total=quantity)。
//
// 編集はモデルの set〜(id:) 更新口へ Binding 経由で流す（touched 遷移はモデル側で管理）。

import SwiftUI

struct ConfirmItemCard: View {
    let item: DraftItem
    @Bindable var model: AddFlowModel

    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store

    /// カレンダーのインライン展開状態（カードローカル）。
    /// DEBUG: -openCardCalendar でカレンダー展開を初期表示する（スクショ検証用）。
    #if DEBUG
    @State private var calendarOpen = CommandLine.arguments.contains("-openCardCalendar")
    #else
    @State private var calendarOpen = false
    #endif

    private var category: FoodCategory? { FoodCategory.find(item.catId) }
    private var preset: IngredientPreset? { IngredientCatalog.find(item.presetId) }
    /// プレースホルダー名。プリセット既定名を優先し、引けないときはセクション既定名へフォールバック。
    private var defaultName: String { preset?.name ?? category?.defaultName ?? category?.name ?? "" }

    // 名前: モデルへ書き戻す Binding。
    private var nameBinding: Binding<String> {
        Binding(
            get: { item.name },
            set: { model.setName(id: item.id, $0) }
        )
    }

    // もち日数: モデルへ書き戻す Binding（ステッパー／カレンダー双方向同期）。
    private var daysBinding: Binding<Int> {
        Binding(
            get: { item.days },
            set: { model.setDays(id: item.id, $0) }
        )
    }

    // 残量モード／スライダー／個数: いずれもモデル更新口へ流す（touched はモデルが管理）。
    private var modeBinding: Binding<AmountMode> {
        Binding(
            get: { item.amountMode },
            set: { model.setAmountMode(id: item.id, $0) }
        )
    }

    private var amountBinding: Binding<Double> {
        Binding(
            get: { item.amount },
            set: { model.setAmount(id: item.id, $0) }
        )
    }

    private var quantityBinding: Binding<Int> {
        Binding(
            get: { item.quantity },
            set: { model.setQuantity(id: item.id, $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
                .padding(.bottom, 12)
            daysRow
            calendarSection
            amountSection
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        // 影は出典（FKConfirmItem 0.10）より控えめに（ユーザー指定）。
        .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.06),
                radius: 1.5, x: 0, y: 1)
        .padding(.bottom, 10)
    }

    // MARK: - 上段（アイコン＋名前＋✕）

    private var topRow: some View {
        HStack(spacing: 11) {
            if let category {
                CategoryIcon(category: category, size: 44)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(category?.name ?? "")
                    .font(AppFont.rounded(size: 11, weight: .bold))
                    .foregroundStyle(tokens.textTer)
                TextField("", text: nameBinding, prompt: namePrompt)
                    .font(AppFont.rounded(size: 18, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .textInputAutocapitalization(.never)
                Rectangle()
                    .fill(tokens.hair)
                    .frame(height: 2)
                    .clipShape(Capsule())
                    .padding(.top, 3)
            }
            removeButton
        }
    }

    private var namePrompt: Text {
        Text("\(defaultName)（任意）")
            .font(AppFont.rounded(size: 18, weight: .heavy))
            .foregroundColor(tokens.textTer)
    }

    // ✕ 28pt 丸・中立背景・カード除外。最後の 1枚を消したら選ぶ画面へ自動で戻る。
    private var removeButton: some View {
        Button {
            let last = model.cartCount <= 1
            model.removeItem(id: item.id)
            if last { model.screen = .select }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tokens.textTer)
                .frame(width: 28, height: 28)
                .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.06), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("取り消し")
    }

    // MARK: - 中段（もち日数＋カレンダーボタン＋ステッパー）

    private var daysRow: some View {
        HStack {
            Text("もち日数")
                .font(AppFont.rounded(size: 14.5, weight: .bold))
                .foregroundStyle(tokens.text)
            Spacer()
            HStack(spacing: 8) {
                calendarButton
                DaysStepper(days: daysBinding)
            }
        }
    }

    // カレンダーボタン 34pt 角丸11。開時 accent 14% 地＋accent tint／閉時 中立背景＋textSec。
    private var calendarButton: some View {
        Button {
            // withAnimation で包む（.animation(value:) 直付けだけだとコンテナ外の
            // レイアウト移動が即時に飛び、ニョキっと育つ感じにならない。残量トグルと同じ流儀）。
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                calendarOpen.toggle()
            }
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(calendarOpen ? tokens.accent : tokens.textSec)
                .frame(width: 34, height: 34)
                .background(
                    calendarOpen
                        ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.14)
                        : ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.06),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendarOpen ? "カレンダーを閉じる" : "カレンダーで日付を選ぶ")
    }

    // MARK: - カレンダーのインライン展開

    // 常設コンテナ＋if＋.animation 直付け＋clipped（過去に踏んだ罠: transition がフェードに化けない構造）。
    private var calendarSection: some View {
        VStack(spacing: 0) {
            if calendarOpen {
                CalendarPicker(days: daysBinding)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: calendarOpen)
    }

    // MARK: - 残量エリア（確認画面の「残量」トグルで開閉）

    // カレンダー展開と同じ構造（常設コンテナ＋if＋.animation＋clipped）。
    // off のとき AmountSection ごと畳む（上余白 10pt も一緒に消えるので下のバランスが崩れない）。
    // 畳んでいても値（amount/quantity/mode）は生きている。
    private var amountSection: some View {
        VStack(spacing: 0) {
            if store.confirmAmountShown {
                Color.clear.frame(height: 10)
                AmountSection(
                    mode: modeBinding,
                    frac: amountBinding,
                    count: quantityBinding,
                    unit: item.unit,
                    context: .add,
                    total: item.quantity,
                    boxed: false
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: store.confirmAmountShown)
    }
}
