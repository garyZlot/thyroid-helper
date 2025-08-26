//
//  AddRecordView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI

struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedType = CheckupRecord.CheckupType.comprehensive
    @State private var notes = ""
    @State private var indicators: [String: IndicatorInput] = [:]
    @State private var showingCamera = false
    @State private var ocrMode = false
    
    struct IndicatorInput {
        var value: String = ""
        var unit: String
        var normalRange: String
        var isValid: Bool { !value.isEmpty && Double(value) != nil }
        var doubleValue: Double { Double(value) ?? 0 }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("检查信息") {
                    DatePicker("检查日期", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("检查类型", selection: $selectedType) {
                        ForEach(CheckupRecord.CheckupType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("录入方式") {
                    HStack(spacing: 20) {
                        Button(action: {
                            ocrMode = true
                            showingCamera = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("拍照识别")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(true) // OCR功能暂时禁用，需要Vision框架实现
                        
                        Button(action: { ocrMode = false }) {
                            VStack(spacing: 8) {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.title2)
                                Text("手动输入")
                                    .font(.caption)
                            }
                            .foregroundColor(ocrMode ? .secondary : .green)
                            .padding()
                            .background((ocrMode ? Color.gray : Color.green).opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                if !ocrMode {
                    Section("检查数值") {
                        ForEach(selectedType.defaultIndicators, id: \.self) { indicatorName in
                            IndicatorInputRow(
                                name: indicatorName,
                                input: Binding(
                                    get: { indicators[indicatorName] ?? defaultIndicatorInput(for: indicatorName) },
                                    set: { indicators[indicatorName] = $0 }
                                )
                            )
                        }
                    }
                }
                
                Section("备注") {
                    TextField("添加备注信息...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveRecord() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                setupDefaultIndicators()
            }
            .onChange(of: selectedType) { _, newType in
                setupDefaultIndicators()
            }
        }
    }
    
    private var canSave: Bool {
        !indicators.isEmpty && indicators.values.allSatisfy { $0.isValid }
    }
    
    private func setupDefaultIndicators() {
        indicators.removeAll()
        for indicatorName in selectedType.defaultIndicators {
            indicators[indicatorName] = defaultIndicatorInput(for: indicatorName)
        }
    }
    
    private func defaultIndicatorInput(for name: String) -> IndicatorInput {
        switch name {
        case "TSH":
            return IndicatorInput(unit: "mIU/L", normalRange: "0.27-4.2")
        case "FT3":
            return IndicatorInput(unit: "pmol/L", normalRange: "3.1-6.8")
        case "FT4":
            return IndicatorInput(unit: "pmol/L", normalRange: "12-22")
        case "TG":
            return IndicatorInput(unit: "ng/mL", normalRange: "3.5-77")
        case "TPO":
            return IndicatorInput(unit: "IU/mL", normalRange: "<34")
        default:
            return IndicatorInput(unit: "", normalRange: "")
        }
    }
    
    private func saveRecord() {
        let record = CheckupRecord(date: selectedDate, type: selectedType, notes: notes.isEmpty ? nil : notes)
        
        for (name, input) in indicators {
            let status = ThyroidIndicator.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
            let indicator = ThyroidIndicator(
                name: name,
                value: input.doubleValue,
                unit: input.unit,
                normalRange: input.normalRange,
                status: status
            )
            indicator.record = record
            record.indicators.append(indicator)
        }
        
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}

struct IndicatorInputRow: View {
    let name: String
    @Binding var input: AddRecordView.IndicatorInput
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                Text("参考: \(input.normalRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField("数值", text: $input.value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                Text(input.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}
