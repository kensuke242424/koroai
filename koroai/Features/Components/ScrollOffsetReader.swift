// スクロールオフセット監視（HomeView と AddSheet で共用）。
// 使い方: ScrollView 先頭に offsetProbe(coordinateSpace:) を置き、
// ScrollView に .coordinateSpace(name:) ＋ .onPreferenceChange（iOS 17 用）＋
// .modifier(ScrollOffsetObserver)（iOS 18+ 用）を付ける。

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
/// 新しい OS で更新されないことがあるため）。iOS 17 は PreferenceKey フォールバック。
struct ScrollOffsetObserver: ViewModifier {
    @Binding var scrollY: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newValue in
                if abs(scrollY - newValue) > 0.5 { scrollY = newValue }
            }
        } else {
            content
        }
    }
}
