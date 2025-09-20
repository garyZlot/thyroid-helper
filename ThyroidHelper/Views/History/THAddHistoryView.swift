//
//  THAddHistoryView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/20.
//

import SwiftUI
import PhotosUI
import SwiftData

struct THAddHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageDatas: [Data] = []
    
    // 历史记录类型
    @State private var selectedHistoryType: HistoryType = .checkupReport
    
    // 图片相关状态
    @State private var showingImagePicker = false
    @State private var showingSourceActionSheet = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var capturedImage: UIImage?
    
    enum HistoryType: String, CaseIterable {
        case checkupReport = "checkup_report"
        case dietAdjustment = "diet_adjustment"
        case medicationAdjustment = "medication_adjustment"
        case treatment = "treatment"
        case symptom = "symptom"
        case other = "other"
        
        var localizedName: String {
            return self.rawValue.localized
        }
        
        var icon: String {
            switch self {
            case .checkupReport:
                return "doc.text.magnifyingglass"
            case .dietAdjustment:
                return "fork.knife"
            case .medicationAdjustment:
                return "pills"
            case .treatment:
                return "stethoscope"
            case .symptom:
                return "heart.text.square"
            case .other:
                return "folder"
            }
        }
        
        var color: Color {
            switch self {
            case .checkupReport:
                return .blue
            case .dietAdjustment:
                return .green
            case .medicationAdjustment:
                return .orange
            case .treatment:
                return .purple
            case .symptom:
                return .red
            case .other:
                return .gray
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("section_basic_info".localized) {
                    DatePicker("record_date".localized, selection: $selectedDate, displayedComponents: .date)
                    
                    // 记录类型选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("record_type".localized)
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(HistoryType.allCases, id: \.self) { type in
                                Button {
                                    selectedHistoryType = type
                                    // 根据类型设置默认标题
                                    if title.isEmpty {
                                        title = type.localizedName
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: type.icon)
                                            .font(.title2)
                                            .foregroundColor(selectedHistoryType == type ? .white : type.color)
                                        
                                        Text(type.localizedName)
                                            .font(.caption)
                                            .foregroundColor(selectedHistoryType == type ? .white : .primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedHistoryType == type ? type.color : type.color.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // 标题输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("record_title".localized)
                            .font(.headline)
                        TextField("record_title_placeholder".localized, text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // 图片添加部分
                Section("section_images".localized) {
                    VStack(spacing: 0) {
                        Button(action: {
                            showingSourceActionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
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
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("select_from_album".localized)
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
                
                // 图片预览
                if !selectedImageDatas.isEmpty {
                    Section("selected_images".localized) {
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
                
                // 详细内容
                Section("section_content".localized) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("detailed_content".localized)
                            .font(.headline)
                        TextField("content_placeholder".localized, text: $notes, axis: .vertical)
                            .lineLimit(5...10)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // 根据类型显示提示信息
                Section("tips".localized) {
                    Text(getTipsForSelectedType())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("add_history_record".localized)
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
            .onChange(of: selectedHistoryType) { _, newType in
                // 当类型改变时，如果标题还是默认的，则更新为新类型的名称
                if title == selectedHistoryType.localizedName || title.isEmpty {
                    title = newType.localizedName
                }
            }
        }
    }
    
    private var canSave: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func getTipsForSelectedType() -> String {
        switch selectedHistoryType {
        case .checkupReport:
            return "checkup_report_tips".localized
        case .dietAdjustment:
            return "diet_adjustment_tips".localized
        case .medicationAdjustment:
            return "medication_adjustment_tips".localized
        case .treatment:
            return "treatment_tips".localized
        case .symptom:
            return "symptom_tips".localized
        case .other:
            return "other_tips".localized
        }
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

#Preview {
    NavigationView {
        THAddHistoryView()
    }
    .modelContainer(for: THHistoryRecord.self)
}
