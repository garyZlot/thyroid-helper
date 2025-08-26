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
        "TG": [
            "TG[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "甲状腺球蛋白[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "Thyroglobulin[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "A-TG[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)"
        ],
        "TPO": [
            "TPO[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
            "甲状腺过氧化物酶抗体[\\s\\S]*?([<>]?[0-9]+\\.?[0-9]*)",
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
        
        // 提取所有识别到的文本
        let recognizedStrings = observations.compactMap { observation in
            return observation.topCandidates(1).first?.string
        }
        
        recognizedText = recognizedStrings.joined(separator: "\n")
        
        // 从识别的文本中提取指标数值
        extractIndicators(from: recognizedText)
    }
    
    private func extractIndicators(from text: String) {
        extractedIndicators.removeAll()
        
        print("🔍 开始从文本中提取指标:")
        print("原始文本: \(text)")
        
        // 按行分割文本
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        print("📝 分割后的行: \(lines)")
        
        // 使用位置匹配方法提取指标
        extractByPositionMatching(lines: lines)
        
        print("📊 最终提取到的指标: \(extractedIndicators)")
    }
    
    // 基于位置匹配的指标提取方法
    private func extractByPositionMatching(lines: [String]) {
        // 定义指标映射
        let indicatorMap: [String: String] = [
            "FT3": "FT3",
            "FT4": "FT4",
            "TSH": "TSH",
            "A-TPO": "TPO",
            "TPO": "TPO",
            "A-TG": "TG",
            "TG": "TG"
        ]
        
        // 查找指标名称的位置，然后在后续行中查找对应的数值
        for (index, line) in lines.enumerated() {
            print("🔍 检查行 \(index): '\(line)'")
            
            // 检查当前行是否包含指标名称
            for (key, indicator) in indicatorMap {
                if line.contains(key) {
                    print("📍 找到指标 \(key) 在行 \(index)")
                    
                    // 在当前行及后续几行中查找数值
                    for valueIndex in index..<min(index + 10, lines.count) {
                        let valueLine = lines[valueIndex]
                        if let value = extractFirstNumber(from: valueLine) {
                            // 验证这个数值是否合理（避免提取到无关的数字）
                            if isReasonableThyroidValue(value: value, indicator: indicator) {
                                extractedIndicators[indicator] = value
                                print("✅ 成功提取 \(indicator): \(value) (从行 \(valueIndex): '\(valueLine)')")
                                break
                            }
                        }
                    }
                }
            }
        }
        
        // 如果位置匹配失败，尝试基于已知结果值的顺序匹配
        if extractedIndicators.count < 3 {
            extractBySequentialMatching(lines: lines)
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
        
        // 根据OCR识别的结果，按顺序匹配常见的甲状腺指标
        // 从截图看，顺序应该是: FT3(5.27), FT4(21.10), TSH(0.565), TPO(81.20), TG(<1.3)
        let expectedOrder = ["FT3", "FT4", "TSH", "TPO", "TG"]
        
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
    
    // 从文本中提取第一个数值（处理<1.3这种情况）
    private func extractFirstNumber(from text: String) -> Double? {
        // 匹配数字，包括带<或>符号的
        let pattern = "([<>]?[0-9]+\\.?[0-9]*)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
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
    
    // 验证数值是否为合理的甲状腺指标值
    private func isReasonableThyroidValue(value: Double, indicator: String) -> Bool {
        switch indicator {
        case "TSH":
            return value >= 0.001 && value <= 100  // TSH通常在0.1-10之间
        case "FT3":
            return value >= 1.0 && value <= 20     // FT3通常在2-8之间
        case "FT4":
            return value >= 5.0 && value <= 50     // FT4通常在10-25之间
        case "TPO":
            return value >= 0 && value <= 1000     // TPO抗体可能很高
        case "TG":
            return value >= 0 && value <= 100      // TG抗体通常较低
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
