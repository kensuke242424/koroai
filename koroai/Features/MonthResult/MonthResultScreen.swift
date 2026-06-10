// 月替わりリザルト（全画面オーバーレイ）。プロトタイプ fk-result.jsx FKMonthResult の移植。
//
// 月をまたいで起動したとき、先月の食べきり結果を「リザルト画面」として祝い、新しい月へ送り出す。
// 構成（上→下）: 放射グラデ背景 / 有限 LeafFall / AppMark 円52・kicker・title（トーン別）/
//   ヒーローカード（称号バッジ・74pt カウントアップ＋「品」・背後グロー・heroSub・tier.note）/
//   統計チップ2枚（先月比 / 連続）/ closing（トーン別）/ CTA「{次月}月をはじめる」/ フッター。
//
// CTA（とフッターの文言）でのみ閉じる（スクリム外タップなし）。閉じるとき monthResultShownFor を先月キーに更新。
// 文言はすべてプロトタイプから一字一句転記（トーン分岐含む）。絵文字不使用・SF Symbols。

import SwiftUI

// MARK: - 先月比チップの導出（純関数・テスト可能）

/// 先月比チップのトーン。up は上向き矢印＋brandInk 文字。
enum DiffChipTone {
    case neutral
    case up
}

/// 先月比チップ（ラベル＋トーン）。
struct DiffChip: Equatable {
    let label: String
    let tone: DiffChipTone
}

enum MonthResultCopy {
    /// 先月比チップを count / prevCount から導出する。出典: fk-result.jsx diffChip。
    /// - prevCount == nil → 「はじめての記録」(neutral)
    /// - count > prevCount → 「先月より ＋N品」(up)
    /// - count == prevCount → 「先月と同じペース」(neutral)
    /// - count < prevCount → 「マイペースで継続中」(neutral)
    static func diffChip(count: Int, prevCount: Int?) -> DiffChip {
        guard let prev = prevCount else {
            return DiffChip(label: "はじめての記録", tone: .neutral)
        }
        if count > prev { return DiffChip(label: "先月より ＋\(count - prev)品", tone: .up) }
        if count == prev { return DiffChip(label: "先月と同じペース", tone: .neutral) }
        return DiffChip(label: "マイペースで継続中", tone: .neutral)
    }
}

// MARK: - 画面

struct MonthResultScreen: View {
    let result: MonthResultData
    /// 「{次月}月をはじめる」タップ。親が monthResultShownFor 更新＋オーバーレイ解除を行う。
    let onStart: () -> Void

    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store

