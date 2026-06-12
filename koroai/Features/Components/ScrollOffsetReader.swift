// スクロールオフセット監視（HomeView と AddSheet で共用）。
// 使い方: ScrollView 先頭に offsetProbe(coordinateSpace:) を置き、
// ScrollView に .coordinateSpace(name:) ＋ .onPreferenceChange（iOS 17 用）＋
// .modifier(ScrollOffsetObserver)（iOS 18+ 用）を付ける。
//
// パフォーマンス: 生のオフセットを毎フレーム @State に書くと、ヘッダー演出にしか
// 使わないのに画面全体（76タイルの LazyVGrid 等）がスクロール中ずっと再評価されて
// カクつく（実機で確認）。そこで quantize() で 1pt 単位に丸め、演出が終わる位置
// （cap）を超えたら cap に張り付かせる。onScrollGeometryChange は変換後の値が
// 変わったときだけ action を呼ぶため、cap より深いスクロール中は状態更新ゼロになる。

import SwiftUI

// MARK: - スクロールオフセット PreferenceKey（iOS 17 互換）

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - スクロールオフセット監視（iOS 18+）

/// iOS 18+ では onScrollGeometryChange でオフセットを取る（PreferenceKey 方式が
/// 新しい OS で更新されないことがあるため）。iOS 17 は PreferenceKey フォールバック
/// （呼び出し側の onPreferenceChange でも quantize を通すこと）。
struct ScrollOffsetObserver: ViewModifier {
    @Binding var scrollY: CGFloat
    /// このオフセットより深い位置は使わない（ヘッダー演出の終端）。超えたら cap に丸める。
    var cap: CGFloat = .infinity

    /// 0...cap に clamp し、1pt 単位に丸める。フェード演出（22〜34pt 窓）には十分な分解能。
    static func quantize(_ y: CGFloat, cap: CGFloat) -> CGFloat {
        min(max(0, y.rounded()), cap)
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                Self.quantize(geometry.contentOffset.y + geometry.contentInsets.top, cap: cap)
            } action: { _, newValue in
                if scrollY != newValue { scrollY = newValue }
            }
        } else {
            content
        }
    }
}
