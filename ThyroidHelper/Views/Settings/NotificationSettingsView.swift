//
//  NotificationSettingsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI

struct NotificationSettingsView: View {
    @State private var enableReminders = true
    @State private var reminderDays = 14
    @State private var dailyReminder = false
    @State private var reminderTime = Date()
    
    var body: some View {
        Form {
            Section("复查提醒") {
                Toggle("开启复查提醒", isOn: $enableReminders)
                
                if enableReminders {
                    HStack {
                        Text("提前提醒")
                        Spacer()
                        Picker("天数", selection: $reminderDays) {
                            Text("7天").tag(7)
                            Text("14天").tag(14)
                            Text("30天").tag(30)
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            
            Section("日常提醒") {
                Toggle("每日用药提醒", isOn: $dailyReminder)
                
                if dailyReminder {
                    DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
            }
            
            Section {
                Text("提醒功能需要您授权应用发送通知")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
