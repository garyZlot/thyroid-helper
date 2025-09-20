//
//  THManualAddHistoryView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/20.
//

import SwiftUI
import PhotosUI

struct THManualAddHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data] = []
    
    // 相机相关状态
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("record_date".localized, selection: $selectedDate, displayedComponents: .date)
                
                TextField("record_title_placeholder".localized, text: $title)
                    .textFieldStyle(.roundedBorder)
                
                VStack(spacing: 0) {
                    Button(action: {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            imagePickerSource = .camera
                            showingImagePicker = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("take_photo".localized)
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
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("choose_from_library".localized)
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
            }
            .navigationTitle("manual_add_history".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveRecord()
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
        }
    }
    
    private var canSave: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveRecord() {
        let record = THHistoryRecord(
            date: selectedDate,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            imageDatas: selectedImageDatas,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        modelContext.insert(record)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 保存历史记录失败: \(error.localizedDescription)")
        }
    }
}
