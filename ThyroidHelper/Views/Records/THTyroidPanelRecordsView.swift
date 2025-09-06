//
//  THTyroidPanelRecordsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import _SwiftData_SwiftUI

struct THTyroidPanelRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THCheckupRecord.date, order: .reverse) private var records: [THCheckupRecord]
    @State private var showingAddRecord = false
    @State private var recordToEdit: THCheckupRecord?
    
    var body: some View {
        NavigationView {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "暂无检查记录",
                        systemImage: "doc.text",
                        description: Text("添加您的第一条检查记录")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            RecordRowView(record: record) {
                                recordToEdit = record
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("甲功五项")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRecord = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            THAddRecordView()
        }
        .sheet(item: $recordToEdit) { record in
            EditRecordView(record: record)
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(records[index])
            }
            try? modelContext.save()
        }
    }
}

struct RecordRowView: View {
    let record: THCheckupRecord
    let onEdit: () -> Void
    
    // 根据检查类型获取对应的指标配置
    private var indicatorsForType: [THThyroidIndicator] {
        let indicatorNames = THConfig.indicatorsForType(record.type)
        return (record.indicators ?? [])
            .filter { indicatorNames.contains($0.name) }
            .sortedByMedicalOrder()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // 状态指示器
                    HStack(spacing: 4) {
                        if let abnormalCount = record.indicators?.filter { $0.status != .normal }.count {
                            if abnormalCount > 0 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("\(abnormalCount)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // 编辑按钮
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 指标概览 - 根据检查类型显示对应的指标
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(indicatorsForType, id: \.name) { indicator in
                    VStack(spacing: 2) {
                        Text(indicator.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        Text(indicator.value, format: .number.precision(.fractionLength(THConfig.decimalPlaces(for: indicator.name))))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(colorForStatus(indicator.status))
                        
                        // 显示标准正常范围
                        if let normalRange = indicator.standardNormalRange {
                            Text("\(normalRange.0, specifier: "%.2f")-\(normalRange.1, specifier: "%.2f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(backgroundColorForStatus(indicator.status))
                    .cornerRadius(6)
                }
            }
            
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func colorForStatus(_ status: THThyroidIndicator.IndicatorStatus) -> Color {
        switch status {
        case .normal: return .green
        case .high: return .red
        case .low: return .blue
        }
    }
    
    private func backgroundColorForStatus(_ status: THThyroidIndicator.IndicatorStatus) -> Color {
        switch status {
        case .normal: return .green.opacity(0.1)
        case .high: return .red.opacity(0.1)
        case .low: return .blue.opacity(0.1)
        }
    }
}

// MARK: - 编辑记录视图
struct EditRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let record: THCheckupRecord
    
    @State private var selectedDate: Date
    @State private var notes: String
    @State private var indicators: [String: IndicatorInput] = [:]
    
    struct IndicatorInput {
        var value: String = ""
        var unit: String
        var normalRange: String
        var isValid: Bool { !value.isEmpty && Double(value) != nil }
        var doubleValue: Double { Double(value) ?? 0 }
    }
    
    init(record: THCheckupRecord) {
        self.record = record
        _selectedDate = State(initialValue: record.date)
        _notes = State(initialValue: record.notes ?? "")
    }
    
    // 根据记录类型获取对应的指标
    private var indicatorsForType: [String] {
        THConfig.indicatorsForType(record.type)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("检查信息") {
                    DatePicker("检查日期", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section {
                    ForEach(indicatorsForType, id: \.self) { indicatorName in
                        IndicatorEditRow(
                            name: indicatorName,
                            input: Binding(
                                get: { indicators[indicatorName] ?? defaultIndicatorInput(for: indicatorName) },
                                set: { indicators[indicatorName] = $0 }
                            )
                        )
                    }
                }
                
                Section("备注") {
                    TextField("添加备注信息...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(record.type.rawValue) // 使用检查类型作为导航栏标题
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveChanges() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                setupIndicatorsFromRecord()
            }
        }
    }
    
    private var canSave: Bool {
        indicatorsForType.allSatisfy { indicatorName in
            guard let input = indicators[indicatorName] else { return false }
            return input.isValid
        }
    }
    
    private func setupIndicatorsFromRecord() {
        indicators.removeAll()
        
        // 从现有记录中加载数据
        for indicator in (record.indicators ?? []).sortedByMedicalOrder() {
            let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
            indicators[indicator.name] = IndicatorInput(
                value: String(format: "%.\(decimalPlaces)f", indicator.value),
                unit: indicator.unit,
                normalRange: indicator.normalRange
            )
        }
        
        // 确保当前类型的所有指标都存在（如果缺少则添加默认值）
        for indicatorName in indicatorsForType {
            if indicators[indicatorName] == nil {
                indicators[indicatorName] = defaultIndicatorInput(for: indicatorName)
            }
        }
    }
    
    private func defaultIndicatorInput(for name: String) -> IndicatorInput {
        // 使用扩展中的标准配置
        let tempIndicator = THThyroidIndicator(name: name, value: 0, unit: "", normalRange: "", status: .normal)
        let normalRange = tempIndicator.standardNormalRange
        let rangeString = normalRange.map { "\($0.0)-\($0.1)" } ?? ""
        
        return IndicatorInput(
            unit: tempIndicator.standardUnit,
            normalRange: rangeString
        )
    }
    
    private func saveChanges() {
        // 更新记录基本信息
        record.date = selectedDate
        record.notes = notes.isEmpty ? nil : notes
        
        // 清除现有指标
        if let existingIndicators = record.indicators {
            for indicator in existingIndicators {
                modelContext.delete(indicator)
            }
        }
        record.indicators = []
        
        // 添加新指标（只保存当前类型对应的指标）
        for indicatorName in indicatorsForType {
            guard let input = indicators[indicatorName], input.isValid else { continue }
            
            let status = THThyroidIndicator.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
            let indicator = THThyroidIndicator(
                name: indicatorName,
                value: input.doubleValue,
                unit: input.unit,
                normalRange: input.normalRange,
                status: status
            )
            indicator.checkupRecord = record
            record.indicators?.append(indicator)
            modelContext.insert(indicator)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("保存失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 编辑指标输入行
struct IndicatorEditRow: View {
    let name: String
    @Binding var input: EditRecordView.IndicatorInput
    
    // 使用扩展获取完整显示名称
    private var displayName: String {
        let tempIndicator = THThyroidIndicator(name: name, value: 0, unit: "", normalRange: "", status: .normal)
        return tempIndicator.fullDisplayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.headline)
            
            HStack {
                TextField("数值", text: $input.value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                
                Text(input.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
            }
            
            Text("参考范围: \(input.normalRange)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
