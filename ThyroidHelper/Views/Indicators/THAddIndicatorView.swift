//
//  THAddIndicatorView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import Vision
import AVFoundation
import SwiftData

struct THAddIndicatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var thyroidPanelType: THCheckupRecord.CheckupType = .thyroidFunction5
    @State private var notes = ""
    @State private var indicators: [String: IndicatorInput] = [:]
    
    @State private var showingDuplicateAlert = false
    @State private var showingSuccessAlert = false
    @State private var duplicateRecord: THCheckupRecord?
    
    // OCR 相关状态
    @State private var showingImagePicker = false
    @State private var showingSourceActionSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    @State private var showingOCRResult = false
    
    // 手动输入状态
    @State private var showManualInput = false
    
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
                Section("section_checkup_info".localized) {
                    DatePicker("checkup_date".localized, selection: $selectedDate, displayedComponents: .date)
                    
                    // 甲状腺检查类型
                    Picker("checkup_type".localized, selection: $thyroidPanelType) {
                        ForEach(THCheckupRecord.CheckupType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("input_method".localized) {
                    VStack(spacing: 0) {
                        Button(action: {
                            showingSourceActionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("image_recognition_data".localized)
                                    .font(.body)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        Button(action: {
                            showManualInput = true
                            if indicators.isEmpty {
                                setupDefaultIndicators()
                            }
                        }) {
                            HStack {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("manual_input_data".localized)
                                    .font(.body)
                                    .foregroundColor(.green)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .actionSheet(isPresented: $showingSourceActionSheet) {
                    ActionSheet(
                        title: Text("select_photo_source".localized),
                        buttons: [
                            .default(Text("take_photo".localized)) {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    imagePickerSource = .camera
                                    showingImagePicker = true
                                }
                            },
                            .default(Text("choose_from_library".localized)) {
                                imagePickerSource = .photoLibrary
                                showingImagePicker = true
                            },
                            .cancel(Text("cancel".localized))
                        ]
                    )
                }
                
                // 甲状腺数据输入
                if showManualInput || !indicators.isEmpty {
                    Section("checkup_values".localized) {
                        ForEach(thyroidPanelType.indicators, id: \.self) { indicatorName in
                            IndicatorInputRow(
                                name: indicatorName,
                                input: Binding(
                                    get: { indicators[indicatorName] ?? defaultIndicatorInput(for: indicatorName) },
                                    set: { indicators[indicatorName] = $0 }
                                )
                            )
                        }
                        
                        if showManualInput && indicators.values.allSatisfy({ $0.value.isEmpty }) {
                            Button("hide_input_fields".localized) {
                                showManualInput = false
                                indicators.removeAll()
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("section_notes".localized) {
                    TextField("notes_placeholder".localized, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("add_checkup_indicator".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveThyroidRecord()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                THImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            .sheet(isPresented: $showingOCRResult) {
                if let image = capturedImage {
                    THPanelOCRResultView(
                        capturedImage: image,
                        indicatorType: thyroidPanelType,
                        onConfirm: { extractedData in
                            handleThyroidOCRResult(extractedData)
                        },
                        onDateExtracted: { extractedDate in
                            if let date = extractedDate {
                                selectedDate = date
                            }
                        }
                    )
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let newImage = newImage {
                    showingOCRResult = true
                }
            }
            .alert("record_already_exists".localized, isPresented: $showingDuplicateAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("add_anyway".localized) {
                    performSaveThyroidRecord()
                }
            } message: {
                if let duplicate = duplicateRecord {
                    let dateString = duplicate.date.localizedMedium
                    Text(String(format: "duplicate_record_message".localized, dateString, duplicate.type.rawValue))
                }
            }
            .alert("save_success".localized, isPresented: $showingSuccessAlert) {
                Button("ok".localized) {
                    dismiss()
                }
            } message: {
                Text("record_saved_successfully".localized)
            }
        }
    }
    
    private func handleThyroidOCRResult(_ extractedData: [String: Double]) {
        showManualInput = true
        if indicators.isEmpty {
            setupDefaultIndicators()
        }
        for (indicatorName, value) in extractedData {
            if let defaultInput = indicators[indicatorName] {
                var updatedInput = defaultInput
                updatedInput.value = String(format: "%.2f", value)
                indicators[indicatorName] = updatedInput
            } else {
                let setting = THConfig.indicatorSettings[indicatorName] ?? IndicatorSetting(unit: "", normalRange: (0, 0))
                let newInput = IndicatorInput(value: String(format: "%.2f", value), unit: setting.unit, normalRange: setting.normalRangeString)
                indicators[indicatorName] = newInput
            }
        }
    }
    
    private var canSave: Bool {
        return !indicators.isEmpty && indicators.values.allSatisfy { $0.isValid }
    }
    
    private func setupDefaultIndicators() {
        indicators.removeAll()
        for indicatorName in thyroidPanelType.indicators {
            indicators[indicatorName] = defaultIndicatorInput(for: indicatorName)
        }
    }
    
    private func defaultIndicatorInput(for name: String) -> IndicatorInput {
        let setting = THConfig.indicatorSettings[name] ?? IndicatorSetting(unit: "", normalRange: (0, 0))
        return IndicatorInput(value: "", unit: setting.unit, normalRange: setting.normalRangeString)
    }
    
    private func saveThyroidRecord() {
        // 检查是否存在同一日期和同一类型的记录
        if let existingRecord = checkForDuplicateRecord() {
            duplicateRecord = existingRecord
            showingDuplicateAlert = true
            return
        }
        
        // 执行实际保存
        performSaveThyroidRecord()
    }

    // 检查重复记录的辅助函数
    private func checkForDuplicateRecord() -> THCheckupRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            // 先获取指定日期范围的所有记录
            let descriptor = FetchDescriptor<THCheckupRecord>(
                predicate: #Predicate<THCheckupRecord> { record in
                    record.date >= startOfDay && record.date < endOfDay
                }
            )
            
            let records = try modelContext.fetch(descriptor)
            return records.first { $0.type == thyroidPanelType }
        } catch {
            print("❌ 检查重复记录失败: \(error)")
            return nil
        }
    }

    // 实际执行保存的函数
    private func performSaveThyroidRecord() {
        let record = THCheckupRecord(date: selectedDate, type: thyroidPanelType, notes: notes.isEmpty ? nil : notes)
        
        for (name, input) in indicators {
            let status = THIndicatorRecord.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
            let indicator = THIndicatorRecord(
                name: name,
                value: input.doubleValue,
                unit: input.unit,
                normalRange: input.normalRange,
                status: status
            )
            indicator.checkupRecord = record
            record.indicators?.append(indicator)
        }
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            showingSuccessAlert = true  // 显示成功提示
        } catch {
            print("❌ 保存甲状腺记录失败: \(error.localizedDescription)")
        }
    }
}

struct IndicatorInputRow: View {
    let name: String
    @Binding var input: THAddIndicatorView.IndicatorInput
    
    private var displayName: String {
        let tempIndicator = THIndicatorRecord(name: name, value: 0, unit: "", normalRange: "", status: .normal)
        return tempIndicator.fullDisplayName
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                Text("reference_format".localized(input.normalRange))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField("value_placeholder".localized, text: $input.value)
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

#Preview {
    NavigationView {
        THAddIndicatorView()
    }
    .modelContainer(for: THCheckupRecord.self)
}
