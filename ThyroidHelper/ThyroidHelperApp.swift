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
            CheckupRecord.self,
            ThyroidIndicator.self,
            ReminderSetting.self,
            MedicalHistoryRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // 打印数据库位置（仅调试用）
            let url = modelConfiguration.url
            print("数据库位置: \(url)")
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
