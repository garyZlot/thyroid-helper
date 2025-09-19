//
//  THDatabaseManager.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/19.
//

import SwiftData
import Foundation

struct THDatabaseManager {
    static func migrateDatabase(modelContext: ModelContext) {
        let key = "hasMigratedCheckupType"
        guard !UserDefaults.standard.bool(forKey: key) else {
            print("迁移已完成，跳过。")
            return
        }
        
        do {
            // 迁移 THThyroidPanelRecord
            let panelDescriptor = FetchDescriptor<THThyroidPanelRecord>()
            let panelRecords = try modelContext.fetch(panelDescriptor)
            print("找到 \(panelRecords.count) 条 THThyroidPanelRecord 记录需要迁移。")
            
            for record in panelRecords {
                if record.id.isEmpty {
                    record.id = UUID().uuidString
                    print("为 THThyroidPanelRecord 分配新 ID: \(record.id)")
                }
                modelContext.insert(record) // 更新记录
            }
            
            // 迁移 THReminderSetting
            let reminderDescriptor = FetchDescriptor<THReminderSetting>()
            let reminderRecords = try modelContext.fetch(reminderDescriptor)
            print("找到 \(reminderRecords.count) 条 THReminderSetting 记录需要迁移。")
            
            for reminder in reminderRecords {
                if reminder.id == UUID(uuid: UUID_NULL) {
                    reminder.id = UUID()
                    print("为 THReminderSetting 分配新 ID: \(reminder.id)")
                }
                modelContext.insert(reminder) // 更新记录
            }
            
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: key)
            print("数据库迁移成功，更新了 \(panelRecords.count) 条 THThyroidPanelRecord 和 \(reminderRecords.count) 条 THReminderSetting 记录。")
        } catch {
            print("迁移失败: \(error)")
        }
    }
}
