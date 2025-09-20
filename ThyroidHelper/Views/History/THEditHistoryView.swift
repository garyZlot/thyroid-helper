//
//  THEditHistoryView.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/20.
//  Updated by gdlium2p on 2025/9/20.
//

import SwiftUI
import SwiftData
import PhotosUI

struct THEditHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let record: THHistoryRecord
    
    @State private var selectedDate: Date
    @State private var title: String
    @State private var notes: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data]
    @State private var showingPhotosPicker = false
    
    // OCR 相关状态
    @StateObject private var ocrService = THHistoryCheckupOCRService()
    
    // 图片相关状态
    @State private var showingImagePicker = false
    @State private var showingSourceActionSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    
    init(record: THHistoryRecord) {
        self.record = record
        _selectedDate = State(initialValue: record.date)
        _title = State(initialValue: record.title)
        _notes = State(initialValue: record.notes)
        _selectedImageDatas = State(initialValue: record.imageDatas)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("record_date".localized, selection: $selectedDate, displayedComponents: .date)
                
                TextField("record_title_placeholder".localized, text: $title)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    showingSourceActionSheet = true
                }) {
                    HStack {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("add_photos".localized)
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
                                showingPhotosPicker = true
                            },
                            .cancel(Text("cancel".localized))
                        ]
                    )
                }
                
                // OCR识别处理中的提示
                if ocrService.isProcessing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("ocr_processing_message".localized)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // 图片预览
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
                
                TextField("content_placeholder".localized, text: $notes, axis: .vertical)
                    .lineLimit(5...10)
                    .textFieldStyle(.roundedBorder)
                
                // OCR识别的原始文本（如果有）
                if !ocrService.recognizedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("section_recognized_text".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("copy_text".localized) {
                                UIPasteboard.general.string = ocrService.recognizedText
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        Text(ocrService.recognizedText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("edit_history_nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveChanges()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                THImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            .sheet(isPresented: $showingPhotosPicker) {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                    Text("select_photos".localized)
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let newImage = newImage {
                    // 添加图片到数据数组
                    if let imageData = newImage.jpegData(compressionQuality: 0.8) {
                        selectedImageDatas.append(imageData)
                    }
                    // 开始OCR识别
                    ocrService.processImage(newImage)
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    var newImages: [UIImage] = []
                    for photo in newValue {
                        if let data = try? await photo.loadTransferable(type: Data.self) {
                            if !selectedImageDatas.contains(data) {
                                selectedImageDatas.append(data)
                                // 收集新添加的图片用于OCR
                                if let image = UIImage(data: data) {
                                    newImages.append(image)
                                }
                            }
                        }
                    }
                    selectedPhotos.removeAll()
                    showingPhotosPicker = false
                    
                    // 对第一张新图片进行OCR识别
                    if let firstImage = newImages.first {
                        ocrService.processImage(firstImage)
                    }
                }
            }
            .onChange(of: ocrService.extractedDate) { _, newDate in
                if let newDate = newDate {
                    selectedDate = newDate
                }
            }
            .onChange(of: ocrService.extractedCheckupName) { _, newTitle in
                if !newTitle.isEmpty {
                    title = newTitle
                }
            }
            .onChange(of: ocrService.extractedNotes) { _, newNotes in
                if !newNotes.isEmpty {
                    // 编辑时，如果已有内容，询问是否替换
                    if notes.isEmpty {
                        notes = newNotes
                    }
                }
            }
        }
    }
    
    private var canSave: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveChanges() {
        // 更新记录信息
        record.date = selectedDate
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 更新图片数据
        record.imageDatas = selectedImageDatas
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 保存历史记录失败: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: THHistoryRecord.self, configurations: config)
    
    let sampleRecord = THHistoryRecord(
        date: Date(),
        title: "甲状腺超声检查",
        imageDatas: [],
        notes: "检查结果正常"
    )
    container.mainContext.insert(sampleRecord)
    
    return NavigationView {
        THEditHistoryView(record: sampleRecord)
    }
    .modelContainer(container)
}
