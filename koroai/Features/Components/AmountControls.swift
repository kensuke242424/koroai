// 残量コントロール一式。プロトタイプ fk-ui.jsx FKAmtSection / FKAmtModeToggle / FKAmtSlider /
// FKAmtCount / FK_AMT_STOPS の移植。数値・挙動はすべてプロトタイプを正とする。
//
// 文脈（context）: add（追加）/ edit（編集・Step 5）。サブ文言とカウント表示を出し分ける。
// 色は Color.fillColor(fraction:tokens:)（fkFillColor 移植）に一元化。

import SwiftUI

// MARK: - 残量ストップ（吸着スライダーの目盛り）

/// 吸着スライダーのストップ。出典: fk-ui.jsx FK_AMT_STOPS。
struct AmountStop: Identifiable {
    let label: String
    let frac: Double
    var id: String { label }
}

enum AmountStops {
    static let all: [AmountStop] = [
        AmountStop(label: "わずか", frac: 0.12),
        AmountStop(label: "少し", frac: 0.3),
        AmountStop(label: "半分", frac: 0.5),
        AmountStop(label: "多め", frac: 0.72),
        AmountStop(label: "満タン", frac: 1),
    ]

    /// 指定値に最も近いストップ（fkNearestStop の移植）。
    static func nearest(to f: Double) -> AmountStop {
        all.reduce(all[0]) { abs($1.frac - f) < abs($0.frac - f) ? $1 : $0 }
    }
}

// MARK: - 残量の文脈

enum AmountContext {
    case add
    case edit
}

// MARK: - モードトグル（ざっくり量 / 個数）

struct AmountModeToggle: View {
    @Binding var mode: AmountMode

    @Environment(\.tokens) private var tokens

