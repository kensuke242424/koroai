import SwiftUI
import SwiftData

@main
struct koroaiApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(container)
    }

    /// 永続コンテナ。FoodItem / ConsumptionLog を扱う。
    /// DEBUG かつ起動引数 "-seedPreviewData" のときだけ、空 DB に SeedData を投入する
    /// （プレビュー／スクショ用。本番起動には影響させない）。
    /// 注意: computed にすると body 再評価のたびに別コンテナが生成されうるため、stored で1つに固定する。
    private let container: ModelContainer = Self.makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([FoodItem.self, ConsumptionLog.self])
        do {
            let container = try ModelContainer(for: schema)
            #if DEBUG
            if CommandLine.arguments.contains("-seedPreviewData") {
                seedIfEmpty(container)
            }
            #endif
            return container
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }

    #if DEBUG
    /// 空 DB のときだけシードを投入する（既存データは壊さない）。
    @MainActor
    private static func seedIfEmpty(_ container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        guard existing.isEmpty else { return }
        for item in SeedData.previewItems() {
            context.insert(item)
        }
        // 達成カードの数字（当月 ate 件数）が出るよう、当月のダミー ate ログを投入。
        for cat in ["fish", "leafy", "veg", "dairy", "tofu", "egg", "chicken", "meat", "fruit", "mush", "bread", "deli"] {
            context.insert(ConsumptionLog(catId: cat, action: .ate))
        }
        try? context.save()
    }
    #endif
}
