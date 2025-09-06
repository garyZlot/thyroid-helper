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
    @Query private var records: [THThyroidPanelRecord]
    
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
                            Text(authManager.user?.fullName ?? "用户")
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
                
                // 数据统计
                Section("数据统计") {
                    StatRow(title: "检查记录", value: "\(records.count) 条")
                    StatRow(title: "最近检查", value: lastCheckupText)
                    StatRow(title: "数据同步", value: cloudManager.isSignedInToiCloud ? "已开启" : "未开启")
                }
                
                // 设置选项
                Section("设置") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("通知设置", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: DataExportView()) {
                        Label("数据导出", systemImage: "square.and.arrow.up")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("关于应用", systemImage: "info.circle")
                    }
                }
                
                // 数据管理
                Section("数据管理") {
                    Button(action: { cloudManager.checkiCloudStatus() }) {
                        Label("刷新云端状态", systemImage: "icloud.and.arrow.down")
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Label("清除所有数据", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // 账户
                Section("账户") {
                    Button(action: { authManager.signOut() }) {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("个人中心")
        }
        .alert("清除数据", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确认清除", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("此操作将删除所有本地检查记录，且无法恢复。")
        }
    }
    
    private var lastCheckupText: String {
        guard let lastRecord = records.max(by: { $0.date < $1.date }) else {
            return "无记录"
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
