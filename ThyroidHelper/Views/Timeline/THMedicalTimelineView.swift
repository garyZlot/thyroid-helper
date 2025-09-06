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
    @Query(sort: \THMedicalHistoryRecord.date, order: .reverse) private var records: [THMedicalHistoryRecord]
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
                THAddRecordView(mode: .medicalRecord) 
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
    let record: THMedicalHistoryRecord
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
            THImageViewer(
                imageDatas: record.allImageDatas,
                initialIndex: selectedImageIndex
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    THMedicalTimelineView()
        .modelContainer(for: THMedicalHistoryRecord.self)
}
