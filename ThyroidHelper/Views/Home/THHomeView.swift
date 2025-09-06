//
//  THHomeView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData

struct THHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THCheckupRecord.date, order: .reverse) private var records: [THCheckupRecord]
    @State private var showingAddRecord = false
    
    var latestRecord: THCheckupRecord? {
        records.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // 复查提醒卡片
                    CheckupReminderCard(latestRecord: latestRecord)
                        .padding(.vertical, 8)
                    
                    // 最新检查结果
                    if let record = latestRecord {
                        LatestResultCard(record: record)
                    } else {
                        EmptyStateCard()
                    }
                    
                    // 快速操作按钮
                    QuickActionButtons(showingAddRecord: $showingAddRecord)
                }
                .padding()
            }
            .navigationTitle("甲状腺助手")
            .sheet(isPresented: $showingAddRecord) {
                THAddRecordView()
            }
        }
    }
}

struct CheckupReminderCard: View {
    let latestRecord: THCheckupRecord?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THReminderSetting.lastUpdated, order: .reverse)
    private var reminderSettings: [THReminderSetting]
    
    @State private var showingDatePicker = false
    @State private var showHint = true
    @State private var refreshID = UUID()
    
    // 获取甲状腺复查的设置（默认使用甲功五项）
    private var thyroidSetting: THReminderSetting {
        if let existing = reminderSettings.setting(for: .comprehensive) {
            return existing
        }
        
        // 创建新设置
        let newSetting = THReminderSetting(checkupType: .comprehensive)
        modelContext.insert(newSetting)
        try? modelContext.save()
        return newSetting
    }
    
    // 计算下次复查日期
    private var nextCheckupDate: Date? {
        thyroidSetting.nextReminderDate(basedOn: latestRecord?.date)
    }
    
    private func updateView() {
        refreshID = UUID()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("下次复查提醒")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if thyroidSetting.isCustomReminderEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .accessibilityLabel("已设置自定义提醒")
                        }
                    }
                    
                    if let days = daysUntilCheckup {
                        if days > 0 {
                            Text("距离下次检查还有")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            + Text(" \(days) ")
                                .font(.headline)
                                .foregroundColor(.orange)
                            + Text("天")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            Text("该复查了！")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .fontWeight(.bold)
                        }
                    } else {
                        Text("添加检查记录开始追踪")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if let nextDate = formattedNextCheckupDate {
                        Text("下次检查日期：\(nextDate)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // 提示文本
                    if showHint && !thyroidSetting.isCustomReminderEnabled {
                        Text("点击此处设置自定义提醒")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .id(refreshID)
        .padding()
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .onTapGesture {
            showingDatePicker = true
        }
        .sheet(isPresented: $showingDatePicker) {
            ReminderDatePickerView(
                isPresented: $showingDatePicker,
                reminderSetting: thyroidSetting,
                showHint: $showHint,
                onSave: updateView
            )
        }
        .onAppear {
            // 应用启动3秒后隐藏提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showHint = false
                }
            }
        }
    }
    
    // 计算距离复查的天数
    private var daysUntilCheckup: Int? {
        guard let nextDate = nextCheckupDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day
    }
    
    // 格式化日期显示
    private var formattedNextCheckupDate: String? {
        guard let date = nextCheckupDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if formatter.locale.identifier.starts(with: "zh") {
            formatter.dateFormat = "yyyy年MM月dd日"
        }
        
        return formatter.string(from: date)
    }
}

// 更新日期选择器视图
struct ReminderDatePickerView: View {
    @Binding var isPresented: Bool
    @State var selectedDate: Date
    @State var isEnabled: Bool
    let reminderSetting: THReminderSetting
    @Binding var showHint: Bool
    var onSave: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    
    init(isPresented: Binding<Bool>,
         reminderSetting: THReminderSetting,
         showHint: Binding<Bool>,
         onSave: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.reminderSetting = reminderSetting
        self._selectedDate = State(initialValue: reminderSetting.customReminderDate ?? Date())
        self._isEnabled = State(initialValue: reminderSetting.isCustomReminderEnabled)
        self._showHint = showHint
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("启用自定义提醒", isOn: $isEnabled)
                    
                    if isEnabled {
                        DatePicker(
                            "复查日期",
                            selection: $selectedDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                    }
                } header: {
                    Text("自定义\(reminderSetting.checkupType.displayName)提醒")
                } footer: {
                    Text("开启后，将使用您设置的日期作为复查提醒，而不是自动计算的日期。")
                }
            }
            .navigationTitle("设置\(reminderSetting.checkupType.displayName)提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSettings()
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        reminderSetting.customReminderDate = isEnabled ? selectedDate : nil
        reminderSetting.isCustomReminderEnabled = isEnabled
        reminderSetting.lastUpdated = Date()
        
        // 保存后隐藏提示
        showHint = false
        
        // 尝试保存到上下文
        do {
            try modelContext.save()
            onSave?()
        } catch {
            print("保存提醒设置失败: \(error)")
        }
    }
}

struct LatestResultCard: View {
    let record: THCheckupRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text("最新检查结果")
                    .font(.headline)
                
                Text("\(record.date.formatted(date: .abbreviated, time: .omitted)) · \(record.type.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 6) {
                ForEach((record.indicators ?? []).sortedByMedicalOrder(), id: \.name) { indicator in
                    IndicatorCard(indicator: indicator)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct IndicatorCard: View {
    let indicator: THThyroidIndicator
    
    var body: some View {
        VStack(spacing: 4) {
            Text(indicator.name)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(indicator.value, format: .number.precision(.fractionLength(THConfig.decimalPlaces(for: indicator.name))))
                .font(.title3)
                .fontWeight(.bold)
            
            Text(indicator.unit)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("参考: \(indicator.normalRange)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundColorForStatus(indicator.status))
        .cornerRadius(12)
    }
    
    private func backgroundColorForStatus(_ status: THThyroidIndicator.IndicatorStatus) -> Color {
        switch status {
        case .normal:
            return Color.green.opacity(0.1)
        case .high:
            return Color.red.opacity(0.1)
        case .low:
            return Color.blue.opacity(0.1)
        }
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("暂无检查记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("添加您的第一条检查记录开始健康管理")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct QuickActionButtons: View {
    @Binding var showingAddRecord: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: { showingAddRecord = true }) {
                Label("拍照录入", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
            
            NavigationLink(destination: THTrendsView()) {
                Label("查看趋势", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
        }
    }
}
