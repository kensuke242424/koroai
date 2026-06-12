// アプリマーク（角丸正方形の brand 地＋白チェック）。プロトタイプ fk-digest.jsx FKAppMark の移植。
//
// 角丸はサイズの 28%、チェックはサイズの 60%。まとめヘッダーなどで使う。絵文字不使用。

import SwiftUI

struct AppMark: View {
    var size: CGFloat = 30
    /// 角丸半径。nil なら size * 0.28。
    var radius: CGFloat? = nil

    @Environment(\.tokens) private var tokens

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.6, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                tokens.brand,
                in: RoundedRectangle(cornerRadius: radius ?? size * 0.28, style: .continuous)
            )
            .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
            // 装飾（アプリマーク）なので VoiceOver から隠す。
            .accessibilityHidden(true)
    }
}
