// ふりかえり（常設・プル型）。プロトタイプ fk-review.jsx FKReview の移植。
//
// 全画面オーバーレイ（bg ベタ・戻るチェブロン）。中心は「つぎのごほうび」の道のり。
// ヒーロー（称号バッジ＋いまの記録）/ 週次サマリー（任意表示）/ マイルストーンの縦レール / フッター一文。
// 統計はすべて ConsumptionLog のクエリ導出（Stats の純関数）。文言はプロトタイプから一字一句転記。
// 絵文字不使用・SF Symbols（葉=leaf.fill、錠=lock、チェック=checkmark、上矢印=arrow.up）。

import SwiftUI
import SwiftData

struct ReviewScreen: View {
    @Binding var isPresented: Bool

    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store

    @Query private var logs: [ConsumptionLog]

    private var tone: Tone { store.tone }

    // MARK: - 集計（すべてクエリ導出）

    private var lifetime: Int { Stats.lifetimeAteCount(logs: logs) }
    private var monthly: Int { Stats.monthlyAteCount(logs: logs) }
    private var streak: Int { Stats.monthStreak(logs: logs) }

    private var prevWeekInterval: DateInterval { Stats.previousWeekInterval() }
    private var prevWeekCount: Int { Stats.ateCount(logs: logs, in: prevWeekInterval) }
    private var prevPrevWeekCount: Int {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .weekOfYear, value: -1, to: prevWeekInterval.start) else { return 0 }
        return Stats.ateCount(logs: logs, in: DateInterval(start: start, end: prevWeekInterval.start))
    }

    private var rank: Rank { Ranks.rank(for: lifetime) }
    private var doneCount: Int { Milestones.all.filter { lifetime >= $0.at }.count }
    private var allDone: Bool { doneCount == Milestones.all.count }
    /// 次に目指すマイルストーンの index（無ければ -1）。
    private var nextIndex: Int { Milestones.all.firstIndex { lifetime < $0.at } ?? -1 }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 0) {
                        hero
                        if store.showWeeklySummary {
                            weeklySummary
                        }
                        rewardSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
        }
        // push 遷移で表示する（システムナビバーは隠して自前の topBar を使う）。
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - トップバー

    private var topBar: some View {
        HStack(spacing: 4) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tokens.text)
                    .frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Text("ふりかえり")
                .font(AppFont.rounded(size: 17, weight: .heavy))
                .foregroundStyle(tokens.text)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.bottom, 8)
    }

    // MARK: - ヒーロー

    private var hero: some View {
        VStack(spacing: 0) {
            RankBadge(rank: rank)

            Text("いまの記録")
                .font(AppFont.rounded(size: 14, weight: .bold))
                .foregroundStyle(tokens.textSec)
                .padding(.top, 14)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(lifetime)")
                    .font(AppFont.rounded(size: 46, weight: .heavy))
                Text("品 食べきり")
                    .font(AppFont.rounded(size: 18, weight: .heavy))
            }
            .foregroundStyle(tokens.brandInk)
            .padding(.top, 2)

            HStack(spacing: 9) {
                statChip("今月 \(monthly)品")
                statChip("連続 \(streak)ヶ月")
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(tokens.hair, lineWidth: 1)
        )
        // ヒーローの大数字（「N品 食べきり」）は AX サイズで数字が分断されるため
        // xxxLarge でキャップする（拡大時のみ効く。large の見た目は不変）。
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// brandSoft → surface の 160° グラデ。
    private var heroGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [tokens.brandSoft, tokens.surface]),
            startPoint: UnitPoint(x: 0.18, y: 0),
            endPoint: UnitPoint(x: 0.82, y: 1)
        )
    }

    private func statChip(_ text: String) -> some View {
        Text(text)
            .font(AppFont.rounded(size: 13, weight: .heavy))
            .foregroundStyle(tokens.text)
            .padding(.vertical, 6)
            .padding(.horizontal, 13)
            .background(tokens.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(tokens.hair, lineWidth: 1))
    }

    // MARK: - 週次サマリー（先週のふりかえり）

    private var weeklySummary: some View {
        let up = prevWeekCount > prevPrevWeekCount
        let diff = prevWeekCount - prevPrevWeekCount
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("先週のふりかえり")
                    .font(AppFont.rounded(size: 16.5, weight: .heavy))
                    .foregroundStyle(tokens.text)
                Spacer(minLength: 0)
                Text(weekRangeLabel)
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                    .foregroundStyle(tokens.textTer)
            }
            .padding(.bottom, 14)

            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(tokens.brand).frame(width: 46, height: 46)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(prevWeekCount)")
                            .font(AppFont.rounded(size: 26, weight: .heavy))
                        Text("品 食べきり")
                            .font(AppFont.rounded(size: 15, weight: .heavy))
                    }
                    .foregroundStyle(tokens.brandInk)
                    Text(weeklySub(up: up, diff: diff))
                        .font(AppFont.rounded(size: 12.5, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if up {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .heavy))
                        Text("＋\(diff)")
                    }
                    .font(AppFont.rounded(size: 12.5, weight: .heavy))
                    .foregroundStyle(tokens.brandInk)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 11)
                    .background(tokens.brandSoft, in: Capsule())
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(tokens.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tokens.hair, lineWidth: 1)
            )
        }
        .padding(.top, 26)
    }

    /// 週次サブ文。出典: fk-review.jsx。
    private func weeklySub(up: Bool, diff: Int) -> String {
        if up {
            return "先々週より ＋\(diff)品。いいリズムです"
        }
        return tone == .cheer ? "マイペースでつづいています！" : "マイペースでつづいています"
    }

    /// 先週の実期間ラベル「M/D – M/D」。end は排他なので末尾日は -1 日した日。
    private var weekRangeLabel: String {
        let cal = Calendar.current
        let interval = prevWeekInterval
        let start = interval.start
        let end = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        func md(_ d: Date) -> String {
            let c = cal.dateComponents([.month, .day], from: d)
            return "\(c.month ?? 0)/\(c.day ?? 0)"
        }
        return "\(md(start)) – \(md(end))"
    }

    // MARK: - つぎのごほうび

    private var rewardSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("つぎのごほうび")
                    .font(AppFont.rounded(size: 16.5, weight: .heavy))
                    .foregroundStyle(tokens.text)
                Spacer(minLength: 0)
                Text(allDone ? "ぜんぶ達成！" : "\(doneCount) / \(Milestones.all.count)")
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                    .foregroundStyle(tokens.textTer)
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(Milestones.all.enumerated()), id: \.element.id) { idx, m in
                    milestoneStep(m, index: idx)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
            .background(tokens.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(tokens.hair, lineWidth: 1)
            )
        }
        .padding(.top, 26)
    }

    @ViewBuilder
    private func milestoneStep(_ m: Milestone, index idx: Int) -> some View {
        let done = lifetime >= m.at
        let isNext = !done && idx == nextIndex
        let prevAt = idx == 0 ? 0 : Milestones.all[idx - 1].at
        let prog = isNext ? max(0, min(1, Double(lifetime - prevAt) / Double(m.at - prevAt))) : 0
        let isLast = idx == Milestones.all.count - 1

        HStack(alignment: .top, spacing: 13) {
            // レール（円＋縦線）
            VStack(spacing: 0) {
                railNode(done: done, isNext: isNext)
                if !isLast {
                    Rectangle()
                        .fill(done ? tokens.brand : tokens.hair)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .frame(minHeight: 30)
                        .padding(.top, 2)
                }
            }
            .frame(width: 34)

            // 本文
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(m.name)
                        .font(AppFont.rounded(size: 15.5, weight: .heavy))
                        .foregroundStyle(tokens.text)
                    if done {
                        Text("達成")
                            .font(AppFont.rounded(size: 11, weight: .heavy))
                            .foregroundStyle(tokens.brandInk)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(tokens.brandSoft, in: Capsule())
                    }
                }
                Text(isNext ? "あと\(m.at - lifetime)品で達成" : m.note)
                    .font(AppFont.rounded(size: 12.5, weight: .bold))
                    .foregroundStyle(tokens.textSec)
                    .padding(.top, 2)

                if isNext {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tokens.surface2)
                            Capsule().fill(tokens.accent)
                                .frame(width: geo.size.width * prog)
                        }
                    }
                    .frame(height: 7)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 18)
            .opacity(done || isNext ? 1 : 0.5)
        }
    }

    private func railNode(done: Bool, isNext: Bool) -> some View {
        ZStack {
            Circle()
                .fill(done ? tokens.brand : isNext ? tokens.brandSoft : tokens.surface2)
                .frame(width: 34, height: 34)
            if isNext {
                Circle()
                    .strokeBorder(tokens.accent, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
            } else if isNext {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(tokens.brandInk)
            } else {
                Image(systemName: "lock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tokens.textTer)
            }
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - フッター

    private var footer: some View {
        Text(footerLine)
            .font(AppFont.rounded(size: 13, weight: .bold))
            .foregroundStyle(tokens.textTer)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
    }

    /// フッター一文。出典: fk-review.jsx。
    private var footerLine: String {
        switch tone {
        case .cheer:  return "ひとつ食べきるたび、ここが進みます。今日もいい調子！"
        case .simple: return "食べきるたびに進みます。"
        case .gentle: return "ひとつ食べきるたび、少しずつ進みます。あせらず、気楽に。"
        }
    }
}

// MARK: - 称号バッジ（FKRankBadge 移植）

struct RankBadge: View {
    let rank: Rank
    @Environment(\.tokens) private var tokens

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(tokens.brand).frame(width: 24, height: 24)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
            Text(rank.name)
                .font(AppFont.rounded(size: 15, weight: .heavy))
                .foregroundStyle(tokens.brandInk)
        }
        .padding(.vertical, 7)
        .padding(.leading, 12)
        .padding(.trailing, 15)
        .background(tokens.brandSoft, in: Capsule())
        // inset 1.5pt の brand 28% リング。
        .overlay(
            Capsule().strokeBorder(mixWithTransparent(tokens.brand, fractionOfFirst: 0.28), lineWidth: 1.5)
        )
    }
}
