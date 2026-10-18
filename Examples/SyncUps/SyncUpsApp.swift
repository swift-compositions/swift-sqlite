import SQLiteData
import SwiftUI

@main
struct SyncUpsApp: App {
    static let model = AppModel()

    init() {
        if !isTesting {
            do {
                try prepareDependencies {
                    try $0.bootstrapDatabase()
                }
            } catch {
                fatalError("\(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if !isTesting {
                AppView(model: Self.model)
            }
        }
    }
}
