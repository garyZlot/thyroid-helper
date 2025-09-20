//
//  THEditHistory.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/20.
//

import SwiftUI
import SwiftData
import PhotosUI

struct THEditHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let record: THHistoryRecord
    
    @State private var selectedDate: Date
    @State private var medicalTitle: String
    @State private var notes: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data]
    
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
        _medicalTitle = State(initialValue: record.title)
        _notes = State(initialValue: record.notes)
        _selectedImageDatas = State(initialValue: record.imageDatas)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("section_checkup_info".localized) {
                    DatePicker("checkup_date".localized, selection: $selectedDate, displayedComponents: .date)
                    
                    LabeledContent("checkup_item".localized) {
                        TextField("checkup_item_placeholder".localized, text: $medicalTitle)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("section_images".localized) {
                    VStack(spacing: 0) {
                        Button(action: {
                            showingSourceActionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("add_photo".localized)
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
                                Text("select_photos".localized)
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
                
                // OCR识别结果展示
                if ocrService.isProcessing {
                    Section("ocr_processing_title".localized) {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("ocr_processing_message".localized)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                
                // 图片预览
                if !selectedImageDatas.isEmpty {
                    Section("section_checkup_images".localized) {
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
                
                Section("section_notes".localized) {
                    TextField("notes_placeholder".localized, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // OCR识别的原始文本
                if !ocrService.recognizedText.isEmpty {
                    Section("section_recognized_text".localized) {
                        Text(ocrService.recognizedText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("edit_history_nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
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
        record.title = medicalTitle
        record.notes = notes
        
        // 更新图片数据
        record.imageDatas = selectedImageDatas
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("save_failed_format".localized(error.localizedDescription))
        }
    }
}
