//
//  AddRecordView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import Vision
import AVFoundation
import PhotosUI

struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedType = CheckupRecord.CheckupType.comprehensive
    @State private var notes = ""
    @State private var indicators: [String: IndicatorInput] = [:]
    
    // 图片相关状态
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
                Section("检查信息") {
                    DatePicker("检查日期", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("检查类型", selection: $selectedType) {
                        ForEach(CheckupRecord.CheckupType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("录入方式") {
                    VStack(spacing: 0) {
                        // ✅ 图片识别按钮
                        Button(action: {
                            print("点击了图片识别")
                            showingSourceActionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("图片识别")
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
                        
                        // ✅ 手动输入按钮
                        Button(action: {
                            print("点击了手动输入")
                            showManualInput = true
                            // 确保指标已经初始化
                            if indicators.isEmpty {
                                setupDefaultIndicators()
                            }
                        }) {
                            HStack {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("手动输入")
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
                        title: Text("选择图片来源"),
                        buttons: [
                            .default(Text("拍照")) {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    imagePickerSource = .camera
                                    showingImagePicker = true
                                }
                            },
                            .default(Text("从相册选择")) {
                                imagePickerSource = .photoLibrary
                                showingImagePicker = true
                            },
                            .cancel()
                        ]
                    )
                }
                
                // ✅ 显示手动输入字段（当用户点击手动输入或已有数据时显示）
                if showManualInput || !indicators.isEmpty {
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
                        
                        // 添加一个清除按钮，让用户可以隐藏输入字段
                        if showManualInput && indicators.values.allSatisfy({ $0.value.isEmpty }) {
                            Button("隐藏输入字段") {
                                showManualInput = false
                                indicators.removeAll()
                            }
                            .foregroundColor(.secondary)
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
                // 页面加载时不自动显示输入字段，等待用户选择输入方式
            }
            .onChange(of: selectedType) { _, _ in
                // 切换检查类型时，如果已经在手动输入模式，则更新指标
                if showManualInput {
                    setupDefaultIndicators()
                }
            }
            
            // ✅ 弹出相机/相册
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            
            // ✅ OCR 结果展示
            .sheet(isPresented: $showingOCRResult) {
                if let image = capturedImage {
                    OCRResultView(capturedImage: image) { extractedData in
                        handleOCRResult(extractedData)
                    }
                }
            }
            
            // ✅ 图片变化时进入 OCR 结果
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    showingOCRResult = true
                }
            }
        }
    }
    
    private func handleOCRResult(_ extractedData: [String: Double]) {
        // OCR 识别成功后，确保显示输入字段
        showManualInput = true
        
        for (indicatorName, value) in extractedData {
            if let defaultInput = indicators[indicatorName] {
                var updatedInput = defaultInput
                updatedInput.value = String(format: "%.2f", value)
                indicators[indicatorName] = updatedInput
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
        case "TSH": return IndicatorInput(unit: "μIU/mL", normalRange: "0.380-4.340")
        case "FT3": return IndicatorInput(unit: "pmol/L", normalRange: "2.77-6.31")
        case "FT4": return IndicatorInput(unit: "pmol/L", normalRange: "10.44-24.38")
        case "A-TG":  return IndicatorInput(unit: "IU/mL", normalRange: "0-4.5")
        case "A-TPO": return IndicatorInput(unit: "IU/mL", normalRange: "0-60")
        default:    return IndicatorInput(unit: "", normalRange: "")
        }
    }
    
//    private func saveRecord() {
//        let record = CheckupRecord(date: selectedDate, type: selectedType, notes: notes.isEmpty ? nil : notes)
//        for (name, input) in indicators {
//            let status = ThyroidIndicator.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
//            let indicator = ThyroidIndicator(
//                name: name,
//                value: input.doubleValue,
//                unit: input.unit,
//                normalRange: input.normalRange,
//                status: status
//            )
//            indicator.record = record
//            record.indicators.append(indicator)
//        }
//        modelContext.insert(record)
//        try? modelContext.save()
//        dismiss()
//    }
    
    private func saveRecord() {
        print("开始保存记录...")
        print("检查日期: \(selectedDate)")
        print("检查类型: \(selectedType.rawValue)")
        print("备注: \(notes)")
        
        let record = CheckupRecord(date: selectedDate, type: selectedType, notes: notes.isEmpty ? nil : notes)
        
        // 记录指标数据
        for (name, input) in indicators {
            print("指标 \(name): 值=\(input.value), 单位=\(input.unit), 正常范围=\(input.normalRange)")
            let status = ThyroidIndicator.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
            let indicator = ThyroidIndicator(
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
            print("✅ 记录保存成功! ID: \(record.id)")
            
            // 打印保存的记录详情
            print("保存的记录详情:")
            print(" - 日期: \(record.date)")
            print(" - 类型: \(record.type.rawValue)")
            print(" - 指标数量: \((record.indicators ?? []).count)")
            for indicator in (record.indicators ?? []) {
                print("   - \(indicator.name): \(indicator.value) \(indicator.unit) (\(indicator.status.rawValue))")
            }
            
            dismiss()
        } catch {
            print("❌ 保存失败: \(error.localizedDescription)")
            // 这里可以添加用户提示，例如使用Alert
        }
    }
}


struct IndicatorInputRow: View {
    let name: String
    @Binding var input: AddRecordView.IndicatorInput
    
    // 使用扩展获取完整显示名称
    private var displayName: String {
        let tempIndicator = ThyroidIndicator(name: name, value: 0, unit: "", normalRange: "", status: .normal)
        return tempIndicator.fullDisplayName
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                
                Text("参考: \(input.normalRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .leading)
            
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
