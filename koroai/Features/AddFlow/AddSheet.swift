// 追加シート（刷新版・2ステップ）。プロトタイプ FKAddSheet の移植。
//
// native .sheet は使わず SheetContainer(0.88・extendContentUnderHomeIndicator) 内に組む。
// 幅 2倍の HStack トラックを offset x で 0 ⇄ −画面幅 にずらして「選ぶ」⇄「確認・編集」を横プッシュする。
// 閉じる確認は全画面に重ねるトップモーダル。文言はプロトタイプ / ADD_FLOW.md から一字一句転記。
//
// セクション＝FoodCategory.all（10件）、タイル＝IngredientPreset（計76枚）。
// セクション見出しはセクション name、タイルは preset.label を表示する。

import SwiftUI
import SwiftData

// MARK: - AddSheet

struct AddSheet: View {
    @Binding var isPresented: Bool

    @Environment(\.tokens) private var tokens
    @Environment(\.resolvedTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(ToastCenter.self) private var toast
    @Environment(\.modelContext) private var context
    /// SheetContainer の detent ドラッグ中フラグ（離し際のタップ流れ込み抑止）。
    @State private var sheetDragging = false

    @State private var model = AddFlowModel()
    /// シートの detent（中⇄大）。初期は中、確認画面へ進むと自動で大（参照HTML準拠）。
    @State private var detent: SheetDetent = .medium
    /// チップ行の段階出現用。CTA エリアのせり出し完了後に true にする（ユーザー指定の順序）。
    @State private var chipRowShown = false

    private var copy: ToneCopy { store.tone.copy }

    var body: some View {
        ZStack {
            SheetContainer(
                isPresented: $isPresented,
                detentFractions: (medium: 0.68, large: 1.0), // 中68%⇄大は最大（セーフエリア上端）まで
                detent: $detent,
                extendContentUnderHomeIndicator: true, // 下部トレイを画面下端まで敷く（デザイン準拠）
                onDismissRequest: { handleDismiss() },
                detentDragActive: $sheetDragging,
                // large 時の下スワイプ先勝ち判定（表示中画面のスクロールが最上部か）。
                contentAtTop: { model.screen == .select ? selectScrollY <= 1 : confirmScrollY <= 1 }
            ) {
                track
            }

            // 閉じる確認は「トップモーダル」なので、シートの内側ではなく全画面に重ねる。
            confirmCloseOverlay
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                initPresentation()
            } else {
                didInitPresentation = false
                chipRowShown = false
            }
        }
        .onChange(of: model.cartCount) { old, new in
            if old == 0, new > 0 {
                // CTA エリアのせり出し（トレイ挿入アニメ）が終わってからチップ行を出す（ユーザー指定の順序）。
                chipRowShown = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        chipRowShown = true
                    }
                }
            } else if new == 0 {
                chipRowShown = false
            }
        }
        .onChange(of: model.screen) { _, screen in
            // 確認画面へ進むと自動で大 detent（参照HTML準拠）。
            if screen == .confirm {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    detent = .large
                }
            }
        }
        .onAppear {
            if isPresented { initPresentation() }
        }
    }

    /// 表示開始時の初期化。onAppear と onChange の両方から呼ばれうるため
    /// didInitPresentation で1回にガードする（reset の二重実行でカゴが消えるのを防ぐ）。
    @State private var didInitPresentation = false
    @State private var selectScrollY: CGFloat = 0
    /// 確認画面のスクロール量（large 時の下スワイプ先勝ち判定用）。
    @State private var confirmScrollY: CGFloat = 0

    /// 折りたたみ中セクションの id 集合（"recent" ＋ FoodCategory.id）。
    /// 既定は「最近使った食材」だけ展開・他は全部折りたたみ。表示ごとにリセット（永続化しない）。
    @State private var collapsedSections: Set<String> = []
    /// 「最近使った食材」セクションの表示スナップショット。
    /// シート表示中に commit はされないので実質固定だが、表示開始時に1度確定する。
    @State private var recentPresets: [IngredientPreset] = []

    /// 「最近使った食材」の特別セクション id。
    private static let recentSectionId = "recent"

    private func initPresentation() {
        guard !didInitPresentation else { return }
        didInitPresentation = true
        model.reset(store: store)
        detent = .medium
        chipRowShown = false
        selectScrollY = 0
        confirmScrollY = 0
        // 最近使った食材（最大9枚・解決できない id はスキップ）。
        recentPresets = Array(store.recentPresetIds.compactMap { IngredientCatalog.find($0) }.prefix(9))
        // 既定の開閉: 「最近使った食材」のみ展開・他セクションは折りたたみ。
        collapsedSections = Set(FoodCategory.all.map(\.id))
        #if DEBUG
        applyLaunchHook()
        #endif
    }

    private func isCollapsed(_ id: String) -> Bool { collapsedSections.contains(id) }

    private func toggleSection(_ id: String) {
        // detent ドラッグの離し際に「離した地点のボタン」へタップ判定が流れ込むのを抑止。
        guard !sheetDragging else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            if collapsedSections.contains(id) {
                collapsedSections.remove(id)
            } else {
                collapsedSections.insert(id)
            }
        }
    }

    #if DEBUG
    /// -openAddConfirm で 刺身×2・牛乳×1 をカゴに積んで確認画面を初期表示する（スクショ用）。
    /// -autoAddOne <id> は表示 1.2 秒後にタイルタップと同じ経路（addOneAnimated）で 1件追加する
    /// （トレイ出現アニメーションの録画検証用）。<id> は preset id 優先・後方互換で section id も試す。
    /// 二重実行は initPresentation 側でガード済み。
    private func applyLaunchHook() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-autoAddOne"), i + 1 < args.count,
           let preset = resolvePreset(args[i + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                addOneAnimated(preset)
            }
        }
        if args.contains("-openAddConfirm") {
            seedConfirmSample()
            model.screen = .confirm
        }
        if args.contains("-openCloseConfirm") {
            seedConfirmSample()
            model.confirmClose = true
        }
        // 閉じアニメーションの録画検証用: 表示 1.5 秒後に自動で閉じる。
        if args.contains("-autoCloseSheet") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
        }
    }

    /// スクショ用に 刺身×2・牛乳×1 を積む。
    private func seedConfirmSample() {
        if let sashimi = IngredientCatalog.find("fish.sashimi") {
            model.addOne(preset: sashimi, store: store)
            model.addOne(preset: sashimi, store: store)
        }
        if let milk = IngredientCatalog.find("dairy.milk") {
            model.addOne(preset: milk, store: store)
        }
    }

    /// -autoAddOne の引数解決。preset id を優先し、無ければ section id（FoodCategory）の先頭プリセットにフォールバック。
    private func resolvePreset(_ id: String) -> IngredientPreset? {
        if let p = IngredientCatalog.find(id) { return p }
        if let cat = FoodCategory.find(id) { return IngredientCatalog.presets(in: cat.id).first }
        return nil
    }
    #endif

    // MARK: - 横プッシュトラック

    /// 幅 2倍の HStack を offset x でずらして 2画面を横プッシュする。
    private var track: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                selectScreen
                    .frame(width: w)
                confirmScreen
                    .frame(width: w)
            }
            .frame(width: w * 2, alignment: .leading)
            .offset(x: model.screen == .confirm ? -w : 0)
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: model.screen)
        }
    }

    // MARK: - 画面1：選ぶ

    private var selectScreen: some View {
        VStack(spacing: 0) {
            categoryGrid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // タイトル＋説明が両方スクロールで隠れたら、インラインタイトルをフェードイン
        // （確認画面のナビと同じ見た目。表示領域を最大化するため常設バーにしない）。
        .overlay(alignment: .top) {
            selectInlineBar
        }
        // 下部トレイ（チップ＋CTA）は1品以上選択されたときだけ、下からせり出す（ユーザー指定）。
        .overlay(alignment: .bottom) {
            if model.cartCount > 0 {
                selectTray
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// タイトル＋説明。スクロール内容に含めて、上にスクロールすると隠れる。
    private var selectHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(copy.addTitle)
                .font(AppFont.rounded(size: 22, weight: .heavy))
                .foregroundStyle(tokens.text)
            Text("カテゴリを選んでカゴへ。最後にまとめて確認します。")
                .font(AppFont.rounded(size: 13.5, weight: .semibold))
                .foregroundStyle(tokens.textSec)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // ヘッダー（タイトル＋説明 ≈70pt）が隠れきるあたりでインラインタイトルを入れる。
    private var inlineTitleProgress: CGFloat { clamp01((selectScrollY - 56) / 22) }

    /// インラインタイトル。ハンドル領域（高さ28・SheetContainer）まで背景を伸ばして
    /// シート上端と一体の1枚のヘッダーに見せる（ハンドルは同位置に描き直す）。
    /// allowsHitTesting(false) なので下の SheetContainer のハンドル操作はそのまま効く。
    private var selectInlineBar: some View {
        VStack(spacing: 0) {
            // SheetContainer.handleZone と同位置（カプセル上端 ≈15.5pt）に合わせる。
            Capsule()
                .fill(tokens.hair)
                .frame(width: 40, height: 5)
                .padding(.top, 15.5)
            Text("食材をえらぶ")
                .font(AppFont.rounded(size: 16, weight: .heavy))
                .foregroundStyle(tokens.text)
                .padding(.top, 9)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background {
            // 少しだけ透過させ、裏に回るタイルがほのかに見える馴染みを作る
            // （確認画面の上部説明エリアと同じ印象に合わせる）。
            UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
            .fill(tokens.bg2.opacity(0.92))
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(tokens.hair).frame(height: 1)
        }
        // コンテンツ領域はハンドル領域の直下から始まるので、その分上に伸ばす。
        .padding(.top, -28)
        .opacity(Double(inlineTitleProgress))
        .allowsHitTesting(false)
    }

    private var categoryGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // スクロール量をオフセットで取得（iOS 17 互換 PreferenceKey）
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geo.frame(in: .named("addSelectScroll")).minY
                    )
                }
                .frame(height: 0)

                VStack(spacing: 0) {
                    selectHeader
                    VStack(spacing: 0) {
                        // 特別セクション「最近使った食材」（空ならセクションごと非表示）。
                        if !recentPresets.isEmpty {
                            collapsibleSection(
                                id: Self.recentSectionId,
                                title: "最近使った食材",
                                presets: recentPresets
                            )
                        }
                        ForEach(FoodCategory.all) { section in
                            collapsibleSection(
                                id: section.id,
                                title: section.name,
                                presets: IngredientCatalog.presets(in: section.id)
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
                    .id("addSelectScrollTarget") // -scrollAddSelect 検証フックのスクロール先
                }
                // 下部トレイに隠れない余白（チップ行＋CTA 分）。
                .padding(.bottom, 132)
            }
            .coordinateSpace(name: "addSelectScroll")
            // medium 中は内部スクロール不可（detent ドラッグと競合させない＝先勝ちで大化させる）。
            // detent ドラッグ係合中（sheetDragging）も止めて、進行中のスクロールパンを
            // キャンセルして detent へ引き継ぐ（large・最上部の下スワイプ）。
            .scrollDisabled(detent == .medium || sheetDragging)
            .onPreferenceChange(ScrollOffsetKey.self) { y in
                // iOS 17 用フォールバック。iOS 18+ は onScrollGeometryChange（下の modifier）で取得する。
                if #unavailable(iOS 18.0) {
                    if abs(selectScrollY - y) > 1 { selectScrollY = y }
                }
            }
            .modifier(ScrollOffsetObserver(scrollY: $selectScrollY))
            .frame(maxHeight: .infinity)
            #if DEBUG
            .onAppear {
                // スクショ用: -scrollAddSelect で全セクションを展開してから、
                // タイトル＋説明が隠れるまでスクロールした状態にする（インラインタイトル検証用）。
                guard CommandLine.arguments.contains("-scrollAddSelect") else { return }
                collapsedSections = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { proxy.scrollTo("addSelectScrollTarget", anchor: .top) }
                }
            }
            #endif
        }
    }

    private func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }

    /// 折りたたみ可能なセクション（見出し行タップで開閉・展開時のみタイルグリッドを描く）。
    /// presets に含まれる選択済み件数を見出し右のバッジに出す（折りたたみ中の手がかり）。
    @ViewBuilder
    private func collapsibleSection(id: String, title: String, presets: [IngredientPreset]) -> some View {
        let collapsed = isCollapsed(id)
        let selectedCount = presets.reduce(0) { $0 + (model.contains(presetId: $1.id) ? 1 : 0) }
        VStack(spacing: 0) {
            sectionHeader(title, collapsed: collapsed, selectedCount: selectedCount) {
                toggleSection(id)
            }
            // 常設コンテナ＋if＋clipped＋.animation で高さアニメ（transition 不発の罠回避）。
            VStack(spacing: 0) {
                if !collapsed {
                    tileGrid(presets)
                        .padding(.top, 2)
                        // 展開グリッドと次セクション見出しの間にゆとり。
                        .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    /// セクション見出し行。タップ領域は行全体・最低44pt。シェブロン（chevron.down を回転）。
    /// 折りたたみ中で選択数 n>0 のとき、右側に小さい丸バッジで n を出す。
    private func sectionHeader(
        _ label: String,
        collapsed: Bool,
        selectedCount: Int,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(label)
                    .font(AppFont.rounded(size: 14.5, weight: .heavy))
                    .foregroundStyle(tokens.brandInk)
                // 折りたたみ中・選択ありのときだけ件数バッジ。
                if collapsed, selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(AppFont.rounded(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 3)
                        .background(tokens.accent, in: Circle())
                }
                Rectangle()
                    .fill(tokens.hair)
                    .frame(height: 1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(tokens.textTer)
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
            }
            .padding(.horizontal, 2)
            // 詰めつめ感を避けるため、44pt より少しゆとりを持たせる。
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tileGrid(_ presets: [IngredientPreset]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 11), count: 3)
        return LazyVGrid(columns: columns, spacing: 11) {
            ForEach(presets) { preset in
                if let section = FoodCategory.find(preset.sectionId) {
                    presetTile(preset, section: section)
                }
            }
        }
    }

    /// タイルタップでカゴにトグル選択する。トレイの出現・チップ挿入・バッジ変化が
    /// すべてアニメーションするよう、変異は必ず withAnimation で包む
    /// （.animation(value:) 直付けだけではトレイ高さの変化を取りこぼす）。
    private func toggleAnimated(_ preset: IngredientPreset) {
        // detent ドラッグの離し際のタップ流れ込みを抑止（toggleSection と同様）。
        guard !sheetDragging else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            model.toggle(preset: preset, store: store)
        }
    }

    /// DEBUG フック（-autoAddOne）用に 1件だけ追加するアニメーション付き経路。
    private func addOneAnimated(_ preset: IngredientPreset) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            model.addOne(preset: preset, store: store)
        }
    }

    /// タイル＝食材プリセット単位。アイコン・色はセクション（FoodCategory）を継承し、ラベルは preset.label。
    /// タップ＝トグル選択（入っていれば外す）。同一 presetId はかご最大1件。
    private func presetTile(_ preset: IngredientPreset, section: FoodCategory) -> some View {
        let active = model.contains(presetId: preset.id)
        return Button {
            toggleAnimated(preset)
        } label: {
            VStack(spacing: 9) {
                CategoryIcon(category: section, size: 52)
                Text(preset.label)
                    .font(AppFont.rounded(size: 14, weight: .bold))
                    .foregroundStyle(tokens.text)
                    .multilineTextAlignment(.center)
                    // 長い名前（ほうれん草・小松菜 等）は1行に縮めて収める。
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.horizontal, 8)
            .padding(.bottom, 13)
            .background(
                active
                    ? mixOKLab(section.color, tokens.surface, fractionOfFirst: 0.14)
                    : tokens.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(active ? section.color : .clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                tileBadge(color: section.color, active: active)
                    .padding(7)
            }
            .shadow(color: tokens.shadow, radius: 1.5, x: 0, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// タイル右上バッジ。未選択＝「＋」・選択中＝チェックマーク（セクション色地・白）。
    @ViewBuilder
    private func tileBadge(color: Color, active: Bool) -> some View {
        if active {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 21, height: 21)
                .background(color, in: Circle())
                // 選択状態の切替でポップ。
                .id(active)
                .transition(.scale.combined(with: .opacity))
        } else {
            Text("＋")
                .font(AppFont.rounded(size: 16, weight: .bold))
                .foregroundStyle(tokens.textTer)
                .frame(width: 21, height: 21)
                .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.07), in: Circle())
        }
    }

    // MARK: - 選ぶ画面・下部トレイ（チップ行＋CTA）

    private var selectTray: some View {
        let groups = model.grouped
        let n = model.cartCount
        let showChips = chipRowShown && !groups.isEmpty
        return VStack(spacing: 0) {
            if showChips {
                chipRow(groups)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            // 「確認する（N品）」CTA。
            Button {
                guard !sheetDragging, n > 0 else { return }
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    model.screen = .confirm
                }
            } label: {
                Text(n > 0 ? "確認する（\(n)品）" : "確認する")
                    .font(AppFont.rounded(size: 16, weight: .heavy))
                    .foregroundStyle(n > 0 ? .white : tokens.textTer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(n > 0 ? tokens.accent : tokens.surface2,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: n > 0 ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.35) : .clear,
                            radius: 9, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(n == 0)
            .padding(.horizontal, 18)
            .padding(.top, showChips ? 0 : 12)
        }
        // 押しやすさのため、下部に適度な余白を確保する（ユーザー指定）。
        .padding(.bottom, 26)
        // チップ行の出現/消滅でトレイ高さが滑らかに変わるように。
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: showChips)
        .background {
            // surface2 地・上角丸18・上 hairline・上向き淡影（0 -3 14 rgba(80,65,40,0.07)）。
            UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 18,
                style: .continuous
            )
            .fill(tokens.surface2)
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.07),
                    radius: 7, x: 0, y: -3)
            .background(alignment: .bottom) {
                // 競り上がりバウンドのオーバーシュート中に下へ隙間が見えないよう、
                // トレイ下端のさらに下へ surface2 を 120pt 余分に敷いておく（ブリード）。
                Rectangle()
                    .fill(tokens.surface2)
                    .frame(height: 120)
                    .offset(y: 120)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(tokens.hair).frame(height: 1)
        }
    }

    private func chipRow(_ groups: [AddFlowModel.CartGroup]) -> some View {
        HStack(spacing: 8) {
            // 🧺 の代用: SF "basket"（絵文字禁止）。左に固定。
            Image(systemName: "basket")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tokens.textSec)
                .frame(width: 24, height: 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(groups) { g in
                        chip(g)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        // チップ出現はポップイン（最新が先頭＝追加順降順）。
        .animation(.spring(response: 0.36, dampingFraction: 0.7), value: model.cartCount)
    }

    @ViewBuilder
    private func chip(_ g: AddFlowModel.CartGroup) -> some View {
        if let preset = IngredientCatalog.find(g.presetId),
           let section = FoodCategory.find(g.catId) {
            // トグル選択化でカウントは廃止。「名前 ✕」だけのチップ（✕ でプリセット解除）。
            HStack(spacing: 5) {
                Text(preset.label)
                    .font(AppFont.rounded(size: 12, weight: .heavy))
                    .foregroundStyle(tokens.text)
                    .fixedSize()
                Button {
                    guard !sheetDragging else { return }
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) {
                        model.removePreset(g.presetId)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tokens.textSec)
                        .frame(width: 17, height: 17)
                        .background(ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.08), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.label) を取り消し")
            }
            .padding(.leading, 9)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(tokens.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(mixWithTransparent(section.color, fractionOfFirst: 0.33), lineWidth: 1)
            )
            .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.10),
                    radius: 1, x: 0, y: 1)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - 画面2：確認・編集

    private var confirmScreen: some View {
        VStack(spacing: 0) {
            confirmHeader
            confirmSub
            confirmList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            confirmTray
        }
    }

    private var confirmHeader: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    model.screen = .select
                }
            } label: {
                Text("‹ 選び直す")
                    .font(AppFont.rounded(size: 14.5, weight: .heavy))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(tokens.accent)
                    .frame(minHeight: Layout.minTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 78, alignment: .leading)

            Spacer(minLength: 0)
            Text("内容を確認")
                .font(AppFont.rounded(size: 16, weight: .heavy))
                .foregroundStyle(tokens.text)
            Spacer(minLength: 0)

            // 右スロット（左の「選び直す」と同幅78・中央寄せ維持）に「残量」トグル。
            confirmAmountToggle
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// 確認画面の「残量」表示トグル。on＝accent 14%地＋accent文字／off＝中立背景＋textSec
    /// （カレンダーボタンの配色流儀を踏襲）。タップで store.confirmAmountShown を切替（永続化）。
    private var confirmAmountToggle: some View {
        let on = store.confirmAmountShown
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                store.confirmAmountShown.toggle()
            }
        } label: {
            // 「表示の切替」であることが伝わるよう目アイコンを添える（on=eye / off=eye.slash）。
            HStack(spacing: 4) {
                Image(systemName: on ? "eye" : "eye.slash")
                    .font(.system(size: 11.5, weight: .bold))
                Text("残量")
                    .font(AppFont.rounded(size: 13, weight: .heavy))
            }
            .foregroundStyle(on ? tokens.accent : tokens.textSec)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(
                on
                    ? mixWithTransparent(tokens.accent, fractionOfFirst: 0.14)
                    : ControlColors.neutral(isDark: tokens.colorSchemeIsDark, lightOpacity: 0.06),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "残量の入力を隠す" : "残量を入力する")
    }

    private var confirmSub: some View {
        Text("名前・もち日数・残量を調整できます。")
            .font(AppFont.rounded(size: 12.5, weight: .semibold))
            .foregroundStyle(tokens.textSec)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }

    private var confirmList: some View {
        ScrollView {
            // スクロール量をオフセットで取得（iOS 17 互換 PreferenceKey。selectScreen と同じ構造）。
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: -geo.frame(in: .named("addConfirmScroll")).minY
                )
            }
            .frame(height: 0)

            VStack(spacing: 0) {
                ForEach(FoodCategory.all) { section in
                    confirmSection(section)
                }
                // 末尾「＋ 食べものを選び直す」（破線・選ぶへ戻る）。
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        model.screen = .select
                    }
                } label: {
                    Text("＋ 食べものを選び直す")
                        .font(AppFont.rounded(size: 13.5, weight: .heavy))
                        .foregroundStyle(tokens.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .foregroundStyle(tokens.hair)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            // 下部トレイに隠れない余白。
            .padding(.bottom, 100)
        }
        .coordinateSpace(name: "addConfirmScroll")
        // medium 中は内部スクロール不可。detent ドラッグ係合中（sheetDragging）も止めて、
        // 進行中のスクロールパンをキャンセルして detent へ引き継ぐ（large・最上部の下スワイプ）。
        .scrollDisabled(detent == .medium || sheetDragging)
        .onPreferenceChange(ScrollOffsetKey.self) { y in
            if #unavailable(iOS 18.0) {
                if abs(confirmScrollY - y) > 1 { confirmScrollY = y }
            }
        }
        .modifier(ScrollOffsetObserver(scrollY: $confirmScrollY))
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func confirmSection(_ section: FoodCategory) -> some View {
        // このセクションに属するかご内アイテム（追加順）。
        let items = model.itemsInSection(section.id)
        if !items.isEmpty {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(section.name)
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundStyle(tokens.brandInk)
                    Rectangle()
                        .fill(tokens.hair)
                        .frame(height: 1)
                }
                .padding(.horizontal, 2)
                .padding(.top, 10)
                .padding(.bottom, 9)

                ForEach(items) { it in
                    ConfirmItemCard(item: it, model: model)
                }
            }
        }
    }

    private var confirmTray: some View {
        let n = model.cartCount
        return Button {
            model.commit(context: context, toastCenter: toast)
            isPresented = false
        } label: {
            Text("冷蔵庫に追加（\(n)品）")
                .font(AppFont.rounded(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: mixWithTransparent(tokens.accent, fractionOfFirst: 0.35), radius: 9, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        // 押しやすさのため、下部に適度な余白を確保する（ユーザー指定）。
        .padding(.bottom, 26)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 18,
                style: .continuous
            )
            .fill(tokens.surface2)
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: Color(.sRGB, red: 80 / 255, green: 65 / 255, blue: 40 / 255, opacity: 0.07),
                    radius: 7, x: 0, y: -3)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(tokens.hair).frame(height: 1)
        }
    }

    // MARK: - 閉じる確認オーバーレイ

    /// 閉じる確認のトップモーダル（常設 ZStack に if ＋ transition、.animation を直接付与）。
    private var confirmCloseOverlay: some View {
        ZStack(alignment: .bottom) {
            if model.confirmClose {
                let n = model.cartCount
                // removal transition 中の重なり順を保証するため zIndex を明示
                //（SheetContainer と同じちらつき対策）。
                Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 6 / 255, opacity: 0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { model.confirmClose = false }
                    .zIndex(0)
                VStack(alignment: .leading, spacing: 0) {
                    Text("かごに \(n)品 残っています")
                        .font(AppFont.rounded(size: 17, weight: .heavy))
                        .foregroundStyle(tokens.text)
                    Text("このまま閉じると、選んだ内容はクリアされます。")
                        .font(AppFont.rounded(size: 13.5, weight: .semibold))
                        .foregroundStyle(tokens.textSec)
                        .lineSpacing(3)
                        .padding(.top, 4)
                    VStack(spacing: 9) {
                        Button {
                            model.reset(store: store)
                            isPresented = false
                        } label: {
                            Text("かごを空にして閉じる")
                                .font(AppFont.rounded(size: 15.5, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(tokens.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        Button {
                            // 選ぶ画面にとどまる
                            model.confirmClose = false
                        } label: {
                            Text("キャンセル")
                                .font(AppFont.rounded(size: 14.5, weight: .bold))
                                .foregroundStyle(tokens.textSec)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 22,
                        style: .continuous
                    )
                    .fill(tokens.bg2)
                    .ignoresSafeArea(edges: .bottom)
                }
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: model.confirmClose)
        .allowsHitTesting(model.confirmClose)
    }

    // MARK: - 閉じる制御

    private func handleDismiss() {
        // 確認画面でスクリムタップ → 選ぶへ戻すのではなく、かご非空なら閉じ確認を出す
        // （プロトタイプ FKSheet onClose=requestClose と同じ。画面に関わらずかご基準で判断）。
        if model.requestClose() {
            isPresented = false
        }
    }
}
