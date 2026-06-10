// 空冷蔵庫（アイテム0件）。プロトタイプ fk-home.jsx FKEmptyFridge の移植。
//
// brandSoft 96pt 円＋冷蔵庫線画アイコン、タイトル fs21 w800、サブ fs14.5 w600 textSec、
// accent CTA ボタン（radius16 pad 14/26 w800 fs16 ＋プラス）、下に FAB 案内＋静的下矢印。
//
// README 原則「装飾的な無限ループは避ける」に従い、下矢印は静的（バウンスさせない）。

import SwiftUI

struct EmptyFridgeView: View {
    let tone: Tone
    var onAdd: () -> Void

    @Environment(\.tokens) private var tokens

    private var copy: HomeCopy.EmptyFridgeCopy { HomeCopy.emptyFridge(tone: tone) }

    var body: some View {
        VStack(spacing: 0) {
            fridgeBadge
                .padding(.top, 26)
                .padding(.bottom, 22)

            Text(copy.title)
                .font(AppFont.rounded(size: 21, weight: .heavy))
                .foregroundStyle(tokens.text)
                .multilineTextAlignment(.center)

            Text(copy.sub)
                .font(AppFont.rounded(size: 14.5, weight: .semibold))
                .foregroundStyle(tokens.textSec)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 280)
                .padding(.top, 10)

            Button {
                onAdd()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                    Text(copy.cta)
                        .font(AppFont.rounded(size: 16, weight: .heavy))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 26)
                .frame(minHeight: Layout.minTapTarget)
                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 24)

            // FAB 案内＋静的下矢印（無限バウンスさせない）
            VStack(spacing: 5) {
                Text(HomeCopy.emptyFridgeFabHint)
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tokens.textTer)
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    /// brandSoft 96pt 円＋冷蔵庫線画アイコン（SF Symbols refrigerator）。
    private var fridgeBadge: some View {
        Image(systemName: "refrigerator")
            .font(.system(size: 42, weight: .light))
            .foregroundStyle(tokens.brand.opacity(0.7))
            .frame(width: 96, height: 96)
            .background(tokens.brandSoft, in: Circle())
    }
}
