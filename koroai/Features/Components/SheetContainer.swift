// 自作ボトムシート。native .sheet は使わず、プロトタイプ FKSheet を SwiftUI で再現する。
//
// 全画面 ZStack の最前面に重ねて使う前提（呼び出し側の ZStack 最上位に置く）。
// - スクリム rgba(20,14,6,0.34)・タップで onDismissRequest（即閉じではない＝呼び出し側が閉じ判断）。
// - パネルは bg2・上角丸28・上部に 40×5 のハンドル・下からスプリング（response≈0.34）で出入り。
// - maxHeight は画面の 88%。height を指定すると固定高（追加シートは 84%）。
// Step 5 の編集シートでも再利用するため、中身は @ViewBuilder で受ける汎用コンテナにする。

import SwiftUI

struct SheetContainer<Content: View>: View {
    @Binding var isPresented: Bool
    /// シート高さの画面比（0...1）。nil なら内容にフィット（maxHeight 88% まで）。
    var heightFraction: CGFloat?
    /// スクリムタップ時の要求（即閉じではない）。nil なら isPresented を false にする既定動作。
    var onDismissRequest: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Environment(\.tokens) private var tokens

    // 出典: fk-ui.jsx FKSheet スクリム rgba(20,14,6,0.34)。
    private static var scrim: Color { Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.34) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if isPresented {
                    // スクリム
                    Self.scrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { requestDismiss() }

                    // パネル（下からスプリング）
                    panel(maxHeight: geo.size.height * 0.88, height: heightFraction.map { geo.size.height * $0 })
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isPresented)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func panel(maxHeight: CGFloat, height: CGFloat?) -> some View {
        VStack(spacing: 0) {
            // ハンドル 40×5
            Capsule()
                .fill(tokens.hair)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 2)

            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(
            tokens.bg2,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
        )
        .shadow(color: Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.28),
                radius: 20, x: 0, y: -8)
        .ignoresSafeArea(edges: .bottom)
    }

    private func requestDismiss() {
        if let onDismissRequest {
            onDismissRequest()
        } else {
            isPresented = false
        }
    }
}
