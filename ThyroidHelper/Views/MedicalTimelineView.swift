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
                AddMedicalRecordView()
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
                
                // 检查图片
                if let imageData = record.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 200)
                        .clipped()
                        .cornerRadius(8)
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
    }
}

struct AddMedicalRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var date = Date()
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var recordType: MedicalHistoryRecord.RecordType = .ultrasound
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    DatePicker("检查时间", selection: $date, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                    
                    Picker("检查类型", selection: $recordType) {
                        ForEach(MedicalHistoryRecord.RecordType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("检查标题", text: $title, prompt: Text("例如：甲状腺B超检查"))
                }
                
                Section("检查图片") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 12) {
                            if let selectedImageData,
                               let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 100)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo")
                                                .font(.title2)
                                                .foregroundColor(.secondary)
                                            Text("点击选择图片")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                            }
                        }
                    }
                }
                
                Section("备注") {
                    TextField("备注信息", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加档案记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }
    
    private func saveRecord() {
        let record = MedicalHistoryRecord(
            date: date,
            title: title.isEmpty ? recordType.rawValue : title,
            imageData: selectedImageData,
            notes: notes
        )
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("保存档案记录失败: \(error)")
        }
    }
}

#Preview {
    MedicalTimelineView()
        .modelContainer(for: MedicalHistoryRecord.self)
}
