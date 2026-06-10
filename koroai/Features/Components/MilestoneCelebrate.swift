// 節目の祝祭オーバーレイ。プロトタイプ fk-review.jsx FKMilestoneCelebrate の移植。
//
// 通算（lifetime）が新たに節目を跨いだとき（特に初回）に出す小さな祝祭。
// スクリム 0.42＋ぼかし / 有限 LeafFall / 84pt 円＋リングポップ＋58pt brand 円に白葉 /
//   head・name・body・CTA（トーン別）。CTA かスクリムタップで閉じる。
// 文言はプロトタイプから一字一句転記。絵文字不使用。

import SwiftUI

struct MilestoneCelebrate: View {
    let milestone: Milestone
    let onClose: () -> Void

    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store

    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0
    @State private var leafScale: CGFloat = 0.4

    private var tone: Tone { store.tone }
    private var isFirst: Bool { milestone.id == "first" }

    var body: some View {
        ZStack {
            // スクリム rgba(20,14,6,0.42)＋ぼかし。
            Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.42)
                .background(.ultraThinMaterial.opacity(0.4))
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            LeafFall()
                .allowsHitTesting(false)

            card
                .padding(.horizontal, 26)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // 84pt 円＋リングポップ＋58pt brand 円に白葉。
            ZStack {
                Circle().fill(tokens.brandSoft)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                mixWithTransparent(tokens.accent, fractionOfFirst: 0.30),
                                tokens.accent.opacity(0),
                            ]),
                            center: .center, startRadius: 0, endRadius: 42
                        )
                    )
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                ZStack {
                    Circle().fill(tokens.brand)
                    LeafShape()
                        .fill(.white)
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-10))
                }
                .frame(width: 58, height: 58)
                .scaleEffect(leafScale)
            }
            .frame(width: 84, height: 84)
            .padding(.bottom, 18)

            Text(head)
                .font(AppFont.rounded(size: 13, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(tokens.brandInk)
            Text(milestone.name)
                .font(AppFont.rounded(size: 23, weight: .heavy))
                .foregroundStyle(tokens.text)
                .padding(.top, 5)
            Text(bodyText)
                .font(AppFont.rounded(size: 14, weight: .bold))
                .foregroundStyle(tokens.textSec)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Button {
                onClose()
            } label: {
                Text(cta)
                    .font(AppFont.rounded(size: 15.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 22)
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 26)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .background(tokens.bg2, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.4),
                radius: 25, x: 0, y: 18)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.7).delay(0.15)) {
                ringScale = 1
                ringOpacity = 1
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1)) {
                leafScale = 1
            }
        }
    }

    // MARK: - トーン別コピー（出典: fk-review.jsx FKMilestoneCelebrate）

    private var head: String {
        if isFirst {
            switch tone {
            case .cheer: return "やったね、はじめての一品！"
            case .simple: return "はじめての食べきり"
            case .gentle: return "はじめての食べきり！"
            }
        } else {
            switch tone {
            case .cheer: return "たっせい！"
            case .simple: return "達成"
            case .gentle: return "あたらしい記録"
            }
        }
    }

    private var bodyText: String {
        if isFirst {
            return "ムダにせず食べきれました。\nこの小さな積み重ねが、続いていきます。"
        }
        return milestone.note
    }

    private var cta: String {
        switch tone {
        case .simple: return "OK"
        case .gentle, .cheer: return isFirst ? "この調子でいく" : "つづける"
        }
    }
}
