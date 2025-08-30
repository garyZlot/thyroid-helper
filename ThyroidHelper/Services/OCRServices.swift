//
//  OCRServices.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

@preconcurrency import Vision
import UIKit
import Foundation

@MainActor
class OCRService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var extractedIndicators: [String: Double] = [:]
    @Published var errorMessage: String?
    
    // 甲状腺指标的正则表达式匹配模式 - 改进版
    private let indicatorPatterns: [String: [String]] = [
        "TSH": [
            "TSH[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "促甲状腺激素[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "甲状腺刺激素[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)"
        ],
        "FT3": [
            "FT3[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "游离三碘甲状腺原氨酸[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "游离T3[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)"
        ],
        "FT4": [
            "FT4[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "游离甲状腺素[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "游离T4[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)"
        ],
        "A-TG": [
            "TG[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "甲状腺球蛋白自身抗体[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "Thyroglobulin[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "A-TG[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)"
        ],
        "A-TPO": [
            "TPO[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "甲状腺过氧化物酶自身抗体[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "抗TPO[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "TPOAb[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "A-TPO[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)"
        ]
    ]
    
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "图片处理失败"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        recognizedText = ""
        extractedIndicators.removeAll()
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleOCRResult(request: request, error: error)
            }
        }
        
        // 配置识别精度和语言
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "OCR识别失败: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func handleOCRResult(request: VNRequest, error: Error?) {
        isProcessing = false
        
        if let error = error {
            errorMessage = "识别错误: \(error.localizedDescription)"
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            errorMessage = "无法获取识别结果"
            return
        }
        
        // 按观察值排序：从上到下（按递减maxY，因为y=1是顶部），然后从左到右（按递增minX）
        let sortedObservations = observations.sorted { a, b in
            let aBox = a.boundingBox
            let bBox = b.boundingBox
            
            // 如果在不同“行”（y差值>阈值，例如0.01用于归一化坐标）
            if abs(aBox.midY - bBox.midY) > 0.01 {
                return aBox.maxY > bBox.maxY  // 更高maxY优先（从上到下）
            } else {
                return aBox.minX < bBox.minX  // 同一行：从左到右
            }
        }

        // 现在使用sortedObservations代替observations
        let recognizedStrings = sortedObservations.compactMap { observation in
            return observation.topCandidates(1).first?.string
        }
        recognizedText = recognizedStrings.joined(separator: "\n")
        
        // 从识别的文本中提取指标数值
        extractIndicators(from: recognizedText, observations: sortedObservations)
    }
    

    private func extractIndicators(from text: String, observations: [VNRecognizedTextObservation]) {
        extractedIndicators.removeAll()
        
        print("🔍 开始从文本中提取指标:")
        print("原始文本: \(text)")
        
        // 按行分割文本
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        print("📝 分割后的行: \(lines)")
        
        // 使用位置匹配方法提取指标
        extractByPositionMatching(lines: lines, observations: observations)
        
        // 如果未提取到足够指标，尝试顺序匹配
        if extractedIndicators.count < 5 { // 假设有5个指标：FT3, FT4, TSH, A-TG, A-TPO
            extractBySequentialMatching(lines: lines)
        }
        
        print("📊 最终提取到的指标: \(extractedIndicators)")
    }

    // 基于位置匹配的指标提取方法
    private func extractByPositionMatching(lines: [String], observations: [VNRecognizedTextObservation]) {
        let indicatorMap: [String: String] = [
            "FT3": "FT3",
            "FT4": "FT4",
            "TSH": "TSH",
            "A-TG": "A-TG",
            "A-TPO": "A-TPO"
        ]

        // 按行号和边界框匹配
        for (index, line) in lines.enumerated() {
            print("🔍 检查行 \(index): '\(line)'")
            
            for (key, indicator) in indicatorMap {
                if line.contains(key) {
                    print("📍 找到指标 \(key) 在行 \(index)")
                    
                    // 查找对应观察值的边界框
                    if let observation = observations.first(where: { $0.topCandidates(1).first?.string == line }) {
                        let indicatorBox = observation.boundingBox
                        
                        // 移除指标名称，提取剩余文本中的数值
                        var cleanedLine = line
                        if let range = cleanedLine.range(of: key, options: .caseInsensitive) {
                            cleanedLine.removeSubrange(range)
                        }
                        cleanedLine = cleanedLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 从清理后的文本提取第一个数值
                        if let value = extractFirstNumber(from: cleanedLine) {
                            if isReasonableThyroidValue(value: value, indicator: indicator) {
                                extractedIndicators[indicator] = value
                                print("✅ 成功提取 \(indicator): \(value) (从当前行 \(index): '\(cleanedLine)')")
                                continue // 跳过后续行搜索
                            }
                        }
                        
                        // 如果当前行没有有效数值，查找后续行
                        for valueIndex in (index + 1)..<min(index + 3, lines.count) {
                            let valueLine = lines[valueIndex]
                            if let valueObservation = observations.first(where: { $0.topCandidates(1).first?.string == valueLine }),
                               let value = extractFirstNumber(from: valueLine) {
                                let valueBox = valueObservation.boundingBox
                                
                                // 检查值是否在指标右侧（x坐标增加）且y坐标接近
                                if valueBox.minX > indicatorBox.maxX && abs(valueBox.midY - indicatorBox.midY) < 0.05 {
                                    if isReasonableThyroidValue(value: value, indicator: indicator) {
                                        extractedIndicators[indicator] = value
                                        print("✅ 成功提取 \(indicator): \(value) (从行 \(valueIndex): '\(valueLine)')")
                                        break // 找到值后停止搜索
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 基于顺序的匹配（根据常见的检查报告顺序）
    private func extractBySequentialMatching(lines: [String]) {
        print("🔄 尝试顺序匹配方法")
        
        // 提取所有数值行
        var numberLines: [(index: Int, value: Double, line: String)] = []
        for (index, line) in lines.enumerated() {
            if let value = extractFirstNumber(from: line) {
                numberLines.append((index: index, value: value, line: line))
                print("📊 发现数值行 \(index): \(value) - '\(line)'")
            }
        }
        
        // 按常见顺序匹配甲状腺指标
        let expectedOrder = ThyroidConfig.standardOrder
        for (i, indicator) in expectedOrder.enumerated() {
            if i < numberLines.count && extractedIndicators[indicator] == nil {
                let numberInfo = numberLines[i]
                if isReasonableThyroidValue(value: numberInfo.value, indicator: indicator) {
                    extractedIndicators[indicator] = numberInfo.value
                    print("✅ 顺序匹配 \(indicator): \(numberInfo.value)")
                }
            }
        }
    }

    // 从文本中提取第一个数值（处理<、>、+等情况）
    private func extractFirstNumber(from text: String) -> Double? {
        // 简化后的正则表达式：匹配任何数值，不依赖空格
        let pattern = "[<>]?[0-9]+\\.?[0-9]*[+-]?"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range, in: text) {
                var valueString = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if valueString.hasSuffix("+") || valueString.hasSuffix("-") {
                    valueString = String(valueString.dropLast())
                }
                if valueString.hasPrefix("<") || valueString.hasPrefix(">") {
                    valueString = String(valueString.dropFirst())
                }
                return Double(valueString)
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        return nil
    }

    // 验证数值是否为合理的甲状腺指标值
    private func isReasonableThyroidValue(value: Double, indicator: String) -> Bool {
        switch indicator {
        case "TSH":
            return value >= 0.001 && value <= 100
        case "FT3":
            return value >= 1.0 && value <= 20
        case "FT4":
            return value >= 5.0 && value <= 50
        case "A-TPO":
            return value >= 0 && value <= 1000
        case "A-TG":
            return value >= 0 && value <= 100
        default:
            return value >= 0 && value <= 1000
        }
    }
    
    private func extractValue(from text: String, pattern: String) -> Double? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let valueRange = Range(match.range(at: 1), in: text) {
                var valueString = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 处理<符号（将<1.3当作1.3处理）
                if valueString.hasPrefix("<") {
                    valueString = String(valueString.dropFirst())
                } else if valueString.hasPrefix(">") {
                    valueString = String(valueString.dropFirst())
                }
                
                return Double(valueString)
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        
        return nil
    }
    
    // 重置状态
    func reset() {
        recognizedText = ""
        extractedIndicators.removeAll()
        errorMessage = nil
        isProcessing = false
    }
}
