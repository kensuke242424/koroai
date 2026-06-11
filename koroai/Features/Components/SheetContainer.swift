// 自作ボトムシート。native .sheet は使わず、プロトタイプ FKSheet を SwiftUI で再現する。
//
// 全画面 ZStack の最前面に重ねて使う前提（呼び出し側の ZStack 最上位に置く）。
// - スクリム rgba(20,14,6,0.34)・タップで onDismissRequest（即閉じではない＝呼び出し側が閉じ判断）。
// - パネルは bg2・上角丸28・上部に 40×5 のハンドル・下からスプリング（response≈0.34）で出入り。
// - maxHeight は画面の 88%。height を指定すると固定高（追加シートは detents を使用）。
// - detents（中⇄大）対応: detents と detent Binding を渡すと、ハンドルのドラッグ/タップで
//   高さを切り替えられる（参照: reference/ころあい 追加フロー 2ステップ.html の2段 detent）。
//   ドラッグ途中はラバーバンド、離すと近い方へスナップ。タップでトグル。
// - パネルは物理下端（ホームインジケータの下）まで届く。既定では中身の下に
//   セーフエリア分のスペーサーを入れて操作要素を上げる。下部バーを画面下端まで
//   敷きたいシート（追加シートのかごバー等）は extendContentUnderHomeIndicator: true を渡し、
//   中身側で余白を管理する。

import SwiftUI

/// シートの detent（中⇄大）。
enum SheetDetent {
    case medium
    case large
}


