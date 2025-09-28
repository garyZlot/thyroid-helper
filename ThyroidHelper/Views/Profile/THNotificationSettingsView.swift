//
//  THNotificationSettingsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import UserNotifications

struct THNotificationSettingsView: View {
    @State private var enableReminders = true
    @State private var reminderDays = 14
    @State private var dailyReminder = false
    @State private var reminderTime = Date()
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var isLoading = false
    
    // UserDefaults keys
    private let enableRemindersKey = "EnableCheckupReminders"
    private let reminderDaysKey = "CheckupReminderDays"
    private let dailyReminderKey = "EnableDailyReminder"
    private let reminderTimeKey = "DailyReminderTime"
    
    var body: some View {
        NavigationView {
            Form {
                // 权限状态部分
                if notificationPermissionStatus != .authorized {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "bell.slash.fill")
                                    .foregroundColor(.orange)
                                Text("notification_permission_required".localized)
                                    .fontWeight(.medium)
                            }
                            
                            Text("notification_permission_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("enable_notifications".localized) {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 复查提醒设置
                Section("checkup_reminders".localized) {
                    Toggle("enable_checkup_reminders".localized, isOn: $enableReminders)
                        .onChange(of: enableReminders) { oldValue, newValue in
                            saveSettings()
                            if newValue {
                                scheduleCheckupReminders()
                            } else {
                                cancelCheckupReminders()
                            }
                        }
                    
                    if enableReminders {
                        HStack {
                            Text("advance_reminder".localized)
                            Spacer()
                            Picker("days".localized, selection: $reminderDays) {
                                Text("1_day".localized).tag(1)
                                Text("3_days".localized).tag(3)
                                Text("7_days".localized).tag(7)
                                Text("14_days".localized).tag(14)
                                Text("30_days".localized).tag(30)
                            }
                            .pickerStyle(.menu)
                            .onChange(of: reminderDays) { oldValue, newValue in
                                saveSettings()
                                if enableReminders {
                                    scheduleCheckupReminders()
                                }
                            }
                        }
                        
                        Text("checkup_reminder_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(notificationPermissionStatus != .authorized)
                
                // 日常提醒设置
                Section("daily_reminders".localized) {
                    Toggle("daily_medication_reminder".localized, isOn: $dailyReminder)
                        .onChange(of: dailyReminder) { oldValue, newValue in
                            saveSettings()
                            if newValue {
                                scheduleDailyReminders()
                            } else {
                                cancelDailyReminders()
                            }
                        }
                    
                    if dailyReminder {
                        DatePicker("reminder_time".localized, selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { oldValue, newValue in
                                saveSettings()
                                if dailyReminder {
                                    scheduleDailyReminders()
                                }
                            }
                        
                        Text("daily_reminder_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(notificationPermissionStatus != .authorized)
                

                
                // 说明信息
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("notification_settings_info".localized)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        if notificationPermissionStatus != .authorized {
                            Text("notification_permission_note".localized)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("notification_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadSettings()
                checkNotificationPermission()
            }
            .alert("permission_denied".localized, isPresented: $showingPermissionAlert) {
                Button("go_to_settings".localized) {
                    openAppSettings()
                }
                Button("cancel".localized, role: .cancel) {}
            } message: {
                Text("permission_denied_message".localized)
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        enableReminders = UserDefaults.standard.bool(forKey: enableRemindersKey)
        reminderDays = UserDefaults.standard.object(forKey: reminderDaysKey) as? Int ?? 14
        dailyReminder = UserDefaults.standard.bool(forKey: dailyReminderKey)
        
        if let timeData = UserDefaults.standard.data(forKey: reminderTimeKey),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            reminderTime = time
        } else {
            // 默认时间为早上8点
            let calendar = Calendar.current
            let components = DateComponents(hour: 8, minute: 0)
            reminderTime = calendar.date(from: components) ?? Date()
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(enableReminders, forKey: enableRemindersKey)
        UserDefaults.standard.set(reminderDays, forKey: reminderDaysKey)
        UserDefaults.standard.set(dailyReminder, forKey: dailyReminderKey)
        
        if let timeData = try? JSONEncoder().encode(reminderTime) {
            UserDefaults.standard.set(timeData, forKey: reminderTimeKey)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Permission Management
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    private func requestNotificationPermission() {
        isLoading = true
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if granted {
                    self.notificationPermissionStatus = .authorized
                    // 权限获取成功后，如果相关设置已开启，则安排通知
                    if self.enableReminders {
                        self.scheduleCheckupReminders()
                    }
                    if self.dailyReminder {
                        self.scheduleDailyReminders()
                    }
                } else {
                    self.notificationPermissionStatus = .denied
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Notification Scheduling
    
    private func scheduleCheckupReminders() {
        guard notificationPermissionStatus == .authorized else { return }
        
        // 取消现有的复查提醒
        cancelCheckupReminders()
        
        // 这里需要根据最新的检查记录来计算提醒时间
        // 由于我们在View中，无法直接访问SwiftData，所以发送通知给NotificationCenter
        NotificationCenter.default.post(
            name: NSNotification.Name("ScheduleCheckupReminders"),
            object: nil,
            userInfo: ["reminderDays": reminderDays]
        )
    }
    
    private func cancelCheckupReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["checkup_reminder_thyroid", "checkup_reminder_thyroglobulin"])
    }
    
    private func scheduleDailyReminders() {
        guard notificationPermissionStatus == .authorized else { return }
        
        // 取消现有的日常提醒
        cancelDailyReminders()
        
        let content = UNMutableNotificationContent()
        content.title = "daily_medication_reminder_title".localized
        content.body = "daily_medication_reminder_body".localized
        content.sound = .default
        content.badge = 1
        
        // 设置每日重复提醒
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_medication_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error)")
            }
        }
    }
    
    private func cancelDailyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_medication_reminder"])
    }
    
    private func sendTestNotification() {
        THNotificationManager.shared.sendTestNotification()
    }
}

// MARK: - Notification Manager Extension
extension THNotificationSettingsView {
    
    /// 静态方法：根据检查记录安排复查提醒
    static func scheduleCheckupReminders(for records: [THCheckupRecord], reminderDays: Int = 14) {
        guard UserDefaults.standard.bool(forKey: "EnableCheckupReminders") else { return }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            
            // 取消现有提醒
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["checkup_reminder_thyroid", "checkup_reminder_thyroglobulin"]
            )
            
            // 按类型分组记录
            let groupedRecords = Dictionary(grouping: records) { $0.type }
            
            for (checkupType, typeRecords) in groupedRecords {
                guard let latestRecord = typeRecords.max(by: { $0.date < $1.date }) else { continue }
                
                // 计算下次复查日期（根据检查类型的默认间隔）
                let nextCheckupDate = Calendar.current.date(
                    byAdding: checkupType.defaultInterval,
                    to: latestRecord.date
                ) ?? Date()
                
                // 计算提醒日期（提前指定天数）
                let reminderDate = Calendar.current.date(
                    byAdding: .day,
                    value: -reminderDays,
                    to: nextCheckupDate
                ) ?? Date()
                
                // 只有当提醒日期在未来时才安排通知
                if reminderDate > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = "checkup_reminder_title".localized
                    content.body = String(format: "checkup_reminder_body_format".localized,
                                        checkupType.localizedName,
                                        DateFormatter.localizedString(from: nextCheckupDate, dateStyle: .medium, timeStyle: .none))
                    content.sound = .default
                    content.badge = 1
                    content.categoryIdentifier = "CHECKUP_REMINDER"
                    
                    let trigger = UNCalendarNotificationTrigger(
                        dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
                        repeats: false
                    )
                    
                    let identifier = "checkup_reminder_\(checkupType.rawValue)"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Error scheduling checkup reminder: \(error)")
                        }
                    }
                }
            }
        }
    }
}

