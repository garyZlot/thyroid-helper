//
//  ProfileView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import _SwiftData_SwiftUI

struct THProfileView: View {
    @EnvironmentObject var authManager: THAuthenticationManager
    @EnvironmentObject var cloudManager: THCloudKitManager
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [THCheckupRecord]
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.user?.fullName ?? "user".localized)
                                .font(.headline)
                            
                            if let email = authManager.user?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(cloudManager.syncStatus)
                                .font(.caption)
                                .foregroundColor(cloudManager.isSignedInToiCloud ? .green : .orange)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
//                // 数据统计
//                Section("data_statistics".localized) {
//                    StatRow(title: "checkup_records".localized, value: String(format: "records_count_format".localized, records.count))
//                    StatRow(title: "recent_checkup".localized, value: lastCheckupText)
//                    StatRow(title: "data_sync".localized, value: cloudManager.isSignedInToiCloud ? "enabled".localized : "disabled".localized)
//                }
                
                // 设置选项
                Section("settings".localized) {
                    NavigationLink(destination: THNotificationSettingsView()) {
                        Label("notification_settings".localized, systemImage: "bell")
                    }
                    
                    NavigationLink(destination: THDataExportView()) {
                        Label("data_export".localized, systemImage: "square.and.arrow.up")
                    }
                    
                    NavigationLink(destination: THAboutView()) {
                        Label("about_app".localized, systemImage: "info.circle")
                    }
                }
                
                // 数据管理
                Section("data_management".localized) {
                    Button(action: { cloudManager.checkiCloudStatus() }) {
                        Label("refresh_cloud_status".localized, systemImage: "icloud.and.arrow.down")
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Label("clear_all_data".localized, systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // 账户
                Section("account".localized) {
                    Button(action: { authManager.signOut() }) {
                        Label("sign_out".localized, systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("personal_center".localized)
        }
        .alert("clear_data".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("confirm_clear".localized, role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("clear_data_warning".localized)
        }
    }
    
    private var lastCheckupText: String {
        guard let lastRecord = records.max(by: { $0.date < $1.date }) else {
            return "no_records".localized
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastRecord.date, relativeTo: Date())
    }
    
    private func clearAllData() {
        records.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
