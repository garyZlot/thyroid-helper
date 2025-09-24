//
//  THNotificationSettingsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI

struct THNotificationSettingsView: View {
    @State private var enableReminders = true
    @State private var reminderDays = 14
    @State private var dailyReminder = false
    @State private var reminderTime = Date()
    
    var body: some View {
        Form {
            Section("checkup_reminders".localized) {
                Toggle("enable_checkup_reminders".localized, isOn: $enableReminders)
                
                if enableReminders {
                    HStack {
                        Text("advance_reminder".localized)
                        Spacer()
                        Picker("days".localized, selection: $reminderDays) {
                            Text("7_days".localized).tag(7)
                            Text("14_days".localized).tag(14)
                            Text("30_days".localized).tag(30)
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            Section("daily_reminders".localized) {
                Toggle("daily_medication_reminder".localized, isOn: $dailyReminder)
                
                if dailyReminder {
                    DatePicker("reminder_time".localized, selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }
            
            Section {
                Text("notification_permission_note".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("notification_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
