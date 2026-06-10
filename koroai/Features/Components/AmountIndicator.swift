// 残量インジケータ。ホーム行・ヒーローで使う小さな残量表示。プロトタイプ FKAmtIndicator の移植。
//
// amount モード → 幅 size(34/40)・高さ6の Capsule バー（track=surface2、fill=fillColor(amount)）。
// count モード → 最大6個の 6pt ピップ（qty 分 fill、超過は「…」）。
// プロトタイプどおり常時表示（amountIsSet によらず）。

import SwiftUI

struct AmountIndicator: View {
    let item: FoodItem
    var size: CGFloat = 34

    @Environment(\.tokens) private var tokens

    var body: some View {
        switch item.amountMode {
        case .amount:
            amountBar
        case .count:
            countPips
        }
    }

    // MARK: - amount バー

    private var amountBar: some View {
        let frac = min(max(item.amount, 0), 1)
        return ZStack(alignment: .leading) {
            Capsule().fill(tokens.surface2)
                .frame(width: size, height: 6)
            Capsule().fill(Color.fillColor(fraction: frac, tokens: tokens))
                .frame(width: size * frac, height: 6)
        }
        .frame(width: size, height: 6)
    }

    // MARK: - count ピップ

    private var countPips: some View {
        let total = max(item.quantityTotal, item.quantity)
        let show = min(total, 6)
        let frac = total > 0 ? Double(item.quantity) / Double(total) : 1
        let fillColor = Color.fillColor(fraction: frac, tokens: tokens)
        return HStack(spacing: 3) {
            ForEach(0..<show, id: \.self) { i in
                Circle()
                    .fill(i < item.quantity ? fillColor : tokens.surface2)
                    .overlay(
                        i < item.quantity
                            ? nil
                            : Circle().strokeBorder(tokens.hair, lineWidth: 1)
                    )
                    .frame(width: 6, height: 6)
            }
            if total > 6 {
                Text("…")
                    .font(AppFont.rounded(size: 9, weight: .heavy))
                    .foregroundStyle(tokens.textTer)
            }
        }
    }
}
