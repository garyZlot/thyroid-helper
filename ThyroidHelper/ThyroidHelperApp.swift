//
//  ThyroidHelperApp.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData

@main
struct ThyroidHelperApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            THThyroidPanelRecord.self,
            THThyroidIndicator.self,
            THReminderSetting.self,
            THMedicalTimelineRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("数据库位置: \(modelConfiguration.url)")
            THDatabaseManager.migrateDatabase(modelContext: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            THContentView()
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
        .modelContainer(sharedModelContainer)
    }
}
