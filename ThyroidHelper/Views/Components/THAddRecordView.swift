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

struct THAddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 记录类型：甲状腺检查数据 或 医疗档案
    enum RecordMode {
        case thyroidData    // 甲状腺数据记录
        case medicalRecord  // 医疗档案记录
    }
    
    let mode: RecordMode
    
    @State private var selectedDate = Date()
    @State private var selectedType = THThyroidPanelRecord.CheckupType.comprehensive
    @State private var notes = ""
    @State private var indicators: [String: IndicatorInput] = [:]
    
    // 医疗档案相关状态
    @State private var medicalTitle = ""
    @State private var medicalRecordType: THMedicalTimelineRecord.RecordType = .ultrasound
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data] = []
    
    // OCR 相关状态
    @StateObject private var ocrService = THMedicalRecordOCRService()
    @State private var thyroidOCRService = THThyroidPanelOCRService()
    
    // 图片相关状态
    @State private var showingImagePicker = false
    @State private var showingSourceActionSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    @State private var showingOCRResult = false
    
    // 手动输入状态
    @State private var showManualInput = false
    
    init(mode: RecordMode = .thyroidData) {
        self.mode = mode
    }
    
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
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    
                    if mode == .thyroidData {
                        // 甲状腺检查类型
                        HStack {
                            Text("检查类型")
                            Spacer()
                            Text(selectedType.rawValue)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // 医疗档案类型
                        Picker("检查类型", selection: $medicalRecordType) {
                            ForEach(THMedicalTimelineRecord.RecordType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        TextField("检查标题", text: $medicalTitle, prompt: Text("标题：可选"))
                    }
                }
                
                Section(mode == .thyroidData ? "录入方式" : "添加检查图片") {
                    VStack(spacing: 0) {
                        Button(action: {
                            showingSourceActionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("图片识别数据")
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
                        
                        if mode == .thyroidData {
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
                                    Text("手动输入数据")
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
                        } else {
                            // 医疗档案的图片选择
                            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("仅上传图片")
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
                
                // OCR识别结果展示
                if (mode == .medicalRecord && ocrService.isProcessing) {
                    Section("正在识别...") {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("正在识别图片内容...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                
                // 医疗档案的图片预览
                if mode == .medicalRecord && !selectedImageDatas.isEmpty {
                    Section("检查图片") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(Array(selectedImageDatas.enumerated()), id: \.offset) { index, imageData in
                                    if let uiImage = UIImage(data: imageData) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            Button {
                                                selectedImageDatas.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .background(Color.white, in: Circle())
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // 甲状腺数据输入
                if mode == .thyroidData && (showManualInput || !indicators.isEmpty) {
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
                
                // 医疗档案 OCR识别的原始文本
                if mode == .medicalRecord && !ocrService.recognizedText.isEmpty {
                    Section("识别内容") {
                        Text(ocrService.recognizedText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(mode == .thyroidData ? "添加甲状腺记录" : "添加档案记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if mode == .thyroidData {
                            saveThyroidRecord()
                        } else {
                            saveMedicalRecord()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                THImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            .sheet(isPresented: $showingOCRResult) {
                if let image = capturedImage {
                    if mode == .thyroidData {
                        THOCRResultView(capturedImage: image) { extractedData in
                            handleThyroidOCRResult(extractedData)
                        }
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let newImage = newImage {
                    if mode == .thyroidData {
                        showingOCRResult = true
                    } else {
                        // 医疗档案模式：添加图片并开始OCR
                        if let imageData = newImage.jpegData(compressionQuality: 0.8) {
                            selectedImageDatas.append(imageData)
                        }
                        ocrService.processImage(newImage)
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    // 处理医疗档案的多图片选择
                    for photo in newValue {
                        if let data = try? await photo.loadTransferable(type: Data.self) {
                            if !selectedImageDatas.contains(data) {
                                selectedImageDatas.append(data)
                            }
                        }
                    }
                    selectedPhotos.removeAll()
                }
            }
            .onChange(of: ocrService.extractedDate) { _, newDate in
                if let newDate = newDate {
                    selectedDate = newDate
                }
            }
            .onChange(of: ocrService.extractedTitle) { _, newTitle in
                if !newTitle.isEmpty && mode == .medicalRecord {
                    medicalTitle = newTitle
                }
            }
            .onChange(of: ocrService.extractedNotes) { _, newNotes in
                if !newNotes.isEmpty {
                    notes = newNotes
                }
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
        if mode == .thyroidData {
            return !indicators.isEmpty && indicators.values.allSatisfy { $0.isValid }
        } else {
            return !medicalTitle.isEmpty || !selectedImageDatas.isEmpty
        }
    }
    
    private func setupDefaultIndicators() {
        indicators.removeAll()
        for indicatorName in selectedType.defaultIndicators {
            indicators[indicatorName] = defaultIndicatorInput(for: indicatorName)
        }
    }
    
    private func defaultIndicatorInput(for name: String) -> IndicatorInput {
        let setting = THConfig.indicatorSettings[name] ?? IndicatorSetting(unit: "", normalRange: (0, 0))
        return IndicatorInput(value: "", unit: setting.unit, normalRange: setting.normalRangeString)
    }
    
    private func saveThyroidRecord() {
        let record = THThyroidPanelRecord(date: selectedDate, type: selectedType, notes: notes.isEmpty ? nil : notes)
        
        for (name, input) in indicators {
            let status = THThyroidIndicator.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
            let indicator = THThyroidIndicator(
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
            print("❌ 保存甲状腺记录失败: \(error.localizedDescription)")
        }
    }
    
    private func saveMedicalRecord() {
        let record = THMedicalTimelineRecord(
            date: selectedDate,
            title: medicalTitle.isEmpty ? medicalRecordType.rawValue : medicalTitle,
            type: medicalRecordType,
            imageData: selectedImageDatas.first, // 向后兼容
            imageDatas: selectedImageDatas,
            notes: notes
        )
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 保存医疗档案失败: \(error.localizedDescription)")
        }
    }
}

struct IndicatorInputRow: View {
    let name: String
    @Binding var input: THAddRecordView.IndicatorInput
    
    private var displayName: String {
        let tempIndicator = THThyroidIndicator(name: name, value: 0, unit: "", normalRange: "", status: .normal)
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
