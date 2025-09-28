//
//  ThyroidHelperApp.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct ThyroidHelperApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            THCheckupRecord.self,
            THIndicatorRecord.self,
            THReminderSetting.self,
            THHistoryRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("数据库位置: \(modelConfiguration.url)")
            THDatabaseManager.clearEntity(THReminderSetting.self, in: container.mainContext)
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
                .onAppear {
                    setupNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupNotifications() {
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = THNotificationDelegate.shared
        
        // 初始化通知管理器
        THNotificationManager.shared.initialize(with: sharedModelContainer)
    }
}

// MARK: - 简化的通知代理
class THNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = THNotificationDelegate()
    
    // 前台显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // 处理用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        THNotificationManager.shared.handleNotificationResponse(response)
        completionHandler()
    }
}
