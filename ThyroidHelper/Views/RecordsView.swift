//
//  RecordsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import _SwiftData_SwiftUI

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckupRecord.date, order: .reverse) private var records: [CheckupRecord]
    @State private var showingAddRecord = false
    
    var body: some View {
        NavigationStack {
            if records.isEmpty {
                ContentUnavailableView(
                    "暂无检查记录",
                    systemImage: "doc.text",
                    description: Text("添加您的第一条检查记录")
                )
            } else {
                List {
                    ForEach(records) { record in
                        RecordRowView(record: record)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete(perform: deleteRecords)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("检查记录")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddRecord = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            AddRecordView()
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(records[index])
            }
            try? modelContext.save()
        }
    }
}

struct RecordRowView: View {
    let record: CheckupRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.type.rawValue)
                        .font(.headline)
                    
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    if let abnormalCount = record.indicators?.filter { $0.status != .normal }.count {
                        if abnormalCount > 0 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(abnormalCount)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // 指标概览
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach((record.indicators ?? []).prefix(6).sorted(by: { $0.name < $1.name }), id: \.name) { indicator in
                    VStack(spacing: 2) {
                        Text(indicator.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        Text(indicator.value, format: .number.precision(.fractionLength(1)))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(colorForStatus(indicator.status))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(backgroundColorForStatus(indicator.status))
                    .cornerRadius(6)
                }
            }
            
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func colorForStatus(_ status: ThyroidIndicator.IndicatorStatus) -> Color {
        switch status {
        case .normal: return .green
        case .high: return .red
        case .low: return .blue
        }
    }
    
    private func backgroundColorForStatus(_ status: ThyroidIndicator.IndicatorStatus) -> Color {
        switch status {
        case .normal: return .green.opacity(0.1)
        case .high: return .red.opacity(0.1)
        case .low: return .blue.opacity(0.1)
        }
    }
}
