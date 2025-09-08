//
//  OCRServices.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

@preconcurrency import Vision
import UIKit
import Foundation
import os.log

/// OCR 识别服务
@MainActor
class THThyroidPanelOCRService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var extractedIndicators: [String: Double] = [:]
    @Published var extractedDate: Date?
    @Published var errorMessage: String?
    
    /// 当前识别指标，外部可以根据检查类型传入
    var indicatorKeys: [String]
    
    // 日期识别正则表达式模式
    private let datePatterns: [String] = [
        // YYYY-MM-DD 格式
        "([0-9]{4})[年\\-/\\.\\s]+([0-9]{1,2})[月\\-/\\.\\s]+([0-9]{1,2})[日]?",
        // YYYY.MM.DD 格式
        "([0-9]{4})\\.([0-9]{1,2})\\.([0-9]{1,2})",
        // MM/DD/YYYY 格式
        "([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})",
        // 中文完整日期格式：2024年8月26日
        "([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日",
        // 报告常见格式：检查日期：2024-08-26
        "检查日期[：:][\\s]*([0-9]{4})[\\-/]([0-9]{1,2})[\\-/]([0-9]{1,2})",
        // 日期标签格式
        "日期[：:][\\s]*([0-9]{4})[年\\-/\\.\\s]+([0-9]{1,2})[月\\-/\\.\\s]+([0-9]{1,2})[日]?"
    ]
    
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
        
        // 记录每个识别到的文本块的详细信息
        for (index, observation) in observations.enumerated() {
            if let text = observation.topCandidates(1).first?.string {
                let box = observation.boundingBox
                logger.debug("文本块[\(index)]: '\(text)' 位置:(x:\(String(format: "%.3f", box.minX))-\(String(format: "%.3f", box.maxX)), y:\(String(format: "%.3f", box.minY))-\(String(format: "%.3f", box.maxY))) 置信度:\(String(format: "%.3f", observation.confidence))")
            }
        }
        
        let sortedObservations = observations.sorted { a, b in
            if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.01 {
                return a.boundingBox.maxY > b.boundingBox.maxY
            } else {
                return a.boundingBox.minX < b.boundingBox.minX
            }
        }

        let recognizedStrings = sortedObservations.compactMap { $0.topCandidates(1).first?.string }
        recognizedText = recognizedStrings.joined(separator: "\n")
        
        logger.info("📄 排序后的识别文本:\n\(self.recognizedText)")
        logger.info("🔍 开始提取指标数值...")
        
        extractIndicators(from: recognizedText, observations: sortedObservations)
        extractedDate = extractDateFromText(recognizedText)
    }
    
    private func extractIndicators(from text: String, observations: [VNRecognizedTextObservation]) {
        extractedIndicators.removeAll()
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        logger.info("📋 文本行数: \(lines.count)")
        for (index, line) in lines.enumerated() {
            logger.debug("行[\(index)]: '\(line)'")
        }
        
        logger.info("🎯 方法1: 位置匹配提取...")
        extractByPositionMatching(lines: lines, observations: observations)
        
        let positionMatchCount = extractedIndicators.count
        logger.info("✅ 位置匹配完成，提取到 \(positionMatchCount) 个指标")
        
        if extractedIndicators.count < indicatorKeys.count {
            logger.info("🎯 方法2: 顺序匹配提取... (还需要 \(self.indicatorKeys.count - self.extractedIndicators.count) 个)")
            extractBySequentialMatching(lines: lines)
            
            let sequentialMatchCount = extractedIndicators.count - positionMatchCount
            logger.info("✅ 顺序匹配完成，额外提取到 \(sequentialMatchCount) 个指标")
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

    private func extractByPositionMatching(lines: [String], observations: [VNRecognizedTextObservation]) {
        logger.debug("🔍 开始位置匹配...")
        
        for (lineIndex, line) in lines.enumerated() {
            logger.debug("检查行[\(lineIndex)]: '\(line)'")
            
            for key in indicatorKeys {
                if line.contains(key) {
                    logger.info("🎯 在行[\(lineIndex)]中找到指标关键字 '\(key)': '\(line)'")
                    
                    if let observation = observations.first(where: { $0.topCandidates(1).first?.string == line }) {
                        let indicatorBox = observation.boundingBox
                        logger.debug("  指标位置: x:\(String(format: "%.3f", indicatorBox.minX))-\(String(format: "%.3f", indicatorBox.maxX)), y:\(String(format: "%.3f", indicatorBox.minY))-\(String(format: "%.3f", indicatorBox.maxY))")
                        
                        var cleanedLine = line.replacingOccurrences(of: key, with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        logger.debug("  清理后的文本: '\(cleanedLine)'")
                        
                        if let value = extractFirstNumber(from: cleanedLine) {
                            logger.debug("  从同行提取到数值: \(value)")
                            if isReasonableThyroidValue(value: value, indicator: key) {
                                extractedIndicators[key] = value
                                logger.info("  ✅ 同行匹配成功: \(key) = \(value)")
                                continue
                            } else {
                                logger.warning("  ❌ 数值不合理，被过滤: \(value)")
                            }
                        } else {
                            logger.debug("  同行未找到数值")
                        }
                        
                        // 尝试查找右侧的数值行
                        logger.debug("  🔍 搜索右侧数值行...")
                        var foundRightValue = false
                        for valueIndex in (lineIndex + 1)..<min(lineIndex + 3, lines.count) {
                            let valueLine = lines[valueIndex]
                            logger.debug("    检查候选行[\(valueIndex)]: '\(valueLine)'")
                            
                            if let valueObservation = observations.first(where: { $0.topCandidates(1).first?.string == valueLine }),
                               let value = extractFirstNumber(from: valueLine) {
                                let valueBox = valueObservation.boundingBox
                                let horizontalDistance = valueBox.minX - indicatorBox.maxX
                                let verticalDistance = abs(valueBox.midY - indicatorBox.midY)
                                
                                logger.debug("    候选数值: \(value)")
                                logger.debug("    位置: x:\(String(format: "%.3f", valueBox.minX))-\(String(format: "%.3f", valueBox.maxX)), y:\(String(format: "%.3f", valueBox.minY))-\(String(format: "%.3f", valueBox.maxY))")
                                logger.debug("    水平距离: \(String(format: "%.3f", horizontalDistance)), 垂直距离: \(String(format: "%.3f", verticalDistance))")
                                
                                if valueBox.minX > indicatorBox.maxX && abs(valueBox.midY - indicatorBox.midY) < 0.05 {
                                    if isReasonableThyroidValue(value: value, indicator: key) {
                                        extractedIndicators[key] = value
                                        logger.info("    ✅ 右侧匹配成功: \(key) = \(value)")
                                        foundRightValue = true
                                        break
                                    } else {
                                        logger.warning("    ❌ 右侧数值不合理，被过滤: \(value)")
                                    }
                                } else {
                                    logger.debug("    ❌ 位置不符合条件")
                                }
                            } else {
                                logger.debug("    未找到数值或observation")
                            }
                        }
                        
                        if !foundRightValue {
                            logger.warning("  ❌ 未找到合适的右侧数值")
                        }
                    } else {
                        logger.error("  ❌ 未找到对应的observation")
                    }
                }
            }
        }
    }

    private func extractBySequentialMatching(lines: [String]) {
        logger.debug("🔍 开始顺序匹配...")
        
        var numberLines: [(index: Int, value: Double)] = []
        for (index, line) in lines.enumerated() {
            if let value = extractFirstNumber(from: line) {
                numberLines.append((index, value))
                logger.debug("数值行[\(index)]: '\(line)' -> \(value)")
            }
        }
        
        logger.info("📊 找到 \(numberLines.count) 行包含数值")
        
        for (i, key) in indicatorKeys.enumerated() {
            if extractedIndicators[key] == nil {
                logger.debug("处理指标[\(i)]: \(key)")
                
                if i < numberLines.count {
                    let numberLine = numberLines[i]
                    let value = numberLine.value
                    
                    logger.debug("  尝试匹配数值行[\(numberLine.index)]: \(value)")
                    
                    if isReasonableThyroidValue(value: value, indicator: key) {
                        extractedIndicators[key] = value
                        logger.info("  ✅ 顺序匹配成功: \(key) = \(value) (来自行\(numberLine.index))")
                    } else {
                        logger.warning("  ❌ 顺序匹配数值不合理: \(key) = \(value)")
                    }
                } else {
                    logger.warning("  ❌ 没有足够的数值行匹配指标: \(key)")
                }
            } else {
                logger.debug("  ⏭️ 指标已匹配，跳过: \(key)")
            }
        }
    }

    private func extractFirstNumber(from text: String) -> Double? {
        let pattern = "[<>]?[0-9]+\\.?[0-9]*[+-]?"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: text.utf16.count)
            
            if let match = regex.firstMatch(in: text, range: range),
               let valueRange = Range(match.range, in: text) {
                var valueString = String(text[valueRange])
                let originalValue = valueString
                
                if valueString.hasSuffix("+") || valueString.hasSuffix("-") {
                    valueString.removeLast()
                }
                if valueString.hasPrefix("<") || valueString.hasPrefix(">") {
                    valueString.removeFirst()
                }
                
                if let result = Double(valueString) {
                    logger.debug("    🔢 从'\(text)'中提取数值: '\(originalValue)' -> \(result)")
                    return result
                } else {
                    logger.debug("    ❌ 无法转换为Double: '\(valueString)'")
                }
            } else {
                logger.debug("    ❌ 正则匹配失败: '\(text)'")
            }
        } catch {
            logger.error("❌ 正则表达式错误: \(error)")
        }
        return nil
    }
    
    /// 根据 THConfig.indicatorSettings 的范围判断是否合理
    private func isReasonableThyroidValue(value: Double, indicator: String) -> Bool {
        if let setting = THConfig.indicatorSettings[indicator] {
            let minValue = setting.normalRange.lower * 0.1
            let maxValue = setting.normalRange.upper * 10.0
            let isReasonable = value >= minValue && value <= maxValue
            
            if isReasonable {
                logger.debug("      ✅ 数值合理: \(value) 在范围 \(minValue) - \(maxValue)")
            } else {
                logger.debug("      ❌ 数值不合理: \(value) 不在范围 \(minValue) - \(maxValue)")
            }
            
            return isReasonable
        } else {
            let isReasonable = value >= 0 && value <= 1000
            logger.debug("      ⚠️ 未找到指标配置，使用默认范围: \(value) 在 0-1000? \(isReasonable)")
            return isReasonable
        }
    }
    
    /// 从OCR识别的文本中提取日期
    /// - Parameter text: OCR识别的原始文本
    /// - Returns: 提取到的日期，如果未找到返回nil
    private func extractDateFromText(_ text: String) -> Date? {
        print("🔍 [THThyroidPanelOCRService] 开始提取日期信息")
        print("📄 OCR识别文本: \(text)")
        
        // 遍历所有日期模式进行匹配
        for (index, pattern) in datePatterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    print("📍 匹配到模式 #\(index): \(pattern)")
                    
                    // 确保有足够的捕获组
                    guard match.numberOfRanges >= 4 else {
                        print("⚠️ 捕获组数量不足: \(match.numberOfRanges)")
                        continue
                    }
                    
                    // 提取年月日字符串
                    guard let yearRange = Range(match.range(at: 1), in: text),
                          let monthRange = Range(match.range(at: 2), in: text),
                          let dayRange = Range(match.range(at: 3), in: text) else {
                        print("⚠️ 无法创建字符串范围")
                        continue
                    }
                    
                    let yearStr = String(text[yearRange])
                    let monthStr = String(text[monthRange])
                    let dayStr = String(text[dayRange])
                    
                    print("📅 提取到日期字符串: 年=\(yearStr), 月=\(monthStr), 日=\(dayStr)")
                    
                    // 转换为整数
                    guard let year = Int(yearStr),
                          let month = Int(monthStr),
                          let day = Int(dayStr) else {
                        print("⚠️ 日期字符串转换失败")
                        continue
                    }
                    
                    // 构建日期
                    let calendar = Calendar.current
                    var dateComponents = DateComponents()
                    
                    // 根据年份大小判断日期格式
                    if year > 31 {
                        // 标准格式：YYYY-MM-DD
                        dateComponents.year = year
                        dateComponents.month = month
                        dateComponents.day = day
                    } else if Int(dayStr) ?? 0 > 31 {
                        // MM/DD/YYYY 格式
                        dateComponents.year = Int(dayStr)
                        dateComponents.month = year
                        dateComponents.day = month
                    } else {
                        print("⚠️ 无法确定日期格式")
                        continue
                    }
                    
                    // 验证并创建日期
                    if let date = calendar.date(from: dateComponents) {
                        // 日期合理性检查
                        if isDateReasonable(date) {
                            print("✅ 成功提取日期: \(date.formatted(date: .abbreviated, time: .omitted))")
                            return date
                        } else {
                            print("⚠️ 日期不在合理范围内: \(date.formatted())")
                        }
                    }
                }
            } catch {
                print("❌ 日期正则表达式错误 (模式#\(index)): \(error.localizedDescription)")
            }
        }
        
        print("❌ 未找到有效日期")
        return nil
    }
    
    /// 检查日期是否在合理范围内
    /// - Parameter date: 待检查的日期
    /// - Returns: 是否合理
    private func isDateReasonable(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // 不能是未来日期（允许今天）
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        if date >= tomorrow {
            return false
        }
        
        // 不能太久远（10年前）
        let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: now)!
        if date < tenYearsAgo {
            return false
        }
        
        return true
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
