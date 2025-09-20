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
    @State private var showingAddRecord = false
    @State private var recordToEdit: THHistoryRecord?
    
    var body: some View {
        NavigationView {
            VStack {
                if records.isEmpty {
                    ContentUnavailableView(
                        "no_history_title".localized,
                        systemImage: "clock",
                        description: Text("no_history_description".localized)
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
            .navigationTitle("history_nav_title".localized)
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
                THAddHistoryOptionsView()
            }
            .sheet(item: $recordToEdit) { record in
                THEditHistoryView(record: record)
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
    let record: THHistoryRecord
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

#Preview {
    THHistoryView()
        .modelContainer(for: THHistoryRecord.self)
}
