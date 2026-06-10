// 「食べた」達成演出。リング拡大＋白丸チェック＋粒5個。0.7秒で消える。無限ループ禁止。
// プロトタイプ FKEatBurst の移植（リング・チェックポップ・5粒のスパーク）。

import SwiftUI

struct EatBurst: View {
    /// 演出の進行（0→1）。親が onAppear で 0→1 に駆動する。
    @State private var progress: CGFloat = 0
    @State private var checkScale: CGFloat = 0.3
    @State private var sparkProgress: CGFloat = 0

    @Environment(\.tokens) private var tokens

    private let sparkAngles: [Double] = [-58, -28, 0, 28, 58]

    var body: some View {
        ZStack {
            // 拡がるリング
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            mixWithTransparent(tokens.accent, fractionOfFirst: 0.45),
                            tokens.accent.opacity(0),
                        ]),
                        center: .center, startRadius: 0, endRadius: 42
                    )
                )
                .frame(width: 84, height: 84)
                .scaleEffect(0.3 + progress * 0.9)
                .opacity(Double(1 - progress))

            // 立ちのぼる粒
            ForEach(Array(sparkAngles.enumerated()), id: \.offset) { idx, angle in
                Circle()
                    .fill(idx % 2 == 0 ? tokens.brand : tokens.accent)
                    .frame(width: 9, height: 9)
                    .offset(y: -sparkProgress * 34)
                    .rotationEffect(.degrees(angle))
                    .opacity(Double(1 - sparkProgress))
            }

            // 白丸チェック
            Circle()
                .fill(.white)
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(tokens.accent)
                )
                .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.40), radius: 8, x: 0, y: 5)
                .scaleEffect(checkScale)
                .opacity(Double(min(1, progress * 2)))
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.66)) {
                progress = 1
                sparkProgress = 1
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                checkScale = 1
            }
        }
    }
}
