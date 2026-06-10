// トースト。画面下（FAB の上・bottom 約118pt）に Capsule で出す。プロトタイプ FKToast の移植。
//
// ate = accent 背景・白文字・チェック / toss = surface 背景・text 色・ゴミ箱。
// 2.4秒で自動消滅、出入りはスプリング。ToastCenter（@Observable）を environment 注入して連続発火に対応。

import SwiftUI

/// トーストの種別。
enum ToastKind {
    case ate
    case toss
}

/// 1件のトースト。id で連続発火（同じ文言でも再アニメ）を識別する。
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let kind: ToastKind
    let text: String
}

/// トースト中枢。show でメッセージを差し替え、2.4秒後に自動で消す。
@Observable
@MainActor
final class ToastCenter {
    private(set) var current: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    func show(_ kind: ToastKind, _ text: String) {
        current = ToastMessage(kind: kind, text: text)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }
}

/// トースト表示ビュー。ZStack の最前面に重ねて使う。
struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var center
    @Environment(\.tokens) private var tokens

    var body: some View {
        VStack {
            Spacer()
            if let toast = center.current {
                pill(toast)
                    .padding(.bottom, 118)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: center.current)
    }

    @ViewBuilder
    private func pill(_ toast: ToastMessage) -> some View {
        let positive = toast.kind == .ate
        HStack(spacing: 11) {
            if positive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tokens.textSec)
            }
            Text(toast.text)
                .font(AppFont.rounded(size: 15, weight: .bold))
                .foregroundStyle(positive ? .white : tokens.text)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(positive ? tokens.accent : tokens.surface, in: Capsule())
        .shadow(color: Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.28),
                radius: 15, x: 0, y: 10)
    }
}
