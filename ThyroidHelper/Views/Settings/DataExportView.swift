//
//  DataExportView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//


import SwiftUI
import SwiftData
import UIKit

struct DataExportView: View {
    @Query private var records: [CheckupRecord]
    @State private var exportFormat = "CSV"
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section("导出格式") {
                Picker("文件格式", selection: $exportFormat) {
                    Text("CSV").tag("CSV")
                    Text("PDF").tag("PDF")
                    Text("JSON").tag("JSON")
                }
                .pickerStyle(.segmented)
            }
            
            Section("数据范围") {
                HStack {
                    Text("检查记录")
                    Spacer()
                    Text("\(records.count) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("时间范围")
                    Spacer()
                    if let earliest = records.min(by: { $0.date < $1.date }),
                       let latest = records.max(by: { $0.date < $1.date }) {
                        Text("\(earliest.date.formatted(date: .abbreviated, time: .omitted)) - \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("无数据")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: exportData) {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(records.isEmpty)
            }
            
            Section {
                Text("导出的数据可用于备份或医生咨询")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("数据导出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("导出失败", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func exportData() {
        guard !records.isEmpty else {
            errorMessage = "没有数据可导出"
            showingError = true
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 生成安全的文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let safeDateString = dateFormatter.string(from: Date())
        let fileName = "thyroid_export_\(safeDateString).\(exportFormat.lowercased())"
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            switch exportFormat {
            case "CSV":
                try exportToCSV(fileURL: fileURL)
            case "JSON":
                try exportToJSON(fileURL: fileURL)
            case "PDF":
                try exportToPDF(fileURL: fileURL)
            default:
                break
            }
            
            exportURL = fileURL
            showingShareSheet = true
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // MARK: - CSV导出
    private func exportToCSV(fileURL: URL) throws {
        var csvString = "检查日期,检查类型,指标名称,指标值,单位,参考范围,状态,备注\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for record in records.sorted(by: { $0.date > $1.date }) {
            let dateString = dateFormatter.string(from: record.date)
            let notes = record.notes ?? ""
            
            if let indicators = record.indicators, !indicators.isEmpty {
                // 按照standardOrder排序指标
                let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                    let index1 = ThyroidConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                    let index2 = ThyroidConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                    return index1 < index2
                }
                
                for indicator in sortedIndicators {
                    // 格式化数值
                    let decimalPlaces = ThyroidConfig.decimalPlaces(for: indicator.name)
                    let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                    
                    // 转义可能包含逗号的字段
                    let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
                    let escapedRange = indicator.normalRange.replacingOccurrences(of: "\"", with: "\"\"")
                    
                    csvString += "\(dateString),\(record.type.rawValue),\(indicator.name),\(formattedValue),\(indicator.unit),\"\(escapedRange)\",\(indicator.status.rawValue),\"\(escapedNotes)\"\n"
                }
            } else {
                // 没有指标的情况
                let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
                csvString += "\(dateString),\(record.type.rawValue),,,,,\"\(escapedNotes)\"\n"
            }
        }
        
        // 确保使用UTF-8 with BOM来避免中文乱码
        let bom = Data([0xEF, 0xBB, 0xBF])
        let csvData = bom + csvString.data(using: .utf8)!
        try csvData.write(to: fileURL)
    }
    
    // MARK: - JSON导出
    private func exportToJSON(fileURL: URL) throws {
        var exportData: [[String: Any]] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        
        for record in records.sorted(by: { $0.date > $1.date }) {
            var recordDict: [String: Any] = [
                "id": record.id,
                "date": dateFormatter.string(from: record.date),
                "type": record.type.rawValue,
                "notes": record.notes ?? ""
            ]
            
            if let indicators = record.indicators {
                // 按照standardOrder排序指标
                let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                    let index1 = ThyroidConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                    let index2 = ThyroidConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                    return index1 < index2
                }
                
                var indicatorsArray: [[String: Any]] = []
                for indicator in sortedIndicators {
                    // 格式化数值
                    let decimalPlaces = ThyroidConfig.decimalPlaces(for: indicator.name)
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
    }
    
    // MARK: - PDF导出
    private func exportToPDF(fileURL: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4尺寸
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let title = "甲状腺检查记录导出"
            let titleAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm"
            let exportDate = "导出时间: \(dateFormatter.string(from: Date()))"
            let dateAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.gray
            ]
            exportDate.draw(at: CGPoint(x: 50, y: 80), withAttributes: dateAttributes)
            
            var yPosition: CGFloat = 120
            
            for record in records.sorted(by: { $0.date > $1.date }) {
                // 检查是否需要换页
                if yPosition > pageRect.height - 100 {
                    context.beginPage()
                    yPosition = 50
                }
                
                // 记录标题
                let recordDateFormatter = DateFormatter()
                recordDateFormatter.dateFormat = "yyyy年MM月dd日"
                let recordTitle = "\(recordDateFormatter.string(from: record.date)) - \(record.type.rawValue)"
                
                let recordAttributes = [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16),
                    NSAttributedString.Key.foregroundColor: UIColor.darkGray
                ]
                recordTitle.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: recordAttributes)
                
                yPosition += 30
                
                if let indicators = record.indicators, !indicators.isEmpty {
                    // 按照standardOrder排序指标
                    let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                        let index1 = ThyroidConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                        let index2 = ThyroidConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                        return index1 < index2
                    }
                    
                    for indicator in sortedIndicators {
                        // 检查是否需要换页
                        if yPosition > pageRect.height - 50 {
                            context.beginPage()
                            yPosition = 50
                        }
                        
                        // 格式化数值
                        let decimalPlaces = ThyroidConfig.decimalPlaces(for: indicator.name)
                        let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                        
                        let indicatorText = "\(indicator.name): \(formattedValue) \(indicator.unit) (参考范围: \(indicator.normalRange)) - \(indicator.status.rawValue)"
                        
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
                    
                    let notesText = "备注: \(notes)"
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
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
