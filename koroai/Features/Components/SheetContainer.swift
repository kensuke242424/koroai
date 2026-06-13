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
    /// また親はこのフラグで scrollDisabled を立て、進行中のスクロールパンをキャンセルして
    /// detent ドラッグへ引き継ぐ（large・最上部からの下スワイプ用）。
    var detentDragActive: Binding<Bool>? = nil
    /// コンテンツのスクロールが最上部にあるか（large 時の下スワイプ係合判定に使う）。
    /// nil なら large からのパネルドラッグは係合しない（従来挙動）。
    var contentAtTop: (() -> Bool)? = nil
    /// medium detent からの下スワイプ（破棄ジェスチャ）を検知したときの通知。指定時のみ有効化。
    /// 親が状況（かごの中身など）を見て「実際に閉じる／確認を出して留まる」を判断する。
    /// 指定すると、medium での下方向ドラッグが指によく追従するようになる（閉じられる手触り）。
    var onSwipeDownDismiss: (() -> Void)? = nil
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

    // 破棄ジェスチャ（medium からの下スワイプ）の閾値。raw な指の移動量で判定する。
    // （ジェネリック型のため static stored property は不可。computed で持つ。）
    private static var dismissDistance: CGFloat { 96 }       // この距離を超えれば速度に関係なく破棄要求
    private static var dismissFlickDistance: CGFloat { 28 }  // フリック判定の最小距離
    private static var dismissFlickVelocity: CGFloat { 650 } // 下向きフリックとみなす速度(pt/s)

    var body: some View {
        GeometryReader { geo in
            // 外側で .ignoresSafeArea(.bottom) 済みなので、無視した下インセットが
            // safeAreaInsets.bottom として得られる（パネル内の下余白に使う）。
            let bottomInset = geo.safeAreaInsets.bottom
            ZStack(alignment: .bottom) {
                if isPresented {
                    // スクリム
                    // 注意: removal transition 中の重なり順は保証されないため zIndex を明示する。
                    // 無いと閉じる瞬間にスクリムがパネルの上へ来て、一瞬暗転（ちらつき）する。
                    Self.scrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { requestDismiss() }
                        .zIndex(0)

                    // パネル（下からスプリング・物理下端まで届く）
                    panel(geoHeight: geo.size.height, bottomInset: bottomInset)
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
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
            // 影は「スクロールで毎フレーム変わる中身の合成」ではなく静的な背景形状に付ける。
            // パネル全体（content 込み）に .shadow を掛けると、スクロール中ずっと
            // ほぼ全画面のシルエット再計算＋半径20のぼかしが GPU で走ってフレーム落ちする（実機で確認）。
            UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
            .fill(tokens.bg2)
            // opacity はユーザー調整 0.28→0.40（2026-06-13「やや強めに」）。
            // 静的シェイプ側の影なので強めてもスクロール性能への影響はない。
            .shadow(color: Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.40),
                    radius: 20, x: 0, y: -8)
        )
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
            if h < minH {
                // 破棄可能（onSwipeDownDismiss あり）かつ medium のときは、下方向に指へよく追従させて
                // 「下スワイプで閉じられる」ことを手触りで伝える。それ以外は従来どおり固めのラバーバンド。
                let follow: CGFloat = (onSwipeDownDismiss != nil && current == .medium) ? 0.92 : 0.35
                h = minH - (minH - h) * follow
            }
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
            .modifier(HandleAccessibility(detent: detent))
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
                endDrag(geoHeight: geoHeight,
                        translationY: value.translation.height,
                        velocityY: value.velocity.height)
            }
    }

    /// ドラッグ量→高さ補正。上ドラッグ（負の translation）で高さが増える。
    private func applyDetentDrag(translationY: CGFloat) {
        dragDelta = -translationY
    }

    /// ドラッグ終了の共通処理。medium からの下スワイプが破棄閾値を超えたら破棄要求、
    /// それ以外は近い detent へスナップする（ハンドル／パネル両方のドラッグから呼ぶ）。
    private func endDrag(geoHeight: CGFloat, translationY: CGFloat, velocityY: CGFloat) {
        if onSwipeDownDismiss != nil,
           let detent, detent.wrappedValue == .medium,
           isSwipeDownDismiss(translationY: translationY, velocityY: velocityY) {
            // 見た目は medium へ戻す（非空で確認を出すケースの土台＝そのまま留まる）。
            // かご空のケースは親が isPresented=false にするので、退場アニメが優先される。
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                dragDelta = 0
            }
            onSwipeDownDismiss?()
            return
        }
        snapDetent(geoHeight: geoHeight, translationY: translationY)
    }

    /// medium からの下スワイプを破棄ジェスチャとみなすか。距離が大きい or 下向きフリック。
    private func isSwipeDownDismiss(translationY: CGFloat, velocityY: CGFloat) -> Bool {
        if translationY > Self.dismissDistance { return true }
        return translationY > Self.dismissFlickDistance && velocityY > Self.dismissFlickVelocity
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
    /// large のときは、コンテンツ最上部からの下スワイプに限り detent を先勝ちさせて medium へ。
    /// - 発火条件: detentFractions あり。medium は縦優勢なら両向き、large は最上部×下向きのみ。
    /// - 縦優勢判定（初動で |dy| > |dx| のときだけ係合）でチップ横スクロール／タップを壊さない。
    /// - 座標は .global（ハンドルと同じ＝自己フィードバック発振防止）。
    /// - 高さ計算・スナップは handleZone と同じ applyDetentDrag / snapDetent を再利用する。
    private func panelDetentGesture(geoHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard detentFractions != nil, let detent else { return }
                // 1ドラッグ内で最初の onChanged のときだけ係合判定する。
                if panelDragEngaged == nil {
                    let vertical = abs(value.translation.height) > abs(value.translation.width)
                    switch detent.wrappedValue {
                    case .medium:
                        // medium: 縦優勢ならどちら向きでも係合（横／斜めは見送り）。
                        panelDragEngaged = vertical
                    case .large:
                        // large: コンテンツ最上部からの下方向ドラッグだけ係合
                        // （それ以外は内部スクロールに任せる）。係合すると親が
                        // detentDragActive 経由で scrollDisabled を立て、進行中の
                        // スクロールパンはキャンセルされて detent ドラッグに引き継がれる。
                        let downward = value.translation.height > 0
                        panelDragEngaged = vertical && downward && (contentAtTop?() ?? false)
                    }
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
                endDrag(geoHeight: geoHeight,
                        translationY: value.translation.height,
                        velocityY: value.velocity.height)
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

// MARK: - ハンドルのアクセシビリティ

/// detent を持つシートのハンドルは「シートの高さ」を調整できる要素にし、
/// detent を持たないシートのハンドルは純粋装飾として VoiceOver から隠す。
private struct HandleAccessibility: ViewModifier {
    let detent: Binding<SheetDetent>?

    func body(content: Content) -> some View {
        if let detent {
            content
                .accessibilityElement()
                .accessibilityLabel("シートの高さ")
                .accessibilityValue(detent.wrappedValue == .large ? "大サイズ" : "中サイズ")
                .accessibilityAdjustableAction { direction in
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        switch direction {
                        case .increment: detent.wrappedValue = .large
                        case .decrement: detent.wrappedValue = .medium
                        @unknown default: break
                        }
                    }
                }
        } else {
            content.accessibilityHidden(true)
        }
    }
}
