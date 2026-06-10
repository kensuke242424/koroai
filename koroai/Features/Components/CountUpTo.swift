// カウントアップ数字（useCountTo 移植）。プロトタイプ fk-result.jsx useCountTo の SwiftUI 版。
//
// 0 → target をイージング（ease-out cubic）で数え上げる。約 1.05 秒・最終値を必ず target に収束させる。
// Reduce Motion 時は即値（アニメーションしない）。駆動は TimelineView(.animation)。
// 表示はテキスト（フォント・色は親が .font/.foregroundStyle で指定）。月替わりリザルトのヒーロー数字に使う。
//
// 注: 称号バッジ（RankBadge）は ReviewScreen.swift に既存のものを再利用する（ここでは定義しない）。

import SwiftUI

struct CountUpTo: View {
    let target: Int
    /// 開始遅延（秒）。出典: useCountTo delay 0.24。
    var delay: Double = 0.24
    /// 数え上げにかける秒数。出典: useCountTo dur 1.05。
    var duration: Double = 1.05

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let start = Date()

    var body: some View {
        if reduceMotion {
            Text("\(target)")
        } else {
            TimelineView(.animation) { timeline in
                Text("\(value(at: timeline.date))")
            }
        }
    }

    private func value(at now: Date) -> Int {
        let t = now.timeIntervalSince(start) - delay
        guard t > 0 else { return 0 }
        let p = min(1, t / duration)
        let eased = 1 - pow(1 - p, 3) // ease-out cubic
        // 最終値保証: p>=1 なら厳密に target を返す。
        if p >= 1 { return target }
        return Int((Double(target) * eased).rounded())
    }
}
