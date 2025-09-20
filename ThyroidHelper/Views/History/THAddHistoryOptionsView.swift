//
//  THAddHistoryOptionsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/20.
//

import SwiftUI
import PhotosUI
import SwiftData

struct THAddHistoryOptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingManualAdd = false
    @State private var showingBatchProgress = false
    
    @StateObject private var batchOCRService = THBatchOCRService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Spacer()
                
                // 标题
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("add_history_record".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("choose_add_method".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // 选项按钮
                VStack(spacing: 16) {
                    // 图片识别添加
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 20, matching: .images) {
                        OptionButton(
                            icon: "camera.viewfinder",
                            title: "smart_add_from_images".localized,
                            subtitle: "auto_extract_info_from_reports".localized,
                            color: .blue
                        )
                    }
                    
                    // 手动添加
                    Button {
                        showingManualAdd = true
                    } label: {
                        OptionButton(
                            icon: "hand.point.up.left.fill",
                            title: "manual_add".localized,
                            subtitle: "manually_input_information".localized,
                            color: .green
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // 取消按钮
                Button("cancel".localized) {
                    dismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarHidden(true)
            .onChange(of: selectedPhotos) { _, newValue in
                if !newValue.isEmpty {
                    showingBatchProgress = true
                    batchOCRService.processImagesAndCreateRecords(
                        from: newValue,
                        modelContext: modelContext
                    ) {
                        // 处理完成后关闭整个添加流程
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingManualAdd, onDismiss: {
                // 手动添加完成后也关闭整个添加流程
                dismiss()
            }) {
                THManualAddHistoryView()
            }
            .sheet(isPresented: $showingBatchProgress) {
                BatchProgressView(service: batchOCRService)
                    .interactiveDismissDisabled(true)
            }
        }
    }
}

// MARK: - 选项按钮组件
struct OptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - 批量处理进度视图
struct BatchProgressView: View {
    @ObservedObject var service: THBatchOCRService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                
                Spacer()
                
                // 进度动画
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: service.currentProgress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: service.currentProgress)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "photo.artframe")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                            
                            Text("\(service.currentImageIndex)/\(service.totalImages)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("processing_medical_reports".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(service.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // 完成后的操作提示
                if !service.isProcessing {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("processing_completed".localized)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("records_created_format".localized(service.completedRecords.count))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("done".localized) {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarHidden(true)
        }
    }
}

#Preview("Options View") {
    THAddHistoryOptionsView()
        .modelContainer(for: THHistoryRecord.self)
}

#Preview("Manual Add") {
    THManualAddHistoryView()
        .modelContainer(for: THHistoryRecord.self)
}
