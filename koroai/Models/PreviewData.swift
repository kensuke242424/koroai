// SwiftUI Preview 用の in-memory コンテナ。SeedData を投入し、達成カードの数字が出るよう ate ログも入れる。
// 本番起動には一切関与しない（Preview / 開発時のみ）。

import Foundation
import SwiftData

enum PreviewData {
    /// SeedData 7品＋当月 ate ログ12件を投入した in-memory コンテナ。
    @MainActor static let container: ModelContainer = {
        let schema = Schema([FoodItem.self, ConsumptionLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        for item in SeedData.previewItems() {
            context.insert(item)
        }
        for cat in ["fish", "leafy", "veg", "dairy", "tofu", "egg", "chicken", "meat", "fruit", "mush", "bread", "deli"] {
            context.insert(ConsumptionLog(catId: cat, action: .ate))
        }
        return container
    }()
}