    private var tone: Tone { store.tone }
    private var rank: Rank { Ranks.rank(for: result.count) }
    private var m: Int { result.month }
    private var nextM: Int { result.month % 12 + 1 }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            LeafFall()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        heroCard
                            .padding(.top, 22)
                        statsRow
                            .padding(.top, 14)
                        Text(closing)
                            .font(AppFont.rounded(size: 15, weight: .bold))
                            .foregroundStyle(tokens.textSec)
                            .multilineTextAlignment(.center)
                            .lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 22)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 70)
                    .padding(.bottom, 16)
                }

                ctaFooter
            }
        }
    }

    // MARK: - 背景（放射グラデ brand 26%→bg）

    private var backgroundGradient: some View {
        // radial-gradient(120% 80% at 50% 6%, mix(brand 26%, bg) 0%, bg 58%)。
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: mixOKLab(tokens.brand, tokens.bg, fractionOfFirst: 0.26), location: 0),
                .init(color: tokens.bg, location: 0.58),
            ]),
            center: UnitPoint(x: 0.5, y: 0.06),
            startRadius: 0,
            endRadius: 520
        )
    }

    // MARK: - ヘッダー

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(tokens.brandSoft)
                AppMark(size: 30)
            }
            .frame(width: 52, height: 52)
            .padding(.bottom, 14)

            Text(kicker)
                .font(AppFont.rounded(size: 13.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(tokens.brandInk)
            Text(title)
                .font(AppFont.rounded(size: 25, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(tokens.text)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - ヒーローカード

    private var heroCard: some View {
        VStack(spacing: 0) {
            if store.showResultRank {
                RankBadge(rank: rank)
                    .padding(.bottom, 14)
            }

            // 74pt カウントアップ数字＋「品」、背後に brand 26% 放射グロー。
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                mixWithTransparent(tokens.brand, fractionOfFirst: 0.26),
                                tokens.brand.opacity(0),
                            ]),
                            center: .center, startRadius: 0, endRadius: 66
                        )
                    )
                    .frame(width: 132, height: 132)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    CountUpTo(target: result.count)
                        .font(AppFont.rounded(size: 74, weight: .heavy))
                        .tracking(1)
                    Text("品")
                        .font(AppFont.rounded(size: 26, weight: .heavy))
                }
                .foregroundStyle(tokens.brandInk)
            }

            Text(heroSub)
                .font(AppFont.rounded(size: 15, weight: .heavy))
                .foregroundStyle(tokens.text)
                .padding(.top, 6)
            if store.showResultRank {
                Text(rank.note)
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                    .foregroundStyle(tokens.textTer)
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(tokens.hair, lineWidth: 1)
        )
        .shadow(color: tokens.shadow, radius: 18, x: 0, y: 12)
    }

    // MARK: - 統計チップ

    private var statsRow: some View {
        let chip = MonthResultCopy.diffChip(count: result.count, prevCount: result.prevCount)
        return HStack(spacing: 10) {
            // 先月比チップ（sub なし）。
            statChip(sub: nil) {
                HStack(spacing: 5) {
                    if chip.tone == .up {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    Text(chip.label)
                }
                .font(AppFont.rounded(size: 17, weight: .heavy))
                .foregroundStyle(chip.tone == .up ? tokens.brandInk : tokens.text)
            }

            // 連続チップ。
            statChip(sub: "つづけて食べきり") {
                Text("\(result.streak)ヶ月")
                    .font(AppFont.rounded(size: 17, weight: .heavy))
                    .foregroundStyle(tokens.text)
            }
        }
    }

    private func statChip<Main: View>(
        sub: String?,
        @ViewBuilder main: () -> Main
    ) -> some View {
        VStack(spacing: 3) {
            main()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let sub {
                Text(sub)
                    .font(AppFont.rounded(size: 11.5, weight: .heavy))
                    .foregroundStyle(tokens.textTer)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tokens.hair, lineWidth: 1)
        )
    }

    // MARK: - CTA ＋ フッター

    private var ctaFooter: some View {
        VStack(spacing: 0) {
            Button {
                onStart()
            } label: {
                Text("\(nextM)月をはじめる")
                    .font(AppFont.rounded(size: 16.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(tokens.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.38), radius: 11, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Text("カウントは\(m)月のぶん。\(nextM)月はゼロから、また気楽に。")
                .font(AppFont.rounded(size: 12, weight: .heavy))
                .foregroundStyle(tokens.textTer)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - トーン別コピー（出典: fk-result.jsx）

    private var kicker: String {
        switch tone {
        case .simple: return "月間レポート"
        case .cheer: return "ひと月、おつかれさま！"
        case .gentle: return "ひと月、おつかれさまでした"
        }
    }

    private var title: String {
        switch tone {
        case .simple: return "\(m)月のまとめ"
        case .cheer: return "\(m)月のがんばり"
        case .gentle: return "\(m)月のふりかえり"
        }
    }

    private var heroSub: String {
        switch tone {
        case .simple: return "今月の食べきり"
        case .cheer: return "ぜんぶ、おいしく食べきり！"
        case .gentle: return "ムダにせず、使いきれました"
        }
    }

    private var closing: String {
        switch tone {
        case .simple: return "\(nextM)月もこの調子で。"
        case .cheer: return "最高の1ヶ月！\(nextM)月も、いっしょに。"
        case .gentle: return "すてきな1ヶ月でした。\(nextM)月も、いいペースで。"
        }
    }
}
