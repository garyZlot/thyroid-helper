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
                        showingAddRecord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddRecordView(mode: .medicalRecord) 
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
            THImageViewer(imageDatas: record.allImageDatas,
                              initialIndex: selectedImageIndex)
        }
    }
}

#Preview {
    MedicalTimelineView()
        .modelContainer(for: MedicalHistoryRecord.self)
}