struct SheetContainer<Content: View>: View {
    @Binding var isPresented: Bool
    /// シート高さの画面比（0...1）。nil なら内容にフィット（maxHeight 88% まで）。
    var heightFraction: CGFloat?
    /// 中⇄大の2段 detent（画面比）。指定時は heightFraction より優先。
    var detentFractions: (medium: CGFloat, large: CGFloat)?
    /// 現在の detent（detentFractions 指定時に使用。親が変更するときは withAnimation で）。
    var detent: Binding<SheetDetent>?
    /// true なら中身を物理下端まで伸ばす（下部バーを敷くシート用）。既定 false。
    var extendContentUnderHomeIndicator: Bool = false
    /// スクリムタップ時の要求（即閉じではない）。nil なら isPresented を false にする既定動作。
    var onDismissRequest: (() -> Void)?
    /// パネル全体の detent ドラッグが進行中（＋指を離した直後の猶予）かどうかを親へ伝える。
    /// シートが指に追従して動くため、ローカル座標では移動量ほぼゼロ＝離した地点の
    /// ボタンにタップ判定が入ってしまう。親はタップ系アクションをこのフラグで抑止する。
    var detentDragActive: Binding<Bool>? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.tokens) private var tokens

    /// detent ドラッグ中の高さ補正（上ドラッグで正）。
    @State private var dragDelta: CGFloat = 0

    /// パネル全体ドラッグ（先勝ち）の係合状態。nil＝未判定、true＝縦ドラッグとして係合、false＝横優勢で見送り。
    /// 1ジェスチャ内で1度だけ判定する（初動の縦横で確定）。
    @State private var panelDragEngaged: Bool?
    /// 猶予クリアの世代カウンタ（次のドラッグが始まったら古いクリア予約を無効化する）。
    @State private var suppressGeneration = 0

    // 出典: fk-ui.jsx FKSheet スクリム rgba(20,14,6,0.34)。
    private static var scrim: Color { Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.34) }

    var body: some View {
        GeometryReader { geo in
            // 外側で .ignoresSafeArea(.bottom) 済みなので、無視した下インセットが
            // safeAreaInsets.bottom として得られる（パネル内の下余白に使う）。
            let bottomInset = geo.safeAreaInsets.bottom
            ZStack(alignment: .bottom) {
                if isPresented {
                    // スクリム
                    Self.scrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { requestDismiss() }

                    // パネル（下からスプリング・物理下端まで届く）
                    panel(geoHeight: geo.size.height, bottomInset: bottomInset)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isPresented)
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - パネル

    private func panel(geoHeight: CGFloat, bottomInset: CGFloat) -> some View {
        let height = resolvedHeight(geoHeight: geoHeight)
        return VStack(spacing: 0) {
            handleZone(geoHeight: geoHeight)

            content()

            // 既定では操作要素をホームインジケータの上に保つ。
            if !extendContentUnderHomeIndicator {
                Color.clear.frame(height: bottomInset)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        // detents 指定時は height が常に確定しているので cap は実質 no-op（ラバーバンドを潰さないよう height に合わせる）。
        // 非 detent シートは従来どおり 88% 上限の内容フィット。
        .frame(maxHeight: detentFractions != nil ? (height ?? geoHeight * 0.88) : geoHeight * 0.88, alignment: .top)
        .background(
            tokens.bg2,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
        )
        .shadow(color: Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.28),
                radius: 20, x: 0, y: -8)
        // 先勝ちの detent ドラッグ。detentFractions が無いシート（EditSheet 等）には
        // GestureMask .none で完全に無効化する（onChanged 側でも detent nil をガード）。
        .simultaneousGesture(
            panelDetentGesture(geoHeight: geoHeight),
            including: detentFractions != nil ? .gesture : .none
        )
    }

    /// 現在のパネル高さ。detents 指定時は detent＋ドラッグ補正、そうでなければ heightFraction。
    private func resolvedHeight(geoHeight: CGFloat) -> CGFloat? {
        if let detents = detentFractions {
            let current = detent?.wrappedValue ?? .medium
            let base = geoHeight * (current == .large ? detents.large : detents.medium)
            let minH = geoHeight * detents.medium
            let maxH = geoHeight * detents.large
            var h = base + dragDelta
            // 範囲外はラバーバンド（下 0.35 / 上 0.15）。上はステータスバーに食い込まないよう geo 高さでハードクランプ。
            if h > maxH { h = min(maxH + (h - maxH) * 0.15, geoHeight) }
            if h < minH { h = minH - (minH - h) * 0.35 }
            return h
        }
        return heightFraction.map { geoHeight * $0 }
    }

    /// ハンドル（detents 指定時はドラッグ/タップで中⇄大を切替）。
    private func handleZone(geoHeight: CGFloat) -> some View {
        Capsule()
            .fill(tokens.hair)
            .frame(width: 40, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
            .onTapGesture {
                guard detentFractions != nil, let detent else { return }
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    detent.wrappedValue = (detent.wrappedValue == .large) ? .medium : .large
                }
            }
            .gesture(detentDragGesture(geoHeight: geoHeight))
    }

    private func detentDragGesture(geoHeight: CGFloat) -> some Gesture {
        // 注意: 座標系は必ず .global にする。ハンドル自身がパネルのリサイズで動くため、
        // ローカル座標だと translation が自己フィードバックして高さが発振（ちらつき）する。
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard detentFractions != nil else { return }
                applyDetentDrag(translationY: value.translation.height)
            }
            .onEnded { value in
                snapDetent(geoHeight: geoHeight, translationY: value.translation.height)
            }
    }

    /// ドラッグ量→高さ補正。上ドラッグ（負の translation）で高さが増える。
    private func applyDetentDrag(translationY: CGFloat) {
        dragDelta = -translationY
    }

    /// 離した位置→近い detent へスナップ。dragDelta は 0 へ戻す。
    private func snapDetent(geoHeight: CGFloat, translationY: CGFloat) {
        guard let detents = detentFractions, let detent else {
            dragDelta = 0
            return
        }
        let current = detent.wrappedValue
        let base = geoHeight * (current == .large ? detents.large : detents.medium)
        let endHeight = base - translationY
        let midpoint = geoHeight * (detents.medium + detents.large) / 2
        let target: SheetDetent = endHeight >= midpoint ? .large : .medium
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            detent.wrappedValue = target
            dragDelta = 0
        }
    }

    // MARK: - パネル全体の detent ドラッグ（先勝ち）

    /// パネル全体（content 含む）に重ねる detent ドラッグ。
    /// medium のとき、シート内のどこを上にスワイプしても先に detent を large にする。
    /// - 発火条件: detentFractions あり・ドラッグ開始時の detent が .medium。
    /// - 縦優勢判定（初動で |dy| > |dx| のときだけ係合）でチップ横スクロール／タップを壊さない。
    /// - 座標は .global（ハンドルと同じ＝自己フィードバック発振防止）。
    /// - 高さ計算・スナップは handleZone と同じ applyDetentDrag / snapDetent を再利用する。
    private func panelDetentGesture(geoHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard detentFractions != nil, let detent else { return }
                // 1ドラッグ内で最初の onChanged のときだけ係合判定する。
                if panelDragEngaged == nil {
                    // 開始時に medium でなければ最初から見送り（large はここでは扱わない）。
                    guard detent.wrappedValue == .medium else {
                        panelDragEngaged = false
                        return
                    }
                    // 縦優勢のときだけ係合（横／斜めは見送り）。
                    panelDragEngaged = abs(value.translation.height) > abs(value.translation.width)
                    if panelDragEngaged == true {
                        detentDragActive?.wrappedValue = true
                        suppressGeneration += 1
                    }
                }
                guard panelDragEngaged == true else { return }
                applyDetentDrag(translationY: value.translation.height)
            }
            .onEnded { value in
                let engaged = panelDragEngaged == true
                panelDragEngaged = nil
                guard engaged else { return }
                snapDetent(geoHeight: geoHeight, translationY: value.translation.height)
                // タップ抑止は離した直後のタップ判定が流れ込むまで少し残す。
                suppressGeneration += 1
                let generation = suppressGeneration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if suppressGeneration == generation {
                        detentDragActive?.wrappedValue = false
                    }
                }
            }
    }

    private func requestDismiss() {
        if let onDismissRequest {
            onDismissRequest()
        } else {
            isPresented = false
        }
    }
}
