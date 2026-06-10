// 今朝のまとめ（アプリ内ブリーフィング）。プロトタイプ fk-digest.jsx FKDigest の移植。
//
// SheetContainer 内に組む。挨拶＋時刻ラベル → lead → nudge → 急ぎ先頭4件 or 空状態カード → CTA → あとで。
// 文言はプロトタイプから一字一句転記。時刻ラベルはデモ固定値（今朝 7:30）ではなく現在時刻から算出する。
// CTA は「今日のごはんを考える」/「リストを見る」とも、ここでは閉じるだけ（レシピは未実装）。

import SwiftUI
import SwiftData

struct DigestSheet: View {
    @Binding var isPresented: Bool

    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store

    @Query private var items: [FoodItem]

    private var tone: Tone { store.tone }
    private var digest: DigestResult { DigestBuilder.build(items: items, tone: tone) }

    var body: some View {
        SheetContainer(isPresented: $isPresented) {
            content
        }
    }

    private var content: some View {
        let dg = digest
        let show = Array(dg.urgent.prefix(4))
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                // lead（fs22 w800）。today/tomorrow があれば末尾「。」。
                Text(dg.lead + (dg.leadEndsWithPeriod ? "。" : ""))
                    .font(AppFont.rounded(size: 22, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // nudge（fs14.5 w700 brandInk）
                if let nudge = dg.nudge {
                    Text(nudge)
                        .font(AppFont.rounded(size: 14.5, weight: .bold))
                        .foregroundStyle(tokens.brandInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)
                } else {
                    Color.clear.frame(height: 0)
                }

                // 急ぎ先頭4件 or 空状態カード
                if !show.isEmpty {
                    VStack(spacing: 9) {
                        ForEach(show) { it in
                            row(it)
                        }
                    }
                    .padding(.bottom, 20)
                } else {
                    Text(dg.sub)
                        .font(AppFont.rounded(size: 15, weight: .semibold))
                        .foregroundStyle(tokens.textSec)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(22)
                        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.bottom, 20)
                }

                // CTA（accent 塗り・閉じるだけ）
                Button {
                    isPresented = false
                } label: {
                    Text(show.isEmpty ? "リストを見る" : "今日のごはんを考える")
                        .font(AppFont.rounded(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)

                // あとで（透明・textSec）
                Button {
                    isPresented = false
                } label: {
                    Text("あとで")
                        .font(AppFont.rounded(size: 14.5, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 26)
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(spacing: 11) {
            AppMark(size: 30)
            Text(greeting)
                .font(AppFont.rounded(size: 14.5, weight: .bold))
                .foregroundStyle(tokens.textSec)
            Spacer(minLength: 0)
            Text(timeLabel)
                .font(AppFont.rounded(size: 12.5, weight: .bold))
                .foregroundStyle(tokens.textTer)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// 挨拶。出典: fk-digest.jsx greeting。
    private var greeting: String {
        switch tone {
        case .cheer:  return "おはよう！きょうも、いい一日に"
        case .simple: return "今朝のまとめ"
        case .gentle: return "おはようございます"
        }
    }

    // MARK: - 急ぎ行

    private func row(_ it: DigestItem) -> some View {
        let cat = FoodCategory.find(it.catId)
        let u = Urgency.colors(daysLeft: it.days, isDark: theme.isDark)
        return HStack(spacing: 12) {
            if let cat {
                CategoryIcon(category: cat, size: 40)
            }
            Text(it.name)
                .font(AppFont.rounded(size: 16, weight: .bold))
                .foregroundStyle(tokens.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(DigestBuilder.verb(days: it.days, tone: tone))
                .font(AppFont.rounded(size: 13.5, weight: .heavy))
                .foregroundStyle(u.pillFg)
                .padding(.vertical, 4)
                .padding(.horizontal, 11)
                .background(u.pillBg, in: Capsule())
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(tokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 時刻ラベル

    /// 「今朝 H:mm」（12時前）/「きょう H:mm」（12時以降）。プロトタイプの固定「今朝 7:30」を実時刻に置換。
    private var timeLabel: String {
        DigestSheet.timeLabel(now: .now, calendar: .current)
    }

    /// テスト可能な純関数版。
    static func timeLabel(now: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let prefix = hour < 12 ? "今朝" : "きょう"
        return String(format: "%@ %d:%02d", prefix, hour, minute)
    }
}
