// 落ち葉コンフェッティ（有限・1パス）。プロトタイプ fk-result.jsx FKLeafFall の移植。
//
// README 原則: 無限ループは禁止。プロトタイプは CSS animation を infinite で回すが、
// ここでは 14枚を上から下へ 1 回だけ落とし、約4秒で終了させる（最長 5.6 秒で全葉が画面外）。
// 葉の色は brand / accent / mix(brand 70%, #c7d8a8) の3色をローテーション。
// Reduce Motion 時は何も描かない（控えめな祝祭なので欠落しても支障がない）。
//
// 駆動は TimelineView(.animation) で経過時間 t を取り、各葉の進行 p∈[0,1] を線形に計算する。
// 1パスで終わるよう p>1 になった葉は描かない（オーバーレイ自体は親が一定時間で閉じる/留まる）。

import SwiftUI

struct LeafFall: View {
    /// 葉の枚数。出典: fk-result.jsx length 14。
    var count: Int = 14

    @Environment(\.tokens) private var tokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1枚分のパラメータ（生成時に確定。ランダム位置・遅延・継続・サイズ・色・横ドリフト）。
    private struct Leaf: Identifiable {
        let id: Int
        let xFraction: Double   // 0...1（横位置）
        let delay: Double       // 落下開始の遅延（秒）
        let duration: Double    // 落下にかける秒数（3.4...5.6）
        let size: CGFloat       // 13...25
        let colorIndex: Int     // 0,1,2
        let drift: CGFloat      // 横ドリフト量（-26...26）
        let spins: Double       // 回転（半回転〜2回転ぶん）
    }

    private let leaves: [Leaf]

    init(count: Int = 14) {
        self.count = count
        var rng = SystemRandomNumberGenerator()
        self.leaves = (0..<count).map { i in
            Leaf(
                id: i,
                xFraction: 0.04 + Double.random(in: 0...0.92, using: &rng),
                delay: Double.random(in: 0...1.6, using: &rng),
                duration: 3.4 + Double.random(in: 0...2.2, using: &rng),
                size: 13 + CGFloat.random(in: 0...12, using: &rng),
                colorIndex: i % 3,
                drift: CGFloat.random(in: -26...26, using: &rng),
                spins: Double.random(in: 0.6...2.0, using: &rng)
            )
        }
    }

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    leafLayer(geo: geo, now: timeline.date)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func leafLayer(geo: GeometryProxy, now: Date) -> some View {
        // 基準時刻からの経過秒。TimelineView は同一の date 系列を返すため、初回 onAppear の時刻を起点にする。
        let elapsed = now.timeIntervalSince(start)
        ZStack(alignment: .topLeading) {
            ForEach(leaves) { leaf in
                let t = elapsed - leaf.delay
                if t >= 0 {
                    let p = t / leaf.duration
                    if p <= 1 {
                        let topStart: CGFloat = -28
                        let bottomEnd = geo.size.height + 28
                        let y = topStart + (bottomEnd - topStart) * CGFloat(p)
                        let x = geo.size.width * CGFloat(leaf.xFraction)
                            + leaf.drift * CGFloat(sin(p * .pi)) // 軽い横揺れ
                        LeafShape()
                            .fill(color(leaf.colorIndex))
                            .frame(width: leaf.size, height: leaf.size)
                            .rotationEffect(.degrees(leaf.spins * 360 * p))
                            // 出だしと終わりをわずかにフェード（fkLeafFall の opacity カーブを簡略再現）。
                            .opacity(opacity(for: p))
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    /// 開始時刻（ビュー生成時に固定）。
    private let start = Date()

    private func opacity(for p: Double) -> Double {
        // 0→0.12 で立ち上げ、0.85→1 でフェードアウト。
        if p < 0.12 { return p / 0.12 }
        if p > 0.85 { return max(0, (1 - p) / 0.15) }
        return 1
    }

    private func color(_ index: Int) -> Color {
        switch index {
        case 0: return tokens.brand
        case 1: return tokens.accent
        default: return mixOKLab(tokens.brand, Color(hex: 0xc7d8a8), fractionOfFirst: 0.70)
        }
    }
}

// MARK: - 葉のシェイプ（FKLeaf 風の単色リーフ）

/// やわらかい木の葉形。プロトタイプ FKLeaf（中心脈つきの葉）を塗りつぶしシェイプで近似する。
struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // 左下から右上へ伸びる葉。2本のベジェで紡錘形を作る。
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.minX + w * 0.15, y: rect.minY + h * 0.15)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - w * 0.15, y: rect.maxY - h * 0.15)
        )
        return p
    }
}
