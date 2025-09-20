//
//  THIndicatorOCRService.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

@preconcurrency import Vision
import UIKit
import Foundation
import os.log

/// 改进的OCR 识别服务
@MainActor
class THIndicatorOCRService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var extractedIndicators: [String: Double] = [:]
    @Published var extractedDate: Date?
    @Published var errorMessage: String?
    
    /// 当前识别指标，外部可以根据检查类型传入
    var indicatorKeys: [String]
    
    /// 日志记录器
    private let logger = Logger(subsystem: "ThyroidHelper", category: "OCR")
    
    init(indicatorKeys: [String]? = nil) {
        // 如果没传就用标准顺序
        self.indicatorKeys = indicatorKeys ?? THConfig.standardOrder
        logger.info("📋 OCR服务初始化，目标指标: \(self.indicatorKeys)")
    }
    
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "图片处理失败"
            logger.error("❌ 图片处理失败：无法获取CGImage")
            return
        }
        
        logger.info("🖼️ 开始处理图片，尺寸: \(image.size.width)x\(image.size.height)")
        
        isProcessing = true
        errorMessage = nil
        recognizedText = ""
        extractedIndicators.removeAll()
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleOCRResult(request: request, error: error)
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        
        logger.info("⚙️ OCR配置：精确识别，支持中英文，启用语言校正")
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "OCR识别失败: \(error.localizedDescription)"
                    self.isProcessing = false
                    self.logger.error("❌ OCR识别异常: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleOCRResult(request: VNRequest, error: Error?) {
        isProcessing = false
        
        if let error = error {
            errorMessage = "识别错误: \(error.localizedDescription)"
            logger.error("❌ OCR识别错误: \(error.localizedDescription)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            errorMessage = "无法获取识别结果"
            logger.error("❌ 无法获取VNRecognizedTextObservation结果")
            return
        }
        
        logger.info("📝 OCR识别完成，获得 \(observations.count) 个文本块")
        
        // 提取表格数据
        let tableData = extractTableData(from: observations)
        recognizedText = tableData.allText
        
        logger.info("📄 识别文本:\n\(self.recognizedText)")
        logger.info("🔍 开始提取指标数值...")
        
        extractIndicatorsFromTable(tableData: tableData)
        extractedDate = THDateExtractionService.extractDate(from: recognizedText)
    }
    
    /// 表格数据结构
    struct TableCell {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
        var row: Int = -1
        var column: Int = -1
    }
    
    struct TableData {
        let cells: [TableCell]
        let allText: String
        let rows: [[TableCell]]
    }
    
    /// 从OCR结果中提取表格数据
    private func extractTableData(from observations: [VNRecognizedTextObservation]) -> TableData {
        // 转换为TableCell
        var cells: [TableCell] = []
        for observation in observations {
            if let text = observation.topCandidates(1).first?.string {
                let cell = TableCell(
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
                if !cell.text.isEmpty {
                    cells.append(cell)
                }
            }
        }
        
        // 改进的排序和分行逻辑
        logger.info("🔍 开始改进的文本块排序...")
        
        // 首先按Y坐标排序（从上到下）
        let sortedByY = cells.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        
        // 使用聚类算法进行行分组
        var rows: [[TableCell]] = []
        var remainingCells = sortedByY
        
        while !remainingCells.isEmpty {
            let firstCell = remainingCells.removeFirst()
            var currentRow = [firstCell]
            let rowY = firstCell.boundingBox.midY
            
            logger.debug("  🆕 开始新行，基准Y: \(String(format: "%.3f", rowY))")
            
            // 找出与当前行Y坐标相近的所有cell
            var i = 0
            while i < remainingCells.count {
                let cell = remainingCells[i]
                let cellY = cell.boundingBox.midY
                let yDistance = abs(cellY - rowY)
                
                // 使用动态阈值：对于小文本使用更小的阈值
                let heightThreshold = min(firstCell.boundingBox.height, cell.boundingBox.height) * 0.5
                let yThreshold = max(0.015, heightThreshold)
                
                if yDistance <= yThreshold {
                    currentRow.append(cell)
                    remainingCells.remove(at: i)
                    logger.debug("    ➕ 添加到当前行: '\(cell.text)' (Y距离: \(String(format: "%.3f", yDistance)))")
                } else {
                    i += 1
                }
            }
            
            // 对当前行按X坐标排序（从左到右）
            currentRow.sort { $0.boundingBox.minX < $1.boundingBox.minX }
            rows.append(currentRow)
            
            logger.debug("  ✅ 行完成，包含 \(currentRow.count) 个元素")
        }
        
        // 再次检查和优化行分组
        rows = optimizeRowGrouping(rows: rows)
        
        // 为每个cell标记行列信息
        var cellsWithPosition: [TableCell] = []
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, cell) in row.enumerated() {
                var updatedCell = cell
                updatedCell.row = rowIndex
                updatedCell.column = colIndex
                cellsWithPosition.append(updatedCell)
            }
        }
        
        let allText = rows.map { row in
            row.map { $0.text }.joined(separator: " ")
        }.joined(separator: "\n")
        
        logger.info("📊 表格解析完成：\(rows.count)行")
        for (i, row) in rows.enumerated() {
            logger.debug("行[\(i)]: \(row.map { $0.text }.joined(separator: " | "))")
        }
        
        return TableData(cells: cellsWithPosition, allText: allText, rows: rows)
    }
    
    /// 优化行分组
    private func optimizeRowGrouping(rows: [[TableCell]]) -> [[TableCell]] {
        var optimizedRows: [[TableCell]] = []
        
        for row in rows {
            if row.count == 1 {
                // 单个cell的行，检查是否应该合并到前一行
                let cell = row[0]
                
                if let lastRowIndex = optimizedRows.indices.last,
                   let lastRow = optimizedRows.last,
                   !lastRow.isEmpty {
                    
                    // 计算与上一行的Y距离
                    let lastRowMaxY = lastRow.map { $0.boundingBox.maxY }.max() ?? 0
                    let lastRowMinY = lastRow.map { $0.boundingBox.minY }.min() ?? 0
                    let lastRowMidY = (lastRowMaxY + lastRowMinY) / 2
                    
                    let currentCellY = cell.boundingBox.midY
                    let yDistance = abs(currentCellY - lastRowMidY)
                    
                    // 如果距离很近，考虑合并
                    if yDistance < 0.025 {
                        // 检查X位置是否合理
                        let lastRowMaxX = lastRow.map { $0.boundingBox.maxX }.max() ?? 0
                        let currentCellX = cell.boundingBox.minX
                        
                        // 如果在合理的X位置范围内，合并到上一行
                        if currentCellX >= lastRowMaxX - 0.1 {
                            optimizedRows[lastRowIndex].append(cell)
                            // 重新按X排序
                            optimizedRows[lastRowIndex].sort { $0.boundingBox.minX < $1.boundingBox.minX }
                            logger.debug("  🔗 合并单元格到上一行: '\(cell.text)'")
                            continue
                        }
                    }
                }
            }
            
            // 不合并，作为独立行添加
            optimizedRows.append(row)
        }
        
        return optimizedRows
    }
    
    /// 从表格数据中提取指标
    private func extractIndicatorsFromTable(tableData: TableData) {
        extractedIndicators.removeAll()
        
        // 方法1：基于关键字的精确匹配
        logger.info("🎯 方法1: 表格关键字匹配...")
        extractByTableKeywordMatching(tableData: tableData)
        
        let keywordMatchCount = extractedIndicators.count
        logger.info("✅ 关键字匹配完成，提取到 \(keywordMatchCount) 个指标")
        
        // 方法2：如果关键字匹配不足，尝试模式匹配
        if extractedIndicators.count < indicatorKeys.count {
            logger.info("🎯 方法2: 数值模式匹配...")
            extractByValuePatternMatching(tableData: tableData)
        }
        
        // 方法3：如果仍然不足，尝试位置推断
        if extractedIndicators.count < indicatorKeys.count {
            logger.info("🎯 方法3: 位置推断匹配...")
            extractByPositionInference(tableData: tableData)
        }
        
        logger.info("🏁 最终提取结果:")
        for key in indicatorKeys {
            if let value = extractedIndicators[key] {
                logger.info("  ✓ \(key): \(value)")
            } else {
                logger.warning("  ✗ \(key): 未找到")
            }
        }
    }
    
    /// 方法1：基于表格的关键字匹配（修改：支持在相邻行查找数值）
    private func extractByTableKeywordMatching(tableData: TableData) {
        for (rowIndex, row) in tableData.rows.enumerated() {
            // 查找包含指标关键字的cell
            for (cellIndex, cell) in row.enumerated() {
                for indicator in indicatorKeys {
                    if cell.text.contains(indicator) && extractedIndicators[indicator] == nil {
                        logger.info("🎯 在行中找到指标 '\(indicator)': '\(cell.text)'")
                        
                        // 在同一行中查找数值
                        if let value = findValueInRow(row: row, excludeIndex: cellIndex, indicator: indicator) {
                            extractedIndicators[indicator] = value
                            logger.info("  ✅ 同行匹配成功: \(indicator) = \(value)")
                        } else if let nearbyValue = findValueInNearbyRows(tableData: tableData, rowIndex: rowIndex, excludeIndex: cellIndex, indicator: indicator) {
                            // 🆕 如果同行没有，尝试在相邻行查找（例如 FT4 的结果在下一行）
                            extractedIndicators[indicator] = nearbyValue
                            logger.info("  ✅ 相邻行匹配成功: \(indicator) = \(nearbyValue)")
                        } else {
                            logger.warning("  ❌ 同行及相邻行未找到合适数值")
                        }
                    }
                }
            }
        }
    }

    /// 🆕 从相邻行查找数值（优先搜索下一行，再上一行，向外扩展两行）
    private func findValueInNearbyRows(tableData: TableData, rowIndex: Int, excludeIndex: Int, indicator: String) -> Double? {
        let offsets = [1, -1, 2, -2]
        for offset in offsets {
            let idx = rowIndex + offset
            if idx < 0 || idx >= tableData.rows.count { continue }
            let nearbyRow = tableData.rows[idx]
            for cell in nearbyRow {
                // 跳过明显是范围的文本（如 "10.44-24.38"）
                if cell.text.range(of: #"^\s*\d+(\.\d+)?\s*-\s*\d+(\.\d+)?\s*$"#, options: .regularExpression) != nil {
                    continue
                }
                if let value = extractNumberFromText(cell.text),
                   isReasonableThyroidValue(value: value, indicator: indicator) {
                    logger.debug("    🔎 在相邻行[\(idx)]找到数值 '\(cell.text)' -> \(value)")
                    return value
                }
            }
        }
        return nil
    }

    
    /// 方法2：基于数值模式的匹配
    private func extractByValuePatternMatching(tableData: TableData) {
        // 查找看起来像结果列的数值
        var candidateValues: [(indicator: String, value: Double, confidence: Float)] = []
        
        for row in tableData.rows {
            // 查找这行是否包含指标
            let indicatorInRow = indicatorKeys.first { indicator in
                row.contains { $0.text.contains(indicator) }
            }
            
            if let indicator = indicatorInRow, extractedIndicators[indicator] == nil {
                // 查找这行中的数值
                for cell in row {
                    if let value = extractNumberFromText(cell.text),
                       isReasonableThyroidValue(value: value, indicator: indicator) {
                        candidateValues.append((indicator: indicator, value: value, confidence: cell.confidence))
                    }
                }
            }
        }
        
        // 按置信度排序，选择最佳匹配
        candidateValues.sort { $0.confidence > $1.confidence }
        
        for candidate in candidateValues {
            if extractedIndicators[candidate.indicator] == nil {
                extractedIndicators[candidate.indicator] = candidate.value
                logger.info("  ✅ 模式匹配成功: \(candidate.indicator) = \(candidate.value)")
            }
        }
    }
    
    /// 方法3：基于位置推断的匹配
    private func extractByPositionInference(tableData: TableData) {
        // 查找"结果"列或类似的列标题
        var resultColumnIndex: Int?
        
        for row in tableData.rows {
            for (index, cell) in row.enumerated() {
                if cell.text.contains("结果") || cell.text.contains("值") ||
                   cell.text.lowercased().contains("result") {
                    resultColumnIndex = index
                    logger.info("📍 找到结果列，索引: \(index)")
                    break
                }
            }
            if resultColumnIndex != nil { break }
        }
        
        // 如果没找到结果列，尝试推断
        if resultColumnIndex == nil {
            // 查找最右边包含数值的列
            var maxColumn = -1
            for row in tableData.rows {
                for (index, cell) in row.enumerated() {
                    if extractNumberFromText(cell.text) != nil {
                        maxColumn = max(maxColumn, index)
                    }
                }
            }
            if maxColumn >= 0 {
                resultColumnIndex = maxColumn
                logger.info("📍 推断结果列，索引: \(maxColumn)")
            }
        }
        
        guard let columnIndex = resultColumnIndex else {
            logger.warning("❌ 无法确定结果列位置")
            return
        }
        
        // 按指标顺序匹配
        var indicatorRowMap: [String: Int] = [:]
        for (rowIndex, row) in tableData.rows.enumerated() {
            for indicator in indicatorKeys {
                if row.contains(where: { $0.text.contains(indicator) }) {
                    indicatorRowMap[indicator] = rowIndex
                }
            }
        }
        
        for indicator in indicatorKeys {
            if let rowIndex = indicatorRowMap[indicator],
               extractedIndicators[indicator] == nil,
               rowIndex < tableData.rows.count,
               columnIndex < tableData.rows[rowIndex].count {
                
                let cell = tableData.rows[rowIndex][columnIndex]
                if let value = extractNumberFromText(cell.text),
                   isReasonableThyroidValue(value: value, indicator: indicator) {
                    extractedIndicators[indicator] = value
                    logger.info("  ✅ 位置推断成功: \(indicator) = \(value)")
                }
            }
        }
    }
    
    /// 在行中查找数值
    private func findValueInRow(row: [TableCell], excludeIndex: Int, indicator: String) -> Double? {
        for (index, cell) in row.enumerated() {
            if index != excludeIndex {
                if let value = extractNumberFromText(cell.text),
                   isReasonableThyroidValue(value: value, indicator: indicator) {
                    return value
                }
            }
        }
        return nil
    }
    
    /// 改进的数值提取函数
    private func extractNumberFromText(_ text: String) -> Double? {
        // 处理特殊格式：<1.30, >100, 0.269+等
        let cleanText = text
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🆕 跳过包含范围符号的文本（如 "10.44-24.38"）
        if cleanText.contains("-"),
           let _ = cleanText.range(of: #"^\s*\d+(\.\d+)?\s*-\s*\d+(\.\d+)?\s*$"#, options: .regularExpression) {
            logger.debug("    ⏭️ 跳过范围文本: '\(text)'")
            return nil
        }
        
        // 正则匹配数字（包括小数）- 优先匹配小数
        let patterns = [
            "([0-9]+\\.[0-9]+)",  // 优先匹配小数
            "([0-9]+)"            // 然后匹配整数
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: cleanText.utf16.count)
                
                if let match = regex.firstMatch(in: cleanText, range: range),
                   let valueRange = Range(match.range, in: cleanText) {
                    let valueString = String(cleanText[valueRange])
                    if let result = Double(valueString) {
                        logger.debug("    🔢 从'\(text)'中提取数值: '\(valueString)' -> \(result)")
                        return result
                    }
                }
            } catch {
                logger.error("❌ 正则表达式错误: \(error)")
            }
        }
        return nil
    }

    
    /// 根据 THConfig.indicatorSettings 的范围判断是否合理
    private func isReasonableThyroidValue(value: Double, indicator: String) -> Bool {
        // 过滤明显不是测量结果的数值（如序号）
        if value < 0.001 || value == 1.0 || value == 2.0 || value == 3.0 || value == 4.0 || value == 5.0 {
            logger.debug("      ❌ 疑似序号，被过滤: \(value)")
            return false
        }
        
        if let setting = THConfig.indicatorSettings[indicator] {
            let minValue = setting.normalRange.lower * 0.01  // 更宽松的下限
            let maxValue = setting.normalRange.upper * 100.0  // 更宽松的上限
            let isReasonable = value >= minValue && value <= maxValue
            
            if isReasonable {
                logger.debug("      ✅ 数值合理: \(value) 在范围 \(minValue) - \(maxValue)")
            } else {
                logger.debug("      ❌ 数值不合理: \(value) 不在范围 \(minValue) - \(maxValue)")
            }
            
            return isReasonable
        } else {
            let isReasonable = value >= 0.01 && value <= 10000
            logger.debug("      ⚠️ 未找到指标配置，使用默认范围: \(value) 在 0.01-10000? \(isReasonable)")
            return isReasonable
        }
    }
    
    func reset() {
        logger.info("🔄 重置OCR服务状态")
        recognizedText = ""
        extractedIndicators.removeAll()
        extractedDate = nil
        errorMessage = nil
        isProcessing = false
    }
}
