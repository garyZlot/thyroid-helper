//
//  THMedicalTimelineView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/4.
//

import SwiftUI
import SwiftData
import PhotosUI

struct THMedicalTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THMedicalTimelineRecord.date, order: .reverse) private var records: [THMedicalTimelineRecord]
    @State private var showingAddRecord = false
    @State private var recordToEdit: THMedicalTimelineRecord?
    
    var body: some View {
        NavigationView {
            VStack {
                if records.isEmpty {
                    ContentUnavailableView(
                        "暂无档案记录",
                        systemImage: "clock",
                        description: Text("添加您的第一条医疗记录")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            TimelineRowView(record: record) {
                                recordToEdit = record
                            }
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("档案")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddRecord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                THAddRecordView(mode: .medicalRecord)
            }
            .sheet(item: $recordToEdit) { record in
                THMedicalRecordEditView(record: record)
            }
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(records[index])
            }
        }
    }
}

struct TimelineRowView: View {
    let record: THMedicalTimelineRecord
    let onEdit: () -> Void
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间线圆点
            VStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间和标题，以及编辑按钮
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(record.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
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
                
                // 图片网格
                let allImages = record.imageDatas
                if !allImages.isEmpty {
                    if allImages.count == 1, let imageData = allImages.first, let uiImage = UIImage(data: imageData) {
                        // 单张大图
                        Button {
                            selectedImageIndex = 0
                            showingImageViewer = true
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 200)
                                .clipped()
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // 多张固定 3 列网格
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(Array(allImages.prefix(9).enumerated()), id: \.offset) { index, imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    Button {
                                        selectedImageIndex = index
                                        showingImageViewer = true
                                    } label: {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // 超过9张显示更多
                            if allImages.count > 9 {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo.stack")
                                                .font(.title2)
                                            Text("+\(allImages.count - 9)")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.secondary)
                                    )
                                    .onTapGesture {
                                        selectedImageIndex = 9
                                        showingImageViewer = true
                                    }
                            }
                        }
                    }
                }
                
                // 备注
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: $showingImageViewer) {
            THImageViewer(
                imageDatas: record.imageDatas,
                initialIndex: selectedImageIndex
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - 医疗档案编辑视图
struct THMedicalRecordEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let record: THMedicalTimelineRecord
    
    @State private var selectedDate: Date
    @State private var medicalTitle: String
    @State private var medicalRecordType: THMedicalTimelineRecord.RecordType
    @State private var notes: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data]
    
    // OCR 相关状态
    @StateObject private var ocrService = THMedicalRecordOCRService()
    
    // 图片相关状态
    @State private var showingImagePicker = false
    @State private var showingSourceActionSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    
    init(record: THMedicalTimelineRecord) {
        self.record = record
        _selectedDate = State(initialValue: record.date)
        _medicalTitle = State(initialValue: record.title)
        _medicalRecordType = State(initialValue: record.recordType)
        _notes = State(initialValue: record.notes)
        _selectedImageDatas = State(initialValue: record.imageDatas)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("检查信息") {
                    DatePicker("检查日期", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("检查类型", selection: $medicalRecordType) {
                        ForEach(THMedicalTimelineRecord.RecordType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("检查标题", text: $medicalTitle, prompt: Text("例如：甲状腺B超检查"))
                }
                
                Section("图片管理") {
                    VStack(spacing: 0) {
                        Button(action: {
                            showingSourceActionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("拍照添加")
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
                        
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("选择图片")
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
                
                // OCR识别结果展示
                if ocrService.isProcessing {
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
                
                // 图片预览
                if !selectedImageDatas.isEmpty {
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
                
                Section("备注") {
                    TextField("添加备注信息...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // OCR识别的原始文本
                if !ocrService.recognizedText.isEmpty {
                    Section("识别内容") {
                        Text(ocrService.recognizedText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("编辑档案记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                THImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            .onChange(of: capturedImage) { _, newImage in
                if let newImage = newImage {
                    if let imageData = newImage.jpegData(compressionQuality: 0.8) {
                        selectedImageDatas.append(imageData)
                    }
                    ocrService.processImage(newImage)
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
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
            .onChange(of: ocrService.extractedCheckupName) { _, newTitle in
                if !newTitle.isEmpty {
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
    
    private var canSave: Bool {
        return !medicalTitle.isEmpty || !selectedImageDatas.isEmpty
    }
    
    private func saveChanges() {
        // 更新记录信息
        record.date = selectedDate
        record.title = medicalTitle.isEmpty ? medicalRecordType.rawValue : medicalTitle
        record.notes = notes
        record.recordType = medicalRecordType
        
        // 更新图片数据
        record.imageDatas = selectedImageDatas
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 保存医疗档案失败: \(error.localizedDescription)")
        }
    }
}

#Preview {
    THMedicalTimelineView()
        .modelContainer(for: THMedicalTimelineRecord.self)
}
