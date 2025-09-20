//
//  Untitled.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/20.
//

import SwiftUI
import SwiftData

struct THEditIndicatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let record: THCheckupRecord
    
    @State private var selectedDate: Date
    @State private var notes: String
    @State private var indicators: [String: IndicatorInput] = [:]
    
    struct IndicatorInput {
        var value: String = ""
        var unit: String
        var normalRange: String
        var isValid: Bool { !value.isEmpty && Double(value) != nil }
        var doubleValue: Double { Double(value) ?? 0 }
    }
    
    init(record: THCheckupRecord) {
        self.record = record
        _selectedDate = State(initialValue: record.date)
        _notes = State(initialValue: record.notes ?? "")
    }
    
    private var indicatorsForType: [String] {
        THConfig.indicatorsForType(record.type)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("section_checkup_info".localized) {
                    DatePicker("checkup_date".localized, selection: $selectedDate, displayedComponents: .date)
                }
                
                Section {
                    ForEach(indicatorsForType, id: \.self) { indicatorName in
                        IndicatorEditRow(
                            name: indicatorName,
                            input: Binding(
                                get: { indicators[indicatorName] ?? defaultIndicatorInput(for: indicatorName) },
                                set: { indicators[indicatorName] = $0 }
                            )
                        )
                    }
                }
                
                Section("section_notes".localized) {
                    TextField("notes_placeholder".localized, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(record.type.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) { saveChanges() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                setupIndicatorsFromRecord()
            }
        }
    }
    
    private var canSave: Bool {
        indicatorsForType.allSatisfy { indicatorName in
            guard let input = indicators[indicatorName] else { return false }
            return input.isValid
        }
    }
    
    private func setupIndicatorsFromRecord() {
        indicators.removeAll()
        for indicator in (record.indicators ?? []).sortedByMedicalOrder() {
            let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
            indicators[indicator.name] = IndicatorInput(
                value: String(format: "%.\(decimalPlaces)f", indicator.value),
                unit: indicator.unit,
                normalRange: indicator.normalRange
            )
        }
        for indicatorName in indicatorsForType {
            if indicators[indicatorName] == nil {
                indicators[indicatorName] = defaultIndicatorInput(for: indicatorName)
            }
        }
    }
    
    private func defaultIndicatorInput(for name: String) -> IndicatorInput {
        let tempIndicator = THIndicatorRecord(name: name, value: 0, unit: "", normalRange: "", status: .normal)
        let normalRange = tempIndicator.standardNormalRange
        let rangeString = normalRange.map { "\($0.0)-\($0.1)" } ?? ""
        
        return IndicatorInput(
            unit: tempIndicator.standardUnit,
            normalRange: rangeString
        )
    }
    
    private func saveChanges() {
        record.date = selectedDate
        record.notes = notes.isEmpty ? nil : notes
        
        if let existingIndicators = record.indicators {
            for indicator in existingIndicators {
                modelContext.delete(indicator)
            }
        }
        record.indicators = []
        
        for indicatorName in indicatorsForType {
            guard let input = indicators[indicatorName], input.isValid else { continue }
            
            let status = THIndicatorRecord.determineStatus(value: input.doubleValue, normalRange: input.normalRange)
            let indicator = THIndicatorRecord(
                name: indicatorName,
                value: input.doubleValue,
                unit: input.unit,
                normalRange: input.normalRange,
                status: status
            )
            indicator.checkupRecord = record
            record.indicators?.append(indicator)
            modelContext.insert(indicator)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("save_failed_format".localized(error.localizedDescription))
        }
    }
}

// MARK: - 编辑指标输入行
struct IndicatorEditRow: View {
    let name: String
    @Binding var input: THEditIndicatorView.IndicatorInput
    
    private var displayName: String {
        let tempIndicator = THIndicatorRecord(name: name, value: 0, unit: "", normalRange: "", status: .normal)
        return tempIndicator.fullDisplayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.headline)
            
            HStack {
                TextField("value_placeholder".localized, text: $input.value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                
                Text(input.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
            }
            
            Text("reference_range_format".localized(input.normalRange))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
