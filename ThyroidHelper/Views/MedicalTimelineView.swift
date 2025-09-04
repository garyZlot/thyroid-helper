//
//  MedicalTimelineView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/4.
//

import SwiftUI
import SwiftData
import PhotosUI

struct MedicalTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicalHistoryRecord.date, order: .reverse) private var records: [MedicalHistoryRecord]
    @State private var showingAddRecord = false
    @State private var showingAddTypeSelection = false
    @State private var selectedAddType: AddRecordSelectionView.AddRecordType = .ocrRecognition
    
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
                            TimelineRowView(record: record)
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
                        showingAddTypeSelection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTypeSelection) {
                AddRecordSelectionView { type in
                    selectedAddType = type
                    showingAddRecord = true
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddMedicalRecordView(initialMode: selectedAddType)
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
    let record: MedicalHistoryRecord
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
                // 时间和标题
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(record.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // 图片网格
                let allImages = record.allImageDatas
                if !allImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(3, allImages.count)), spacing: 8) {
                        ForEach(Array(allImages.prefix(9).enumerated()), id: \.offset) { index, imageData in
                            if let uiImage = UIImage(data: imageData) {
                                Button {
                                    selectedImageIndex = index
                                    showingImageViewer = true
                                } label: {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: allImages.count == 1 ? 200 : 100)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // 如果图片超过9张，显示更多指示器
                        if allImages.count > 9 {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 100)
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
            ImageViewer(imageDatas: record.allImageDatas, initialIndex: selectedImageIndex)
        }
    }
}

struct AddMedicalRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let initialMode: AddRecordSelectionView.AddRecordType
    
    @State private var date = Date()
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data] = []
    @State private var recordType: MedicalHistoryRecord.RecordType = .ultrasound
    
    // OCR 相关状态
    @StateObject private var ocrService = MedicalRecordOCRService()
    @State private var showingOCRImagePicker = false
    @State private var ocrProcessedImage: UIImage?
    
    init(initialMode: AddRecordSelectionView.AddRecordType = .manual) {
        self.initialMode = initialMode
    }
    
    private var isOCRMode: Bool {
        initialMode == .ocrRecognition
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // OCR识别结果展示
                if isOCRMode && ocrService.isProcessing {
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
                
                Section("基本信息") {
                    DatePicker("检查时间", selection: $date, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                    
                    Picker("检查类型", selection: $recordType) {
                        ForEach(MedicalHistoryRecord.RecordType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("检查标题", text: $title, prompt: Text("例如：甲状腺B超检查"))
                }
                
                Section("检查图片") {
                    // 已选择的图片预览
                    if !selectedImageDatas.isEmpty {
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
                    
                    // 添加图片按钮
                    VStack(spacing: 12) {
                        if isOCRMode {
                            Button {
                                showingOCRImagePicker = true
                            } label: {
                                Label("拍照识别", systemImage: "camera.viewfinder")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else {
                            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                                Label("选择图片", systemImage: "photo.on.rectangle.angled")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        // 添加更多图片按钮（在已有图片时显示）
                        if !selectedImageDatas.isEmpty {
                            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                                Label("添加更多图片", systemImage: "plus.rectangle.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                Section("备注") {
                    TextField("备注信息", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // OCR识别的原始文本（如果有）
                if !ocrService.recognizedText.isEmpty {
                    Section("识别内容") {
                        Text(ocrService.recognizedText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("添加档案记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    // 不要清空现有图片，而是添加新的
                    for photo in newValue {
                        if let data = try? await photo.loadTransferable(type: Data.self) {
                            // 避免重复添加
                            if !selectedImageDatas.contains(data) {
                                selectedImageDatas.append(data)
                            }
                        }
                    }
                    // 清空选择器以便下次使用
                    selectedPhotos.removeAll()
                }
            }
            .onChange(of: ocrService.extractedDate) { _, newDate in
                if let newDate = newDate {
                    date = newDate
                }
            }
            .onChange(of: ocrService.extractedTitle) { _, newTitle in
                if !newTitle.isEmpty {
                    title = newTitle
                }
            }
            .onChange(of: ocrService.extractedNotes) { _, newNotes in
                if !newNotes.isEmpty {
                    notes = newNotes
                }
            }
            .sheet(isPresented: $showingOCRImagePicker) {
                ImagePickerView { image in
                    ocrProcessedImage = image
                    
                    // 将OCR图片添加到选择的图片中
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        selectedImageDatas.append(imageData)
                    }
                    
                    // 开始OCR识别
                    ocrService.processImage(image)
                }
            }
            .onAppear {
                // 如果是OCR模式，自动打开相机
                if isOCRMode && selectedImageDatas.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingOCRImagePicker = true
                    }
                }
            }
        }
    }
    
    private func saveRecord() {
        let record = MedicalHistoryRecord(
            date: date,
            title: title.isEmpty ? recordType.rawValue : title,
            imageData: selectedImageDatas.first, // 向后兼容
            imageDatas: selectedImageDatas,
            notes: notes
        )
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("保存档案记录失败: \(error)")
        }
    }
}

// 图片选择器组件
struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    MedicalTimelineView()
        .modelContainer(for: MedicalHistoryRecord.self)
}
