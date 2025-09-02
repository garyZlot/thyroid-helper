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

                    // ✅ 改成静态显示
                    HStack {
                        Text("检查类型")
                        Spacer()
                        Text(selectedType.rawValue)
                            .foregroundColor(.secondary)
                    }
                }

                Section("录入方式") {
                    VStack(spacing: 0) {
                        Button(action: {
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
                            .cancel(Text("取消"))
                        ]
                    )
                }

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
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            .sheet(isPresented: $showingOCRResult) {
                if let image = capturedImage {
                    OCRResultView(capturedImage: image) { extractedData in
                        handleOCRResult(extractedData)
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    showingOCRResult = true
                }
            }
        }
    }

    private func handleOCRResult(_ extractedData: [String: Double]) {
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
                let setting = ThyroidConfig.indicatorSettings[indicatorName] ?? IndicatorSetting(unit: "", normalRange: (0, 0))
                var newInput = IndicatorInput(value: String(format: "%.2f", value), unit: setting.unit, normalRange: setting.normalRangeString)
                indicators[indicatorName] = newInput
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
        let setting = ThyroidConfig.indicatorSettings[name] ?? IndicatorSetting(unit: "", normalRange: (0, 0))
        return IndicatorInput(value: "", unit: setting.unit, normalRange: setting.normalRangeString)
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
            indicator.checkupRecord = record
            record.indicators?.append(indicator)
        }

        modelContext.insert(record)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 保存失败: \(error.localizedDescription)")
        }
    }
}

struct IndicatorInputRow: View {
    let name: String
    @Binding var input: AddRecordView.IndicatorInput

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

