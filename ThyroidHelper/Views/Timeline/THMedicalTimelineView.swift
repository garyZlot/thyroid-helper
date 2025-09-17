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
                        "no_medical_records_title".localized,
                        systemImage: "clock",
                        description: Text("no_medical_records_description".localized)
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
            .navigationTitle("medical_records_nav_title".localized)
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
    @State private var isNotesExpanded = false
    
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
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(record.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer(minLength: 8)
                    
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
                .zIndex(10)
                
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
                
                // 内容及备注
                if !record.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("notes_section_title".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isNotesExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isNotesExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text(record.notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(isNotesExpanded ? nil : 2)
                            .animation(.easeInOut(duration: 0.3), value: isNotesExpanded)
                    }
                    .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: $showingImageViewer) {
            THImagesViewer(
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
            .navigationTitle("edit_medical_record_nav_title".localized)
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

#Preview {
    THMedicalTimelineView()
        .modelContainer(for: THMedicalTimelineRecord.self)
}
