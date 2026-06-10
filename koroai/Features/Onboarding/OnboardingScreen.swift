// オンボーディング（全画面）。プロトタイプ fk-flows.jsx FKOnboarding の移植。
//
// 全12カテゴリのタイル（複数選択・チェックバッジ）。CTA「食べものを選んでね」/「{N}品ではじめる」、
// 下に「スキップ」。完了で onDone(選択カテゴリID) を呼ぶ（投入・onboarded 更新は親）。
// シールド風アイコン＝SF checkmark.shield。タイトル「腐らせる前に、\nそっとお知らせします。」
//   サブ「いま冷蔵庫にある食べものを選んでください。いくつでもOK、あとから増やせます。」
//   （「いくつでもOK」は text 色で強調）。文言はプロトタイプから一字一句転記。絵文字不使用。
//
// 注: プロトタイプがデモ用に fkSeedFridge を足しているのは無視する（選択カテゴリだけ投入）。

import SwiftUI

struct OnboardingScreen: View {
    /// 完了/スキップ。選択カテゴリIDの配列（スキップ時は空）。
    let onDone: ([String]) -> Void

    @Environment(\.tokens) private var tokens

    @State private var selected: Set<String> = []

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        shieldIcon
                            .padding(.bottom, 22)

                        Text("腐らせる前に、\nそっとお知らせします。")
                            .font(AppFont.rounded(size: 28, weight: .heavy))
                            .tracking(0.3)
                            .lineSpacing(8)
                            .foregroundStyle(tokens.text)
                            .fixedSize(horizontal: false, vertical: true)

                        subtitle
                            .padding(.top, 14)

                        grid
                            .padding(.top, 26)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 70)
                    .padding(.bottom, 20)
                }

                footer
            }
        }
    }

    private var shieldIcon: some View {
        ZStack {
            Circle().fill(tokens.brandSoft)
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(tokens.brand)
        }
        .frame(width: 60, height: 60)
    }

    /// 「いくつでもOK」のみ text 色で強調する。
    private var subtitle: some View {
        var s = AttributedString("いま冷蔵庫にある食べものを選んでください。いくつでもOK、あとから増やせます。")
        if let range = s.range(of: "いくつでもOK") {
            s[range].foregroundColor = tokens.text
            s[range].font = AppFont.rounded(size: 15.5, weight: .heavy)
        }
        return Text(s)
            .font(AppFont.rounded(size: 15.5, weight: .semibold))
            .foregroundStyle(tokens.textSec)
            .lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 11), count: 3)
        return LazyVGrid(columns: columns, spacing: 11) {
            ForEach(FoodCategory.all) { cat in
                CatTile(category: cat, selected: selected.contains(cat.id)) {
                    toggle(cat.id)
                }
            }
        }
    }

    private var footer: some View {
        let n = selected.count
        return VStack(spacing: 10) {
            Button {
                onDone(Array(selected))
            } label: {
                Text(n == 0 ? "食べものを選んでね" : "\(n)品ではじめる")
                    .font(AppFont.rounded(size: 17, weight: .heavy))
                    .foregroundStyle(n > 0 ? .white : tokens.textTer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(n > 0 ? tokens.accent : tokens.surface2,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: n > 0 ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.35) : .clear,
                            radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(n == 0)

            Button {
                onDone([])
            } label: {
                Text("スキップ")
                    .font(AppFont.rounded(size: 13.5, weight: .heavy))
                    .foregroundStyle(tokens.textTer)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: tokens.bg.opacity(0), location: 0),
                    .init(color: tokens.bg, location: 0.3),
                ]),
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}
