//
//  THIndicatorsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import _SwiftData_SwiftUI

struct THIndicatorsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \THCheckupRecord.date, order: .reverse) private var records: [THCheckupRecord]
    @State private var showingAddRecord = false
    @State private var recordToEdit: THCheckupRecord?
    
    var body: some View {
        NavigationView {
            Group {
                if records.isEmpty {
                    VStack(spacing: 24) {
                        ContentUnavailableView(
                            "no_records_title".localized,
                            systemImage: "doc.text",
                            description: Text("no_records_description".localized)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, -8)
                        
                        Button(action: { showingAddRecord = true }) {
                            Text("add_checkup_indicator".localized)
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
                } else {
                    List {
                        ForEach(records) { record in
                            RecordRowView(record: record) {
                                recordToEdit = record
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("checkup_indicators_title".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRecord = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            THAddIndicatorView()
        }
        .sheet(item: $recordToEdit) { record in
            THEditIndicatorView(record: record)
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
    let record: THCheckupRecord
    let onEdit: () -> Void
    
    private var indicatorsForType: [THIndicatorRecord] {
        let indicatorNames = THConfig.indicatorsForType(record.type)
        return (record.indicators ?? [])
            .filter { indicatorNames.contains($0.name) }
            .sortedByMedicalOrder()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
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
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(indicatorsForType, id: \.name) { indicator in
                    VStack(spacing: 2) {
                        Text(indicator.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                        
                        Text(indicator.value, format: .number.precision(.fractionLength(THConfig.decimalPlaces(for: indicator.name))))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(colorForStatus(indicator.status))
                        
                        if let normalRange = indicator.standardNormalRange {
                            Text(String(format: "%.2f-%.2f", normalRange.0, normalRange.1))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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
    
    private func colorForStatus(_ status: THIndicatorRecord.IndicatorStatus) -> Color {
        switch status {
        case .normal: return .green
        case .high: return .red
        case .low: return .blue
        }
    }
    
    private func backgroundColorForStatus(_ status: THIndicatorRecord.IndicatorStatus) -> Color {
        switch status {
        case .normal: return .green.opacity(0.1)
        case .high: return .red.opacity(0.1)
        case .low: return .blue.opacity(0.1)
        }
    }
}
