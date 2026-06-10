// 入れ直しシート（いま冷蔵庫にある物をタップで選ぶ）。プロトタイプ fk-return.jsx FKReenterSheet の移植。
//
// 生鮮カテゴリのみ（perishable==true）のタイルグリッド（複数選択・チェックバッジ）。
// 確定で「残存食材を全削除（ログなし）→ 選択カテゴリを FoodItem.make で投入」。
//   トースト「{N}品で再開。おかえりなさい」(.ate) を出し、復帰フロー全体を閉じる（onConfirmed）。
// 自作 SheetContainer に組む（native .sheet は使わない）。文言はプロトタイプから一字一句転記。

import SwiftUI
import SwiftData

struct ReenterSheet: View {
    @Binding var isPresented: Bool
    /// 確定後の後始末（親が復帰フロー全体を閉じる）。
    let onConfirmed: () -> Void

    @Environment(\.tokens) private var tokens
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.modelContext) private var context

    @State private var selected: Set<String> = []

    /// 生鮮カテゴリのみ（出典: FKReenterSheet cats.filter(perishable)）。
    private var perishableCats: [FoodCategory] {
        FoodCategory.all.filter(\.perishable)
    }

    var body: some View {
        SheetContainer(isPresented: $isPresented) {
            VStack(spacing: 0) {
                header
                grid
                ctaBar
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented { selected = [] }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("いま冷蔵庫にある物は？")
                .font(AppFont.rounded(size: 21, weight: .heavy))
                .foregroundStyle(tokens.text)
            Text("あてはまるものをタップ。日数は自動でつけ直します。")
                .font(AppFont.rounded(size: 13.5, weight: .semibold))
                .foregroundStyle(tokens.textSec)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 11), count: 3)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 11) {
                ForEach(perishableCats) { cat in
                    CatTile(category: cat, selected: selected.contains(cat.id)) {
                        toggle(cat.id)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
    }

    private var ctaBar: some View {
        let n = selected.count
        return Button {
            confirm()
        } label: {
            Text(n == 0 ? "食材を選んでね" : "これで入れ直す（\(n)品）")
                .font(AppFont.rounded(size: 16.5, weight: .heavy))
                .foregroundStyle(n > 0 ? .white : tokens.textTer)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(n > 0 ? tokens.accent : tokens.surface2,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: n > 0 ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.35) : .clear,
                        radius: 9, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(n == 0)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    /// 残存食材を全削除（ログを書かない）→ 選択カテゴリを FoodItem.make で投入 → トースト → 閉じる。
    private func confirm() {
        let ids = selected
        guard !ids.isEmpty else { return }
        ReturnActions.replaceAllItems(with: ids, context: context)
        toast.show(.ate, "\(ids.count)品で再開。おかえりなさい")
        isPresented = false
        onConfirmed()
    }
}
