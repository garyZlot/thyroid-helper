//
//  THAddHistoryView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/20.
//

import SwiftUI
import PhotosUI

struct THAddHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data] = []
    
    // 相机相关状态
    @State private var showingImagePicker = false
    @State private var showingSourceActionSheet = false
    @State private var showingPhotoPicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("record_date".localized, selection: $selectedDate, displayedComponents: .date)
                
                TextField("record_title_placeholder".localized, text: $title)
                    .textFieldStyle(.roundedBorder)
                
                // 图片网格选择
                Section("photos".localized) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            // 显示已选择的图片
                            ForEach(Array(selectedImageDatas.enumerated()), id: \.offset) { index, imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button {
                                            print("删除图片 at index \(index)")
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
                            
                            // "+" 添加按钮，总是显示在最后
                            if selectedImageDatas.count < 9 { // 限制最多9张图片
                                Button(action: {
                                    showingSourceActionSheet = true
                                }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("notes".localized) {
                    TextField("content_placeholder".localized, text: $notes, axis: .vertical)
                        .lineLimit(5...10)
                        .textFieldStyle(.roundedBorder)
                }
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
            .bottomActionSheet(
                isPresented: $showingSourceActionSheet,
                title: "select_photo_source".localized,
                options: [
                    THBottomSheetOption(
                        icon: "camera",
                        iconColor: .blue,
                        title: "take_photo".localized,
                        subtitle: "use_camera_to_take_photo".localized
                    ) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            imagePickerSource = .camera
                            showingImagePicker = true
                        }
                    },
                    THBottomSheetOption(
                        icon: "photo.on.rectangle",
                        iconColor: .green,
                        title: "choose_from_library".localized,
                        subtitle: "select_from_photo_library".localized
                    ) {
                        // 使用 PhotosPicker
                        showingPhotoPicker = true
                    }
                ]
            )
            .sheet(isPresented: $showingImagePicker) {
                THImagePicker(image: $capturedImage, sourceType: imagePickerSource)
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 10, matching: .images)
            .onChange(of: capturedImage) { _, newImage in
                if let newImage = newImage {
                    if let imageData = newImage.jpegData(compressionQuality: 0.8) {
                        selectedImageDatas.append(imageData)
                    }
                    capturedImage = nil
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                print("📸 选择了 \(newValue.count) 张照片")
                Task {
                    let photos = newValue
                    selectedPhotos.removeAll()
                    var newImages: [Data] = []
                    
                    for photo in photos {
                        do {
                            if let data = try await photo.loadTransferable(type: Data.self) {
                                print("✅ 成功加载图片数据，大小: \(data.count) bytes")
                                newImages.append(data)
                            }
                        } catch {
                            print("❌ 加载图片失败: \(error)")
                        }
                    }
                    
                    // 回到主线程更新 UI
                    await MainActor.run {
                        selectedImageDatas.append(contentsOf: newImages)
                        print("🎯 现在总共有 \(selectedImageDatas.count) 张图片")
                    }
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
