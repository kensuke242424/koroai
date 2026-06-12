// エッジスワイプバックの再有効化。
//
// ふりかえり・設定は NavigationStack の push 遷移だが、システムナビバーを
// .toolbar(.hidden, for: .navigationBar) で隠すと UIKit が interactivePopGestureRecognizer を
// 無効化してしまう（delegate がナビバー前提で false を返す）。
// そこで Stack 直下に埋めたプロキシ VC が delegate を引き受け、
// 「スタックが2枚以上 かつ 遷移中でない」ときだけジェスチャを許可する。
//
// 取り付けは ContentView の NavigationStack 直下（HomeView の background）に1箇所だけ。
// push される全画面（ふりかえり・設定）に効く。

import SwiftUI
import UIKit

/// NavigationStack 配下に置くと、ナビバー非表示でもエッジスワイプで pop できるようにする。
struct EdgeSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ProxyViewController { ProxyViewController() }
    func updateUIViewController(_ uiViewController: ProxyViewController, context: Context) {}

    final class ProxyViewController: UIViewController, UIGestureRecognizerDelegate {
        // 親チェーンに UINavigationController が現れるタイミングは環境で揺れるので、
        // didMove / viewWillAppear の両方から冪等に取り付ける。
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attachIfNeeded()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            attachIfNeeded()
        }

        private func attachIfNeeded() {
            guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
            if gesture.delegate !== self {
                gesture.delegate = self
                gesture.isEnabled = true
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = navigationController else { return false }
            // ルート（ホーム）では始動させない。遷移アニメーション中の二重始動も抑止。
            return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
        }
    }
}
