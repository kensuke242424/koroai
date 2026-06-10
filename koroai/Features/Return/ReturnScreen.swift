// 久しぶり起動の復帰画面（全画面オーバーレイ）。プロトタイプ fk-return.jsx FKReturn の移植。
//
// 古い在庫を責めない。やさしいリセット or さっと入れ直しを提案する。
// 構成: AppMark 円64 / head・sub（トーン別）/ info ボックス / Option 2枚
//   （primary「今ある物だけ入れ直す」＝accent「おすすめ」ピル付き / 「リセットしてまっさらに」）/
//   フッター「このまま続ける」。文言はプロトタイプから一字一句転記。絵文字不使用。
//
// 期限切れ食材の片付け（ログなし削除）は、この画面を出す時点で親（HomeView）が済ませている
// （「少し前の食材は、そっと片付けておきました」を真にするため）。本画面はその後の3択を提示するだけ。

import SwiftUI

struct ReturnScreen: View {
    let daysAway: Int
    /// 「リセットしてまっさらに」: 食材のみ全削除＋トースト。
    let onReset: () -> Void
    /// 「今ある物だけ入れ直す」: 入れ直しシートへ。
    let onReenter: () -> Void
    /// 「このまま続ける」: 残り（未期限切れ）を保持して閉じる。
    let onKeep: () -> Void

    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store

    private var tone: Tone { store.tone }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack {
                            Circle().fill(tokens.brandSoft)
                            AppMark(size: 34)
                        }
                        .frame(width: 64, height: 64)
                        .padding(.bottom, 22)

                        Text(head)
                            .font(AppFont.rounded(size: 30, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(tokens.text)

                        Text(sub)
                            .font(AppFont.rounded(size: 15.5, weight: .semibold))
                            .foregroundStyle(tokens.textSec)
                            .lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)

                        Text("少し前の食材は、そっと片付けておきました。いつでも、好きなところから再開できます。")
                            .font(AppFont.rounded(size: 13, weight: .heavy))
                            .foregroundStyle(tokens.textTer)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(infoBoxColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.top, 16)

                        VStack(spacing: 12) {
                            optionButton(
                                title: "今ある物だけ入れ直す",
                                note: "冷蔵庫にある物をタップで選ぶだけ。30秒で再開。",
                                primary: true,
                                action: onReenter
                            )
                            optionButton(
                                title: "リセットしてまっさらに",
                                note: "今の在庫をクリアして、ゼロから始めます。",
                                primary: false,
                                action: onReset
                            )
                        }
                        .padding(.top, 26)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 78)
                    .padding(.bottom, 20)
                }

                Button {
                    onKeep()
                } label: {
                    Text("このまま続ける")
                        .font(AppFont.rounded(size: 14.5, weight: .heavy))
                        .foregroundStyle(tokens.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Option ボタン

    private func optionButton(title: String, note: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppFont.rounded(size: 16.5, weight: .heavy))
                        .foregroundStyle(tokens.text)
                    Text(note)
                        .font(AppFont.rounded(size: 13, weight: .semibold))
                        .foregroundStyle(tokens.textSec)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if primary {
                    Text("おすすめ")
                        .font(AppFont.rounded(size: 11.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(tokens.accent, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tokens.textTer)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                if primary {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(tokens.surface)
                        .shadow(color: tokens.shadow, radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(tokens.hair, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - info ボックス背景（light/dark で裸の rgba を出し分け）

    private var infoBoxColor: Color {
        // 出典: FKReturn info box dark rgba(255,255,255,0.05) / light rgba(70,55,30,0.05)。
        theme.isDark
            ? Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.05)
            : Color(.sRGB, red: 70 / 255, green: 55 / 255, blue: 30 / 255, opacity: 0.05)
    }

    // MARK: - トーン別コピー（出典: fk-return.jsx FKReturn）

    private var head: String {
        switch tone {
        case .simple: return "おかえり"
        case .cheer: return "おかえりなさい！"
        case .gentle: return "おかえりなさい"
        }
    }

    private var sub: String {
        switch tone {
        case .simple: return "前回から\(daysAway)日。"
        case .cheer: return "\(daysAway)日ぶり。サッと整えて、また気持ちよく再スタート。"
        case .gentle: return "前回から\(daysAway)日空きました。いまの冷蔵庫に合わせて、軽く整えましょう。"
        }
    }
}
