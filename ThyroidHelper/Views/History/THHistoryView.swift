//
//  THHistoryView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/4.
//

import SwiftUI
import SwiftData
import PhotosUI

struct THHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THHistoryRecord.date, order: .reverse) private var records: [THHistoryRecord]
    @State private var showingAddOptions = false
    @State private var showingManualAddHistory = false
    @State private var selectedImageItems: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var showingBatchProgress = false
    @State private var recordToEdit: THHistoryRecord?
    @State private var isLoading = true
    
    @StateObject private var batchOCRService = THBatchOCRService()
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if records.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(records) { record in
                            TimelineRowView(record: record) {
                                recordToEdit = record
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGray6))
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("history_nav_title".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddOptions = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddOptions) {
                addOptionsSheet
                    .presentationDetents([.height(280)])
                    .presentationCornerRadius(20)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingManualAddHistory) {
                THAddHistoryView()
            }
            .sheet(item: $recordToEdit) { record in
                THEditHistoryView(record: record)
            }
            .sheet(isPresented: $showingBatchProgress) {
                BatchProgressView(service: batchOCRService)
                    .interactiveDismissDisabled(true)
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedImageItems,
                maxSelectionCount: 9,
                matching: .images
            )
            .onChange(of: selectedImageItems) { _, newValue in
                if !newValue.isEmpty {
                    showingBatchProgress = true
                    batchOCRService.processImagesAndCreateRecords(
                        from: newValue,
                        modelContext: modelContext
                    ) {
                        selectedImageItems.removeAll()
                    }
                }
            }
            .onAppear {
                // 模拟加载延迟，实际项目中可移除
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            }
        }
    }
    
    // 加载状态视图
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.5)
            
            Text("loading_history".localized)
                .foregroundColor(.secondary)
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.3))
            
            Text("no_history_title".localized)
                .font(.title)
                .fontWeight(.semibold)
            
            Text("no_history_description".localized)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingAddOptions = true }) {
                Text("add_first_record".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                    .shadow(color: .accentColor.opacity(0.2), radius: 10, x: 0, y: 4)
            }
        }
        .padding()
    }
    
    // 添加选项底部弹窗
    private var addOptionsSheet: some View {
        VStack(spacing: 0) {
            Text("select_add_history_method".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding()
            
            Divider()
            
            Button(action: {
                showingAddOptions = false
                showingImagePicker = true
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("smart_add_from_images".localized)
                            .font(.headline)
                        Text("auto_extract_from_images".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            Button(action: {
                showingAddOptions = false
                // 手动添加逻辑
                navigateToManualAdd()
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("manual_add".localized)
                            .font(.headline)
                        Text("manual_input_history".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            Button("cancel".localized, role: .cancel) {
                showingAddOptions = false
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(.primary)
    }
    
    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(records[index])
            }
            
            // 尝试保存上下文
            do {
                try modelContext.save()
            } catch {
                print("删除记录失败: \(error)")
            }
        }
    }
    
    // 导航到手动添加页面
    private func navigateToManualAdd() {
        showingManualAddHistory = true
    }
}

struct TimelineRowView: View {
    let record: THHistoryRecord
    let onEdit: () -> Void
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var isNotesExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 时间线圆点和连接线
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 0)
                
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 10) {
                // 时间和标题，以及编辑按钮
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
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
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                            .padding(6)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
                
                // 图片网格
                let allImages = record.imageDatas
                if !allImages.isEmpty {
                    imageGalleryView(images: allImages)
                }
                
                // 备注内容
                if !record.notes.isEmpty {
                    notesSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, 8)
        .fullScreenCover(isPresented: $showingImageViewer) {
            THImagesViewer(
                imageDatas: record.imageDatas,
                initialIndex: selectedImageIndex
            )
            .ignoresSafeArea()
        }
    }
    
    // 图片画廊视图
    private func imageGalleryView(images: [Data]) -> some View {
        Group {
            if images.count == 1, let imageData = images.first, let uiImage = UIImage(data: imageData) {
                // 单张大图
                Button(action: {
                    selectedImageIndex = 0
                    showingImageViewer = true
                }) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                }
            } else {
                // 多图网格
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            if let uiImage = UIImage(data: images[index]) {
                                Button(action: {
                                    selectedImageIndex = index
                                    showingImageViewer = true
                                }) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        // 轻量底部弹窗实现
        .sheet(isPresented: $showingImageViewer) {
            // 底部弹窗内容
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Spacer()
                    Button("关闭") {
                        showingImageViewer = false
                    }
                    .padding()
                }
                
                // 图片查看器
                THImagesViewer(
                    imageDatas: images,
                    initialIndex: selectedImageIndex
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .presentationDetents([.medium, .large]) // 轻量级底部弹窗支持中等和全屏尺寸
            .presentationBackgroundInteraction(.enabled) // 允许背景交互
        }
    }
    
    // 备注部分
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("notes_section_title".localized)
                    .font(.caption)
                    .fontWeight(.medium)
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
        .padding(.horizontal, 2)
    }
}

// 预览
#Preview {
    THHistoryView()
        .modelContainer(for: THHistoryRecord.self)
}