    private let options: [(mode: AmountMode, title: String)] = [
        (.amount, "ざっくり量"),
        (.count, "個数"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.mode) { opt in
                let on = mode == opt.mode
                Button {
                    mode = opt.mode
                } label: {
                    Text(opt.title)
                        .font(AppFont.rounded(size: 12.5, weight: .heavy))
                        .foregroundStyle(on ? tokens.text : tokens.textSec)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(tokens.surface)
                                    .shadow(color: tokens.shadow, radius: 1.5, x: 0, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(tokens.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 吸着スライダー（ざっくり量）

struct AmountSlider: View {
    @Binding var frac: Double

    @Environment(\.tokens) private var tokens

    private var fillColor: Color { Color.fillColor(fraction: frac, tokens: tokens) }
    private var current: AmountStop { AmountStops.nearest(to: frac) }

    private let trackInset: CGFloat = 6   // 出典: fk-ui.jsx left:6 right:6
    private let knob: CGFloat = 28

    var body: some View {
        VStack(spacing: 12) {
            slider
            labelRow
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private var slider: some View {
        GeometryReader { geo in
            let usable = geo.size.width - trackInset * 2
            let x = trackInset + CGFloat(frac) * usable
            ZStack(alignment: .leading) {
                // トラック
                Capsule()
                    .fill(tokens.surface2)
                    .frame(height: 8)
                    .padding(.horizontal, trackInset)
                // フィル
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(0, CGFloat(frac) * usable), height: 8)
                    .offset(x: trackInset)
                    .animation(.spring(response: 0.22, dampingFraction: 0.8), value: frac)
                // ストップドット
                ForEach(AmountStops.all) { s in
                    Circle()
                        .fill(s.frac <= frac + 0.001 ? Color.white : tokens.textTer)
                        .opacity(0.7)
                        .frame(width: 5, height: 5)
                        .position(x: trackInset + CGFloat(s.frac) * usable, y: geo.size.height / 2)
                }
                // ノブ
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(fillColor, lineWidth: 2))
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.22), radius: 3.5, x: 0, y: 2)
                    .position(x: min(max(x, trackInset), geo.size.width - trackInset), y: geo.size.height / 2)
                    .animation(.spring(response: 0.22, dampingFraction: 0.8), value: frac)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let raw = (value.location.x - trackInset) / max(usable, 1)
                        frac = AmountStops.nearest(to: min(max(Double(raw), 0), 1)).frac
                    }
            )
        }
        .frame(height: 30)
    }

    private var labelRow: some View {
        HStack {
            ForEach(AmountStops.all) { s in
                Button {
                    frac = s.frac
                } label: {
                    Text(s.label)
                        .font(AppFont.rounded(size: 12, weight: current.label == s.label ? .heavy : .bold))
                        .foregroundStyle(current.label == s.label ? fillColor : tokens.textTer)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 個数カウント

struct AmountCount: View {
    @Binding var count: Int
    var unit: String
    var context: AmountContext
    /// 初期個数（edit 文脈の差分ピップ・total 表示用）。
    var total: Int

    @Environment(\.tokens) private var tokens

    private var isEdit: Bool { context == .edit }
    private var added: Int { isEdit ? max(0, count - total) : 0 }
    private var consumed: Int { isEdit ? max(0, total - count) : 0 }
    private var pipCount: Int { isEdit ? min(max(total, count), 12) : min(count, 12) }
    private var overflow: Bool { count > 12 }
    private var pipFill: Color {
        isEdit
            ? Color.fillColor(fraction: total > 0 ? min(1, Double(count) / Double(total)) : 1, tokens: tokens)
            : Color.fillColor(fraction: 0.7, tokens: tokens)
    }
    private var fullFill: Color { Color.fillColor(fraction: 1, tokens: tokens) }

    var body: some View {
        VStack(spacing: 0) {
            pipRow
                .padding(.bottom, 14)
            counter
            if isEdit {
                diffRow
                    .padding(.top, 11)
            }
        }
        .padding(.top, 4)
    }

    // 中央ピップ列（上限12表示・超過は「…」）。
    private var pipRow: some View {
        HStack(spacing: 7) {
            ForEach(0..<pipCount, id: \.self) { i in
                let full = i < count
                let isAdded = isEdit && i >= total
                Button {
                    // i+1 == n のときは i に減らす（プロトタイプの挙動移植）。
                    count = (i + 1 == count) ? i : (i + 1)
                } label: {
                    Circle()
                        .fill(full ? (isAdded ? fullFill : pipFill) : tokens.surface2)
                        .overlay {
                            if full {
                                if isAdded {
                                    Circle().strokeBorder(
                                        mixOKLab(fullFill, .white, fractionOfFirst: 0.65), lineWidth: 2)
                                }
                            } else {
                                Circle().strokeBorder(tokens.hair, lineWidth: 2)
                            }
                        }
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            if overflow {
                Text("…")
                    .font(AppFont.rounded(size: 13, weight: .heavy))
                    .foregroundStyle(tokens.textSec)
            }
        }
        .frame(maxWidth: 250)
    }

    private var counter: some View {
        HStack(spacing: 16) {
            stepButton("−") { count = max(0, count - 1) }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(count)")
                    .font(AppFont.rounded(size: 34, weight: .heavy))
                    .foregroundStyle(tokens.text)
                if isEdit && count <= total {
                    Text(" / \(total)")
                        .font(AppFont.rounded(size: 17, weight: .bold))
                        .foregroundStyle(tokens.textTer)
                }
                Text(" \(unit)")
                    .font(AppFont.rounded(size: 16, weight: .bold))
                    .foregroundStyle(tokens.textSec)
            }
            .frame(minWidth: 96)
            stepButton("＋") { count += 1 }
        }
    }

    private func stepButton(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(AppFont.rounded(size: 23, weight: .bold))
                .foregroundStyle(tokens.text)
                .frame(width: 42, height: 42)
                .background(tokens.surface2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var diffRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(added > 0 ? fullFill : tokens.surface2)
                .overlay {
                    if added > 0 {
                        Circle().strokeBorder(mixOKLab(fullFill, .white, fractionOfFirst: 0.65), lineWidth: 2)
                    } else {
                        Circle().strokeBorder(tokens.hair, lineWidth: 2)
                    }
                }
                .frame(width: 14, height: 14)
            Text(diffText)
                .font(AppFont.rounded(size: 12, weight: .bold))
                .foregroundStyle(added > 0 ? tokens.brandInk : tokens.textTer)
        }
    }

    private var diffText: String {
        if added > 0 { return "＋\(added)\(unit)（初期 \(total)\(unit)）" }
        if consumed > 0 { return "使った分 \(consumed)\(unit)" }
        return "まだ減っていません"
    }
}

// MARK: - 残量セクション（add/edit の複合）

struct AmountSection: View {
    @Binding var mode: AmountMode
    @Binding var frac: Double
    @Binding var count: Int
    var unit: String
    var context: AmountContext
    /// 初期個数（edit の差分ピップ用。add では count と同じ）。
    var total: Int

    @Environment(\.tokens) private var tokens

    private var sub: String {
        let isAdd = context == .add
        switch mode {
        case .amount: return isAdd ? "だいたいでOK" : "いま、どのくらい？"
        case .count: return isAdd ? "いくつ買った？" : "のこりはいくつ？"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("残量")
                        .font(AppFont.rounded(size: 15.5, weight: .bold))
                        .foregroundStyle(tokens.text)
                    Text(sub)
                        .font(AppFont.rounded(size: 12.5, weight: .semibold))
                        .foregroundStyle(tokens.textTer)
                }
                Spacer()
                AmountModeToggle(mode: $mode)
            }
            .padding(.bottom, 13)

            if mode == .amount {
                AmountSlider(frac: $frac)
            } else {
                AmountCount(count: $count, unit: unit, context: context, total: total)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
