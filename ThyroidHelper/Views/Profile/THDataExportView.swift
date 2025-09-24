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
    @Query private var checkupRecords: [THCheckupRecord]
    @Query private var historyRecords: [THHistoryRecord]
    @State private var exportFormat = "CSV"
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isExporting = false
    
    var body: some View {
        Form {
            // 主要功能 - 检查记录导出
            Section("checkup_data_export".localized) {
                Picker("file_format".localized, selection: $exportFormat) {
                    Text("CSV").tag("CSV")
                    Text("PDF").tag("PDF")
                    Text("JSON").tag("JSON")
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("checkup_records".localized)
                    Spacer()
                    Text(String(format: "records_count_format".localized, checkupRecords.count))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("time_range".localized)
                    Spacer()
                    if let earliest = checkupRecords.min(by: { $0.date < $1.date }),
                       let latest = checkupRecords.max(by: { $0.date < $1.date }) {
                        Text("\(earliest.date.formatted(date: .abbreviated, time: .omitted)) - \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("no_data".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: exportCheckupData) {
                    if isExporting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("exporting".localized)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Label("export_checkup_data".localized, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(checkupRecords.isEmpty || isExporting)
            }
            
            // 次要功能 - 历史记录导出
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("history_records_export".localized)
                            .font(.subheadline)
                        Text("pdf_format_only".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "records_count_format".localized, historyRecords.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: exportHistoryData) {
                    if isExporting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("exporting".localized)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Label("export_history_records".localized, systemImage: "doc.richtext")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(historyRecords.isEmpty || isExporting)
            } header: {
                Text("additional_exports".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
    
    // MARK: - 检查记录导出
    private func exportCheckupData() {
        guard !checkupRecords.isEmpty else {
            errorMessage = "no_data_to_export".localized
            showingError = true
            return
        }
        
        isExporting = true
        
        Task {
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let safeDateString = dateFormatter.string(from: Date())
                let fileName = "thyroid_checkup_export_\(safeDateString).\(exportFormat.lowercased())"
                
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                switch exportFormat {
                case "CSV":
                    try await exportCheckupToCSV(fileURL: fileURL)
                case "JSON":
                    try await exportCheckupToJSON(fileURL: fileURL)
                case "PDF":
                    try await exportCheckupToPDF(fileURL: fileURL)
                default:
                    break
                }
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
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
    
    // MARK: - 历史记录导出
    private func exportHistoryData() {
        guard !historyRecords.isEmpty else {
            errorMessage = "no_history_data_to_export".localized
            showingError = true
            return
        }
        
        isExporting = true
        
        Task {
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let safeDateString = dateFormatter.string(from: Date())
                let fileName = "thyroid_history_export_\(safeDateString).pdf"
                
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                try await exportHistoryToPDF(fileURL: fileURL)
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
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
    
    // MARK: - 检查记录CSV导出
    private func exportCheckupToCSV(fileURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let csvHeader = "csv_header".localized
                    var csvString = "\(csvHeader)\n"
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    for record in self.checkupRecords.sorted(by: { $0.date > $1.date }) {
                        let dateString = dateFormatter.string(from: record.date)
                        let notes = record.notes ?? ""
                        
                        if let indicators = record.indicators, !indicators.isEmpty {
                            let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                                let index1 = THConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                                let index2 = THConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                                return index1 < index2
                            }
                            
                            for indicator in sortedIndicators {
                                let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
                                let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                                
                                let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
                                let escapedRange = indicator.normalRange.replacingOccurrences(of: "\"", with: "\"\"")
                                
                                csvString += "\(dateString),\(record.type.localizedName),\(indicator.name),\(formattedValue),\(indicator.unit),\"\(escapedRange)\",\(indicator.status.localizedName),\"\(escapedNotes)\"\n"
                            }
                        } else {
                            let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
                            csvString += "\(dateString),\(record.type.localizedName),,,,,\"\(escapedNotes)\"\n"
                        }
                    }
                    
                    let bom = Data([0xEF, 0xBB, 0xBF])
                    let csvData = bom + csvString.data(using: .utf8)!
                    try csvData.write(to: fileURL)
                    
                    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 检查记录JSON导出
    private func exportCheckupToJSON(fileURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var exportData: [[String: Any]] = []
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    dateFormatter.timeZone = TimeZone.current
                    
                    for record in self.checkupRecords.sorted(by: { $0.date > $1.date }) {
                        var recordDict: [String: Any] = [
                            "id": record.id,
                            "date": dateFormatter.string(from: record.date),
                            "type": record.type.localizedName,
                            "notes": record.notes ?? ""
                        ]
                        
                        if let indicators = record.indicators {
                            let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                                let index1 = THConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                                let index2 = THConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                                return index1 < index2
                            }
                            
                            var indicatorsArray: [[String: Any]] = []
                            for indicator in sortedIndicators {
                                let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
                                let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                                
                                let indicatorDict: [String: Any] = [
                                    "name": indicator.name,
                                    "value": formattedValue,
                                    "unit": indicator.unit,
                                    "normalRange": indicator.normalRange,
                                    "status": indicator.status.localizedName
                                ]
                                indicatorsArray.append(indicatorDict)
                            }
                            recordDict["indicators"] = indicatorsArray
                        }
                        
                        exportData.append(recordDict)
                    }
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                    try jsonData.write(to: fileURL)
                    
                    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 检查记录PDF导出
    private func exportCheckupToPDF(fileURL: URL) async throws {
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
                        
                        for record in self.checkupRecords.sorted(by: { $0.date > $1.date }) {
                            if yPosition > pageRect.height - 100 {
                                context.beginPage()
                                yPosition = 50
                            }
                            
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
                                let sortedIndicators = indicators.sorted { indicator1, indicator2 in
                                    let index1 = THConfig.standardOrder.firstIndex(of: indicator1.name) ?? Int.max
                                    let index2 = THConfig.standardOrder.firstIndex(of: indicator2.name) ?? Int.max
                                    return index1 < index2
                                }
                                
                                for indicator in sortedIndicators {
                                    if yPosition > pageRect.height - 50 {
                                        context.beginPage()
                                        yPosition = 50
                                    }
                                    
                                    let decimalPlaces = THConfig.decimalPlaces(for: indicator.name)
                                    let formattedValue = indicator.value.formatted(decimalPlaces: decimalPlaces)
                                    
                                    let indicatorText = String(format: "pdf_indicator_format".localized,
                                                             indicator.name,
                                                             formattedValue,
                                                             indicator.unit,
                                                             indicator.normalRange,
                                                             indicator.status.localizedName)
                                    
                                    let indicatorAttributes = [
                                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                                        NSAttributedString.Key.foregroundColor: UIColor.black
                                    ]
                                    indicatorText.draw(at: CGPoint(x: 70, y: yPosition), withAttributes: indicatorAttributes)
                                    
                                    yPosition += 25
                                }
                            }
                            
                            if let notes = record.notes, !notes.isEmpty {
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
                            
                            yPosition += 20
                        }
                    }
                    
                    try data.write(to: fileURL)
                    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 历史记录PDF导出
    private func exportHistoryToPDF(fileURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4尺寸
                    let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
                    let margins: CGFloat = 40
                    let contentWidth = pageRect.width - 2 * margins
                    
                    let data = renderer.pdfData { context in
                        var yPosition: CGFloat = margins
                        var isFirstPage = true
                        
                        // 开始第一页
                        context.beginPage()
                        
                        // 标题
                        let title = "history_records_pdf_title".localized
                        let titleAttributes = [
                            NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 24),
                            NSAttributedString.Key.foregroundColor: UIColor.black
                        ]
                        title.draw(at: CGPoint(x: margins, y: yPosition), withAttributes: titleAttributes)
                        yPosition += 40
                        
                        // 导出时间
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm"
                        let exportDate = String(format: "export_time_format".localized, dateFormatter.string(from: Date()))
                        let dateAttributes = [
                            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                            NSAttributedString.Key.foregroundColor: UIColor.gray
                        ]
                        exportDate.draw(at: CGPoint(x: margins, y: yPosition), withAttributes: dateAttributes)
                        yPosition += 40
                        
                        let recordDateFormatter = DateFormatter()
                        recordDateFormatter.dateFormat = "yyyy年MM月dd日"
                        
                        // 按时间降序排序历史记录
                        let sortedHistoryRecords = self.historyRecords.sorted { $0.date > $1.date }
                        
                        for (index, record) in sortedHistoryRecords.enumerated() {
                            // 检查页面空间，预留足够空间给标题和部分内容
                            let requiredSpace: CGFloat = 150 // 标题 + 部分内容的最小空间
                            if yPosition > pageRect.height - requiredSpace {
                                context.beginPage()
                                yPosition = margins
                                isFirstPage = false
                            }
                            
                            // 记录标题
                            let recordTitle = "\(index + 1). \(record.title)"
                            let titleRect = CGRect(x: margins, y: yPosition, width: contentWidth, height: 30)
                            let titleAttributes = [
                                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18),
                                NSAttributedString.Key.foregroundColor: UIColor.black
                            ]
                            recordTitle.draw(in: titleRect, withAttributes: titleAttributes)
                            yPosition += 35
                            
                            // 记录日期
                            let dateText = recordDateFormatter.string(from: record.date)
                            let dateTextAttributes = [
                                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                                NSAttributedString.Key.foregroundColor: UIColor.gray
                            ]
                            dateText.draw(at: CGPoint(x: margins, y: yPosition), withAttributes: dateTextAttributes)
                            yPosition += 25
                            
                            // 处理图片 - 放大显示确保清晰度
                            if !record.imageDatas.isEmpty {
                                for (imageIndex, imageData) in record.imageDatas.enumerated() {
                                    if let image = UIImage(data: imageData) {
                                        // 计算合适的图片尺寸 - 占用更多页面空间以确保清晰度
                                        let maxImageWidth = contentWidth
                                        let maxImageHeight: CGFloat = 400 // 增加最大高度
                                        
                                        let imageAspectRatio = image.size.width / image.size.height
                                        var imageWidth = maxImageWidth
                                        var imageHeight = imageWidth / imageAspectRatio
                                        
                                        if imageHeight > maxImageHeight {
                                            imageHeight = maxImageHeight
                                            imageWidth = imageHeight * imageAspectRatio
                                        }
                                        
                                        // 检查是否需要换页
                                        if yPosition + imageHeight > pageRect.height - margins {
                                            context.beginPage()
                                            yPosition = margins
                                        }
                                        
                                        // 绘制图片
                                        let imageRect = CGRect(
                                            x: margins + (contentWidth - imageWidth) / 2, // 居中
                                            y: yPosition,
                                            width: imageWidth,
                                            height: imageHeight
                                        )
                                        
                                        // 添加图片边框
                                        let borderRect = imageRect.insetBy(dx: -1, dy: -1)
                                        UIColor.lightGray.setStroke()
                                        let borderPath = UIBezierPath(rect: borderRect)
                                        borderPath.lineWidth = 1
                                        borderPath.stroke()
                                        
                                        // 绘制图片
                                        image.draw(in: imageRect)
                                        
                                        yPosition += imageHeight + 15
                                        
                                        // 如果有多张图片，添加图片标号
                                        if record.imageDatas.count > 1 {
                                            let imageLabel = "图片 \(imageIndex + 1)"
                                            let labelAttributes = [
                                                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                                                NSAttributedString.Key.foregroundColor: UIColor.gray
                                            ]
                                            imageLabel.draw(at: CGPoint(x: margins + (contentWidth - imageWidth) / 2, y: yPosition), withAttributes: labelAttributes)
                                            yPosition += 20
                                        }
                                    }
                                }
                            }
                            
                            // 备注内容
                            if !record.notes.isEmpty {
                                // 检查是否需要换页
                                if yPosition > pageRect.height - 100 {
                                    context.beginPage()
                                    yPosition = margins
                                }
                                
                                let notesTitle = "备注："
                                let notesTitleAttributes = [
                                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14),
                                    NSAttributedString.Key.foregroundColor: UIColor.darkGray
                                ]
                                notesTitle.draw(at: CGPoint(x: margins, y: yPosition), withAttributes: notesTitleAttributes)
                                yPosition += 20
                                
                                // 计算备注文本需要的高度
                                let notesAttributes = [
                                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                                    NSAttributedString.Key.foregroundColor: UIColor.black
                                ]
                                
                                let availableHeight = pageRect.height - yPosition - margins
                                let notesRect = CGRect(x: margins, y: yPosition, width: contentWidth, height: availableHeight)
                                
                                let notesString = NSAttributedString(string: record.notes, attributes: notesAttributes)
                                let textSize = notesString.boundingRect(
                                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                    context: nil
                                ).size
                                
                                // 如果文本太长需要换页
                                if textSize.height > availableHeight - 20 {
                                    context.beginPage()
                                    yPosition = margins
                                }
                                
                                let finalNotesRect = CGRect(x: margins, y: yPosition, width: contentWidth, height: textSize.height)
                                notesString.draw(in: finalNotesRect)
                                yPosition += textSize.height + 30
                            }
                            
                            // 记录之间的分隔线和间距
                            yPosition += 10
                            if index < sortedHistoryRecords.count - 1 {
                                // 绘制分隔线
                                let separatorY = yPosition
                                UIColor.lightGray.setStroke()
                                let separatorPath = UIBezierPath()
                                separatorPath.move(to: CGPoint(x: margins, y: separatorY))
                                separatorPath.addLine(to: CGPoint(x: pageRect.width - margins, y: separatorY))
                                separatorPath.lineWidth = 0.5
                                separatorPath.stroke()
                                
                                yPosition += 20
                            }
                        }
                    }
                    
                    try data.write(to: fileURL)
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
