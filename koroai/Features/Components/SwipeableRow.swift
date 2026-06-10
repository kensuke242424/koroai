// スワイプ行。プロトタイプ FKSwipe の移植。
//
// 水平: 右 +96pt 超で「食べた」確定 / 左 −96pt 超で「そっと処分」。96pt 超は 0.35 倍のラバーバンド。
//   確定時は横へ 520pt 飛ばし → 高さを畳む。
// 縦（onCycleNext/onCyclePrev が与えられた時のみ）: ±64pt 超で循環。ヒント「↑ 次の食材へ」「↓ 前の食材へ」。
// スワイプでないタップは onTap。軸ロック（最初に 6pt 動いた方向で h/v 確定）。

import SwiftUI

struct SwipeableRow<Content: View>: View {
    var onAte: (() -> Void)?
    var onToss: (() -> Void)?
    var onTap: (() -> Void)?
    var onCycleNext: (() -> Void)?
    var onCyclePrev: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Environment(\.tokens) private var tokens

    @State private var dx: CGFloat = 0
    @State private var dy: CGFloat = 0
    @State private var axis: Axis? = nil
    @State private var moved = false
    @State private var gone: GoneDir? = nil
    @State private var collapsed = false

    private enum Axis { case h, v }
    private enum GoneDir { case ate, toss }

    private let threshold: CGFloat = 96   // 水平確定しきい値
    private let thresholdV: CGFloat = 64  // 縦循環しきい値

    private var canCycle: Bool { onCycleNext != nil || onCyclePrev != nil }

    var body: some View {
        ZStack {
            actionBackdrop
            cycleHint
            content()
                .background(Color.clear)
                .offset(x: dx, y: dy)
                .gesture(dragGesture)
                .simultaneousGesture(
                    // スワイプでない純粋タップ
                    TapGesture().onEnded {
                        if !moved, let onTap { onTap() }
                    }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(height: collapsed ? 0 : nil)
        .opacity(gone == nil ? 1 : 0)
        .animation(.easeInOut(duration: 0.32), value: collapsed)
    }

    // MARK: - リビール背景（左右）

    private var actionBackdrop: some View {
        let showAte = dx > 8
        let reveal = min(1, abs(dx) / threshold)
        let bg: Color = showAte
            ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.18 + reveal * 0.22)
            // 中立背景（処分側）。出典: fk-ui.jsx FKSwipe rgba(120,110,95,0.14) / dark rgba(150,140,125,0.18)
            : (tokens.colorSchemeIsDark
               ? Color(.sRGB, red: 150 / 255, green: 140 / 255, blue: 125 / 255, opacity: 0.18)
               : Color(.sRGB, red: 120 / 255, green: 110 / 255, blue: 95 / 255, opacity: 0.14))
        return HStack {
            Label {
                Text("食べた").font(AppFont.rounded(size: 15, weight: .heavy))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(tokens.accent)
            .opacity(showAte ? Double(reveal) : 0)

            Spacer()

            Label {
                Text("そっと処分").font(AppFont.rounded(size: 15, weight: .bold))
            } icon: {
                Image(systemName: "trash")
            }
            .labelStyle(.trailingIcon)
            .foregroundStyle(tokens.textSec)
            .opacity(!showAte && dx < -8 ? Double(reveal) : 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg)
    }

    // MARK: - 縦循環ヒント

    @ViewBuilder
    private var cycleHint: some View {
        if canCycle && abs(dy) > 6 {
            let reveal = min(1, abs(dy) / thresholdV)
            VStack {
                if dy < 0 {
                    Text("↑ 次の食材へ")
                        .padding(.top, 8)
                    Spacer()
                } else {
                    Spacer()
                    Text("↓ 前の食材へ")
                        .padding(.bottom, 8)
                }
            }
            .font(AppFont.rounded(size: 12.5, weight: .heavy))
            .foregroundStyle(tokens.brandInk)
            .opacity(Double(reveal))
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
    }

    // MARK: - ジェスチャ

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let ddx = value.translation.width
                let ddy = value.translation.height
                if axis == nil && (abs(ddx) > 6 || abs(ddy) > 6) {
                    axis = (canCycle && abs(ddy) > abs(ddx)) ? .v : .h
                }
                if abs(ddx) > 4 || abs(ddy) > 4 { moved = true }
                switch axis {
                case .h:
                    var m = ddx
                    if abs(m) > threshold {
                        m = (m > 0 ? 1 : -1) * (threshold + (abs(m) - threshold) * 0.35)
                    }
                    dx = m; dy = 0
                case .v:
                    var m = ddy
                    if m < 0 && onCycleNext == nil { m = 0 } // 上は next が要る
                    if m > 0 && onCyclePrev == nil { m = 0 } // 下は prev が要る
                    if abs(m) > thresholdV {
                        m = (m > 0 ? 1 : -1) * (thresholdV + (abs(m) - thresholdV) * 0.4)
                    }
                    dy = m; dx = 0
                case .none:
                    break
                }
            }
            .onEnded { _ in
                defer { axis = nil; moved = false }
                switch axis {
                case .h:
                    if dx > threshold { finishH(.ate) }
                    else if dx < -threshold { finishH(.toss) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dx = 0 } }
                case .v:
                    if dy < -thresholdV, onCycleNext != nil { finishCycle(next: true) }
                    else if dy > thresholdV, onCyclePrev != nil { finishCycle(next: false) }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dy = 0 } }
                case .none:
                    break
                }
            }
    }

    private func finishH(_ dir: GoneDir) {
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.27)) {
            dx = dir == .ate ? 520 : -520
            gone = dir
        }
        // 飛ばした後に高さを畳んでから確定コールバック。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.32)) { collapsed = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            if dir == .ate { onAte?() } else { onToss?() }
        }
    }

    private func finishCycle(next: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            dy = next ? -300 : 300
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if next { onCycleNext?() } else { onCyclePrev?() }
            dy = 0
        }
    }
}

// MARK: - 末尾アイコンの Label スタイル

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon
        }
    }
}

private extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}

// MARK: - DesignTokens のダーク判定ヘルパー

extension DesignTokens {
    /// 中立背景など、テーマに依存する裸の rgba を出し分けるための簡易ダーク判定。
    /// 背景色の明度で判断する（dark テーマのみ bg が暗い。night は明るい紙テイスト）。
    var colorSchemeIsDark: Bool {
        let c = OKLab.rgba(of: bg)
        let luminance = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return luminance < 0.45
    }
}
