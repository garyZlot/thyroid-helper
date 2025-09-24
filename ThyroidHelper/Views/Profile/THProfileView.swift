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
    @State private var showingCloudAlert = false
    
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
                            
                            HStack(spacing: 4) {
                                Image(systemName: cloudManager.isSignedInToiCloud ? "icloud.fill" : "icloud.slash")
                                    .foregroundColor(cloudManager.statusColor)
                                    .font(.caption)
                                    // 添加状态变化动画
                                    .animation(.easeInOut(duration: 0.3), value: cloudManager.isSignedInToiCloud)
                                
                                Text(cloudManager.syncStatus)
                                    .font(.caption)
                                    .foregroundColor(cloudManager.statusColor)
                                    // 添加状态文本变化动画
                                    .animation(.easeInOut(duration: 0.3), value: cloudManager.syncStatus)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // 数据管理
                Section("data_management".localized) {
                    Button(action: {
                        if cloudManager.isSignedInToiCloud {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            cloudManager.checkiCloudStatus()
                        } else {
                            showingCloudAlert = true
                        }
                    }) {
                        HStack {
                            Image(systemName: cloudManager.actionButtonIcon)
                                .foregroundColor(cloudManager.isSignedInToiCloud ? .blue : .orange)
                                .scaleEffect(cloudManager.isRefreshing ? 0.9 : 1.0)
                                .opacity(cloudManager.isRefreshing ? 0.7 : 1.0)
                                .animation(
                                    cloudManager.isRefreshing ?
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true) :
                                    .easeInOut(duration: 0.3),
                                    value: cloudManager.isRefreshing
                                )
                            
                            Text(cloudManager.isRefreshing ? "refreshing".localized : cloudManager.actionButtonText)
                                .foregroundColor(cloudManager.isSignedInToiCloud ? .blue : .orange)
                                .animation(.easeInOut(duration: 0.3), value: cloudManager.isRefreshing)
                        }
                    }
                    .disabled(cloudManager.isRefreshing)
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Label("clear_all_data".localized, systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
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
                
                // 账户
                Section("account".localized) {
                    Button(action: { authManager.signOut() }) {
                        Label("sign_out".localized, systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("personal_center".localized)
            .refreshable {
                cloudManager.checkiCloudStatus()
            }
        }
        .alert("clear_data".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("confirm_clear".localized, role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("clear_data_warning_with_icloud".localized)
        }
        .alert("icloud_signin_required".localized, isPresented: $showingCloudAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("go_to_settings".localized) {
                cloudManager.requestiCloudPermission()
            }
        } message: {
            Text("icloud_signin_message".localized)
        }
        .alert("icloud_signin_required".localized, isPresented: $showingCloudAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("go_to_settings".localized) {
                cloudManager.requestiCloudPermission()
            }
        } message: {
            Text("icloud_signin_message".localized)
        }
        .onAppear {
            cloudManager.checkiCloudStatus()
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
