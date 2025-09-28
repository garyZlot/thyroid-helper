//
//  THNotificationManager.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/27.
//

import Foundation
import UserNotifications
import SwiftData
import UIKit

class THNotificationManager: ObservableObject {
    static let shared = THNotificationManager()
    private var modelContainer: ModelContainer?
    
    private init() {
        setupNotificationCategories()
        observeSettingsChanges()
    }
    
    // 由 App 调用，传入 ModelContainer
    func initialize(with container: ModelContainer) {
        self.modelContainer = container
        
        // 应用启动时自动更新通知
        Task {
            await refreshNotifications()
        }
        
        // 监听应用状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        Task {
            await refreshNotifications()
        }
    }
    
    // MARK: - Setup
    
    func setupNotificationCategories() {
        let checkupAction = UNNotificationAction(
            identifier: "VIEW_CHECKUP",
            title: "view_checkup_reminder".localized,
            options: [.foreground]
        )
        
        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_REMINDER",
            title: "postpone_reminder".localized,
            options: []
        )
        
        let checkupCategory = UNNotificationCategory(
            identifier: "CHECKUP_REMINDER",
            actions: [checkupAction, postponeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([checkupCategory])
    }
    
    public func updateNotificationByCheckupDateChange() async {
        await self.updateCheckupRemindersWithDays(nil)
    }
    
    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleCheckupRemindersFromNotification(_:)),
            name: NSNotification.Name("ScheduleCheckupReminders"),
            object: nil
        )
    }
    
    @objc private func scheduleCheckupRemindersFromNotification(_ notification: Notification) {
        guard let reminderDays = notification.userInfo?["reminderDays"] as? Int else { return }
        
        // 从数据库获取最新数据并更新通知
        Task {
            await updateCheckupRemindersWithDays(reminderDays)
        }
    }
    
    @MainActor
    private func updateCheckupRemindersWithDays(_ reminderDays: Int?) async {
        guard let container = modelContainer else {
            print("ModelContainer not available")
            return
        }
        
        let context = container.mainContext
        
        do {
            // 获取提醒设置
            let reminderRequest = FetchDescriptor<THReminderSetting>(
                sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
            )
            let reminderSettings = try context.fetch(reminderRequest)
            
            // 获取检查记录
            let recordsRequest = FetchDescriptor<THCheckupRecord>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let checkupRecords = try context.fetch(recordsRequest)
            
            // 声明变量并设置默认值
            var aheadReminderDays: Int = 7

            // 如果有新值则更新并保存
            if let newReminderDays = reminderDays {
                aheadReminderDays = newReminderDays
                UserDefaults.standard.set(aheadReminderDays, forKey: "CheckupReminderDays")
            } else {
                aheadReminderDays = UserDefaults.standard.integer(forKey: "CheckupReminderDays")
                if aheadReminderDays == 0 {
                    aheadReminderDays = 7
                }
            }
            
            // 重新安排提醒
            scheduleCheckupReminders(with: reminderSettings, checkupRecords: checkupRecords)
            
            print("已根据新的提前天数(\(aheadReminderDays)天)更新复查提醒")
            
        } catch {
            print("更新复查提醒失败: \(error)")
        }
    }
    
    // MARK: - Permission Management
    
    func requestPermissionIfNeeded() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                return granted
            } catch {
                print("Failed to request notification permission: \(error)")
                return false
            }
        case .denied, .provisional, .ephemeral:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Checkup Reminders
    
    func scheduleCheckupReminders(with reminderSettings: [THReminderSetting], checkupRecords: [THCheckupRecord]) {
        guard UserDefaults.standard.bool(forKey: "EnableCheckupReminders") else {
            cancelAllCheckupReminders()
            return
        }
        
        let reminderDays = UserDefaults.standard.object(forKey: "CheckupReminderDays") as? Int ?? 14
        
        Task {
            let hasPermission = await requestPermissionIfNeeded()
            guard hasPermission else { return }
            
            // 取消现有提醒
            cancelAllCheckupReminders()
            
            // 为每种检查类型安排提醒
            for setting in reminderSettings where setting.isActive {
                scheduleReminderForType(setting, records: checkupRecords, advanceDays: reminderDays)
            }
        }
    }
    
    private func scheduleReminderForType(_ setting: THReminderSetting, records: [THCheckupRecord], advanceDays: Int) {
        // 找到该类型的最新记录
        let typeRecords = records.filter { $0.type == setting.checkupType }
        guard let latestRecord = typeRecords.max(by: { $0.date < $1.date }) else { return }
        
        // 计算下次检查日期
        let nextCheckupDate: Date
        if let customDate = setting.nextReminderDate(basedOn: latestRecord.date) {
            nextCheckupDate = customDate
        } else {
            nextCheckupDate = Calendar.current.date(
                byAdding: setting.checkupType.defaultInterval,
                to: latestRecord.date
            ) ?? Date()
        }
        
        // 计算提醒日期
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -advanceDays,
            to: nextCheckupDate
        ) ?? Date()
        
        // 只有当提醒日期在未来时才安排通知
        guard reminderDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "checkup_reminder_title".localized
        content.body = String(format: "checkup_reminder_body_format".localized,
                            formatDate(nextCheckupDate))
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "CHECKUP_REMINDER"
        content.userInfo = [
            "checkupType": setting.checkupType.rawValue,
            "nextCheckupDate": nextCheckupDate.timeIntervalSince1970
        ]
        
        var reminderComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        reminderComponents.hour = 9
        reminderComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
        let identifier = "checkup_reminder_\(setting.checkupType.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling checkup reminder: \(error)")
            } else {
                if let scheduledDate = Calendar.current.date(from: reminderComponents) {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    print("Scheduled checkup reminder for \(setting.checkupType.localizedName) on \(dateFormatter.string(from: scheduledDate))")
                } else {
                    print("Scheduled checkup reminder for \(setting.checkupType.localizedName) but could not calculate date")
                }
            }
        }
    }
    
    private func cancelAllCheckupReminders() {
        let identifiers = [
            "checkup_reminder_thyroidFunction5",
            "checkup_reminder_thyroglobulin"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Daily Reminders
    
    func scheduleDailyReminders() {
        guard UserDefaults.standard.bool(forKey: "EnableDailyReminder") else {
            cancelDailyReminders()
            return
        }
        
        Task {
            let hasPermission = await requestPermissionIfNeeded()
            guard hasPermission else { return }
            
            // 取消现有的日常提醒
            cancelDailyReminders()
            
            let content = UNMutableNotificationContent()
            content.title = "daily_medication_reminder_title".localized
            content.body = "daily_medication_reminder_body".localized
            content.sound = .default
            content.badge = 1
            
            // 获取设定的提醒时间
            let reminderTime = getReminderTime()
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_medication_reminder", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling daily reminder: \(error)")
                } else {
                    print("Scheduled daily reminder at \(components.hour ?? 0):\(components.minute ?? 0)")
                }
            }
        }
    }
    
    private func cancelDailyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_medication_reminder"])
    }
    
    private func getReminderTime() -> Date {
        if let timeData = UserDefaults.standard.data(forKey: "DailyReminderTime"),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            return time
        } else {
            // 默认时间为早上8点
            let calendar = Calendar.current
            let components = DateComponents(hour: 8, minute: 0)
            return calendar.date(from: components) ?? Date()
        }
    }
    
    // MARK: - Utility
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if formatter.locale.identifier.starts(with: "zh") {
            formatter.dateFormat = "yyyy年MM月dd日"
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - Public API
    
    /// 更新所有通知设置
    func updateAllNotifications(with reminderSettings: [THReminderSetting], checkupRecords: [THCheckupRecord]) {
        scheduleCheckupReminders(with: reminderSettings, checkupRecords: checkupRecords)
        scheduleDailyReminders()
    }
    
    /// 发送测试通知
    func sendTestNotification() {
        Task {
            let hasPermission = await requestPermissionIfNeeded()
            guard hasPermission else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "test_notification_title".localized
            content.body = "test_notification_body".localized
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error sending test notification: \(error)")
                }
            }
        }
    }
    
    /// 获取当前待处理的通知数量
    func getPendingNotificationsCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
    
    // 处理通知响应（由代理调用）
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "VIEW_CHECKUP":
            // 发送导航通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToCheckup"),
                    object: nil,
                    userInfo: ["identifier": identifier]
                )
            }
            
        case "POSTPONE_REMINDER":
            postponeReminder(for: identifier, by: 7)
            
        case UNNotificationDefaultActionIdentifier:
            if identifier.contains("checkup_reminder") {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToCheckup"),
                        object: nil,
                        userInfo: ["identifier": identifier]
                    )
                }
            }
            
        default:
            break
        }
        
        // 更新角标
        Task {
            await updateAppBadge()
        }
    }
    
    // 刷新所有通知
    @MainActor
    private func refreshNotifications() async {
        guard let container = modelContainer else { return }
        
        let context = container.mainContext
        
        do {
            // 获取数据
            let reminderSettings = try context.fetch(FetchDescriptor<THReminderSetting>())
            let checkupRecords = try context.fetch(FetchDescriptor<THCheckupRecord>())
            
            // 更新通知
            updateAllNotifications(with: reminderSettings, checkupRecords: checkupRecords)
            
            // 更新角标
            await updateAppBadge()
            
        } catch {
            print("刷新通知失败: \(error)")
        }
    }
    
    private func updateAppBadge() async {
        let count = await getPendingNotificationsCount()
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    /// 延迟提醒（当用户点击延迟时调用）
    func postponeReminder(for identifier: String, by days: Int = 7) {
        // 先取消现有通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // 重新安排延迟后的通知
        let content = UNMutableNotificationContent()
        content.title = "postponed_reminder_title".localized
        content.body = "postponed_reminder_body".localized
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "CHECKUP_REMINDER"
        
        let postponedDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: postponedDate)
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier + "_postponed", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error postponing reminder: \(error)")
            }
        }
    }
}
