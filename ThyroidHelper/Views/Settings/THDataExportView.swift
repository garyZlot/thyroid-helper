//
//  THDataExportView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData
import UIKit

struct THDataExportView: View {
    @Query private var records: [THCheckupRecord]
    @State private var exportFormat = "CSV"
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isExporting = false
    
    var body: some View {
        Form {
            Section("export_format".localized) {
                Picker("file_format".localized, selection: $exportFormat) {
                    Text("CSV").tag("CSV")
                    Text("PDF").tag("PDF")
                    Text("JSON").tag("JSON")
                }
                .pickerStyle(.segmented)
            }
            
            Section("data_range".localized) {
                HStack {
                    Text("checkup_records".localized)
                    Spacer()
                    Text(String(format: "records_count_format".localized, records.count))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("time_range".localized)
                    Spacer()
                    if let earliest = records.min(by: { $0.date < $1.date }),
                       let latest = records.max(by: { $0.date < $1.date }) {
                        Text("\(earliest.date.formatted(date: .abbreviated, time: .omitted)) - \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("no_data".localized)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: exportData) {
                    if isExporting {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Label("export_data".localized, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(records.isEmpty || isExporting)
            }
            
            Section {
                Text("export_data_usage_hint".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("data_export".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("export_failed".localized, isPresented: $showingError) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func exportData() {
        guard !records.isEmpty else {
            errorMessage = "no_data_to_export".localized
            showingError = true
            return
        }
        
        isExporting = true
        
        // 使用异步任务确保文件完全写入
        Task {
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                // 生成安全的文件名
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let safeDateString = dateFormatter.string(from: Date())
                let fileName = "thyroid_export_\(safeDateString).\(exportFormat.lowercased())"
                
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                switch exportFormat {
                case "CSV":
                    try await exportToCSV(fileURL: fileURL)
                case "JSON":
                    try await exportToJSON(fileURL: fileURL)
                case "PDF":
                    try await exportToPDF(fileURL: fileURL)
                default:
                    break
                }
                
                // 确保文件存在且可读
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    // 在主线程更新UI
                    await MainActor.run {
                        exportURL = fileURL
                        showingShareSheet = true
                        isExporting = false
                    }
                } else {
                    throw NSError(domain: "export_error".localized, code: -1, userInfo: [NSLocalizedDescriptionKey: "file_creation_failed".localized])
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isExporting = false
                }
            }
        }
    }
    
    // MARK: - CSV导出
    private func exportToCSV(fileURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let csvHeader = "csv_header".localized
                    var csvString = "\(csvHeader)\n"
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    for record in self.records.sorted(by: { $0.date > $1.date }) {
                        let dateString = dateFormatter.string(from: record.date)
                        let notes = record.notes ?? ""
                        
                        if let indicators = record.indicators, !indicators.isEmpty {
                            // 按照standardOrder排序指标
                            let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                                let index1 = THConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                                let index2 = THConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                                return index1 < index2
                            }
                            
                            for indicator in sortedIndicators {
                                // 格式化数值
                                let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
                                let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                                
                                // 转义可能包含逗号的字段
                                let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
                                let escapedRange = indicator.normalRange.replacingOccurrences(of: "\"", with: "\"\"")
                                
                                csvString += "\(dateString),\(record.type.localizedName),\(indicator.name),\(formattedValue),\(indicator.unit),\"\(escapedRange)\",\(indicator.status.rawValue),\"\(escapedNotes)\"\n"
                            }
                        } else {
                            // 没有指标的情况
                            let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
                            csvString += "\(dateString),\(record.type.localizedName),,,,,\"\(escapedNotes)\"\n"
                        }
                    }
                    
                    // 确保使用UTF-8 with BOM来避免中文乱码
                    let bom = Data([0xEF, 0xBB, 0xBF])
                    let csvData = bom + csvString.data(using: .utf8)!
                    try csvData.write(to: fileURL)
                    
                    // 强制同步文件系统
                    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - JSON导出
    private func exportToJSON(fileURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var exportData: [[String: Any]] = []
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    dateFormatter.timeZone = TimeZone.current
                    
                    for record in self.records.sorted(by: { $0.date > $1.date }) {
                        var recordDict: [String: Any] = [
                            "id": record.id,
                            "date": dateFormatter.string(from: record.date),
                            "type": record.type.localizedName,
                            "notes": record.notes ?? ""
                        ]
                        
                        if let indicators = record.indicators {
                            // 按照standardOrder排序指标
                            let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                                let index1 = THConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                                let index2 = THConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                                return index1 < index2
                            }
                            
                            var indicatorsArray: [[String: Any]] = []
                            for indicator in sortedIndicators {
                                // 格式化数值
                                let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
                                let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                                
                                let indicatorDict: [String: Any] = [
                                    "name": indicator.name,
                                    "value": formattedValue,
                                    "unit": indicator.unit,
                                    "normalRange": indicator.normalRange,
                                    "status": indicator.status.rawValue
                                ]
                                indicatorsArray.append(indicatorDict)
                            }
                            recordDict["indicators"] = indicatorsArray
                        }
                        
                        exportData.append(recordDict)
                    }
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                    try jsonData.write(to: fileURL)
                    
                    // 强制同步文件系统
                    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - PDF导出
    private func exportToPDF(fileURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4尺寸
                    let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
                    
                    let data = renderer.pdfData { context in
                        context.beginPage()
                        
                        let title = "pdf_export_title".localized
                        let titleAttributes = [
                            NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20),
                            NSAttributedString.Key.foregroundColor: UIColor.black
                        ]
                        title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm"
                        let exportDate = String(format: "export_time_format".localized, dateFormatter.string(from: Date()))
                        let dateAttributes = [
                            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                            NSAttributedString.Key.foregroundColor: UIColor.gray
                        ]
                        exportDate.draw(at: CGPoint(x: 50, y: 80), withAttributes: dateAttributes)
                        
                        var yPosition: CGFloat = 120
                        
                        for record in self.records.sorted(by: { $0.date > $1.date }) {
                            // 检查是否需要换页
                            if yPosition > pageRect.height - 100 {
                                context.beginPage()
                                yPosition = 50
                            }
                            
                            // 记录标题
                            let recordDateFormatter = DateFormatter()
                            recordDateFormatter.dateFormat = "yyyy年MM月dd日"
                            let recordTitle = "\(recordDateFormatter.string(from: record.date)) - \(record.type.localizedName)"
                            
                            let recordAttributes = [
                                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16),
                                NSAttributedString.Key.foregroundColor: UIColor.darkGray
                            ]
                            recordTitle.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: recordAttributes)
                            
                            yPosition += 30
                            
                            if let indicators = record.indicators, !indicators.isEmpty {
                                // 按照standardOrder排序指标
                                let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                                    let index1 = THConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                                    let index2 = THConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                                    return index1 < index2
                                }
                                
                                for indicator in sortedIndicators {
                                    // 检查是否需要换页
                                    if yPosition > pageRect.height - 50 {
                                        context.beginPage()
                                        yPosition = 50
                                    }
                                    
                                    // 格式化数值
                                    let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
                                    let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                                    
                                    let indicatorText = String(format: "pdf_indicator_format".localized,
                                                             indicator.name,
                                                             formattedValue,
                                                             indicator.unit,
                                                             indicator.normalRange,
                                                             indicator.status.rawValue)
                                    
                                    let indicatorAttributes = [
                                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                                        NSAttributedString.Key.foregroundColor: UIColor.black
                                    ]
                                    indicatorText.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: indicatorAttributes)
                                    
                                    yPosition += 25
                                }
                            }
                            
                            // 添加备注
                            if let notes = record.notes, !notes.isEmpty {
                                // 检查是否需要换页
                                if yPosition > pageRect.height - 50 {
                                    context.beginPage()
                                    yPosition = 50
                                }
                                
                                let notesText = String(format: "pdf_notes_format".localized, notes)
                                let notesAttributes = [
                                    NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 14),
                                    NSAttributedString.Key.foregroundColor: UIColor.gray
                                ]
                                notesText.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: notesAttributes)
                                
                                yPosition += 30
                            }
                            
                            yPosition += 20 // 记录之间的间距
                        }
                    }
                    
                    try data.write(to: fileURL)
                    
                    // 强制同步文件系统
                    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
