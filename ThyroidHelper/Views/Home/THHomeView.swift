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
    @EnvironmentObject private var usageManager: THUsageManager
    @Query(sort: \THCheckupRecord.date, order: .reverse) private var records: [THCheckupRecord]
    @State private var showingAddRecord = false
    @State private var showingPremium = false
    
    // 修改为返回最近一天的所有记录
    var latestDayRecords: [THCheckupRecord] {
        guard let latestDate = records.first?.date else { return [] }
        
        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latestDate)
        
        return records.filter { record in
            let recordDay = calendar.startOfDay(for: record.date)
            return calendar.isDate(recordDay, inSameDayAs: latestDay)
        }
    }
    
    // 为了兼容现有代码，保留 latestRecord 但改为使用最近一天记录中的第一条
    var latestRecord: THCheckupRecord? {
        latestDayRecords.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // 复查提醒卡片
                    CheckupReminderCard(latestRecord: latestRecord)
                        .padding(.vertical, 8)
                    
                    // 最新检查结果 - 显示最近一天的所有记录
                    if !latestDayRecords.isEmpty {
                        LatestDayResultsCard(records: latestDayRecords)
                    } else {
                        EmptyStateCard()
                    }
                    
                    // 快速操作按钮
                    QuickActionButtons(showingAddRecord: $showingAddRecord, onAddRecord: addNewRecordAction)
                }
                .padding()
            }
            .navigationTitle("app_title".localized)
            .sheet(isPresented: $showingAddRecord) {
                THAddIndicatorView()
                    .onDisappear {
                        usageManager.syncRecordCount()
                    }
            }
            .sheet(isPresented: $showingPremium) {
                THPremiumView()
            }
        }
    }
    
    private func addNewRecordAction() {
        if usageManager.canAddNewRecord() {
            showingAddRecord = true
        } else {
            showingPremium = true
        }
    }
}

// 新增：显示最近一天的所有检查结果
struct LatestDayResultsCard: View {
    let records: [THCheckupRecord]
    
    private var latestDate: String {
        guard let date = records.first?.date else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("latest_examination_results".localized)
                    .font(.headline)
                
                Text("examination_count_format".localized(latestDate, records.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 按检查类型分组显示
            ForEach(groupedRecords, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    if records.count > 1 {
                        Text(group.key)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 6) {
                        ForEach(group.value.flatMap { $0.indicators ?? [] }.sortedByMedicalOrder(), id: \.name) { indicator in
                            IndicatorCard(indicator: indicator)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // 按检查类型分组
    private var groupedRecords: [(key: String, value: [THCheckupRecord])] {
        let grouped = Dictionary(grouping: records) { $0.type.localizedName }
        return grouped.sorted { $0.key < $1.key }
    }
}

struct CheckupReminderCard: View {
    let latestRecord: THCheckupRecord?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THReminderSetting.lastUpdated, order: .reverse)
    private var reminderSettings: [THReminderSetting]
    
    @State private var showingDatePicker = false
    @State private var showHint = false
    @State private var refreshID = UUID()
    
    // 获取甲状腺复查的设置（默认使用甲功五项）
    private var thyroidSetting: THReminderSetting {
        if let existing = reminderSettings.setting(for: .thyroidFunction5) {
            return existing
        }
        
        // 创建新设置
        let newSetting = THReminderSetting(checkupType: .thyroidFunction5)
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
        
        Task {
            await  THNotificationManager.shared.updateNotificationByCheckupDateChange()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("next_checkup_reminder".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if thyroidSetting.isCustomReminderEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .accessibilityLabel("custom_reminder_set".localized)
                        }
                    }
                    
                    if let days = daysUntilCheckup {
                        if days > 0 {
                            Text("days_until_checkup_format".localized(days))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            Text("time_for_checkup".localized)
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .fontWeight(.bold)
                        }
                    } else {
                        Text("add_record_to_start_tracking".localized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if let nextDate = formattedNextCheckupDate {
                        Text("next_checkup_date_format".localized(nextDate))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // 提示文本
                    if showHint && !thyroidSetting.isCustomReminderEnabled {
                        Text("tap_to_set_custom_reminder".localized)
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

// 更新的日期选择器视图 - 支持时间选择
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
                    Toggle("enable_custom_reminder".localized, isOn: $isEnabled)
                    
                    if isEnabled {
                        DatePicker(
                            "checkup_date".localized,
                            selection: $selectedDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                    }
                } header: {
                    Text("custom_reminder_header_format".localized(reminderSetting.checkupType.displayName))
                } footer: {
                    Text("custom_reminder_footer".localized)
                }
            }
            .navigationTitle("set_reminder_title_format".localized(reminderSetting.checkupType.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveSettings()
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // 设置选定日期的时间
    private func setTimeToDate(hour: Int, minute: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
        components.hour = hour
        components.minute = minute
        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
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
            print("save_reminder_error".localized + ": \(error)")
        }
    }
}

struct IndicatorCard: View {
    let indicator: THIndicatorRecord
    
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
            
            Text("reference_format".localized(indicator.normalRange))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundColorForStatus(indicator.status))
        .cornerRadius(12)
    }
    
    private func backgroundColorForStatus(_ status: THIndicatorRecord.IndicatorStatus) -> Color {
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
            
            Text("no_examination_records".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("add_first_record_prompt".localized)
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
    let onAddRecord: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onAddRecord) {
                Label("add_checkup_indicator".localized, systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
            
            NavigationLink(destination: THTrendsView()) {
                Label("view_trends".localized, systemImage: "chart.line.uptrend.xyaxis")
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
