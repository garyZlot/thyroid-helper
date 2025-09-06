//
//  OCRServices.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

@preconcurrency import Vision
import UIKit
import Foundation

/// OCR 识别服务
@MainActor
class THThyroidPanelOCRService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var extractedIndicators: [String: Double] = [:]
    @Published var errorMessage: String?
    
    /// 当前识别指标，外部可以根据检查类型传入
    var indicatorKeys: [String]
    
    init(indicatorKeys: [String]? = nil) {
        // 如果没传就用标准顺序
        self.indicatorKeys = indicatorKeys ?? THConfig.standardOrder
    }
    
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
        
        let sortedObservations = observations.sorted { a, b in
            if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.01 {
                return a.boundingBox.maxY > b.boundingBox.maxY
            } else {
                return a.boundingBox.minX < b.boundingBox.minX
            }
        }

        let recognizedStrings = sortedObservations.compactMap { $0.topCandidates(1).first?.string }
        recognizedText = recognizedStrings.joined(separator: "\n")
        
        extractIndicators(from: recognizedText, observations: sortedObservations)
    }
    
    private func extractIndicators(from text: String, observations: [VNRecognizedTextObservation]) {
        extractedIndicators.removeAll()
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        extractByPositionMatching(lines: lines, observations: observations)
        
        if extractedIndicators.count < indicatorKeys.count {
            extractBySequentialMatching(lines: lines)
        }
    }

    private func extractByPositionMatching(lines: [String], observations: [VNRecognizedTextObservation]) {
        for (index, line) in lines.enumerated() {
            for key in indicatorKeys {
                if line.contains(key) {
                    if let observation = observations.first(where: { $0.topCandidates(1).first?.string == line }) {
                        let indicatorBox = observation.boundingBox
                        
                        var cleanedLine = line.replacingOccurrences(of: key, with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if let value = extractFirstNumber(from: cleanedLine),
                           isReasonableThyroidValue(value: value, indicator: key) {
                            extractedIndicators[key] = value
                            continue
                        }
                        
                        // 尝试查找右侧的数值行
                        for valueIndex in (index + 1)..<min(index + 3, lines.count) {
                            let valueLine = lines[valueIndex]
                            if let valueObservation = observations.first(where: { $0.topCandidates(1).first?.string == valueLine }),
                               let value = extractFirstNumber(from: valueLine) {
                                let valueBox = valueObservation.boundingBox
                                if valueBox.minX > indicatorBox.maxX && abs(valueBox.midY - indicatorBox.midY) < 0.05,
                                   isReasonableThyroidValue(value: value, indicator: key) {
                                    extractedIndicators[key] = value
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func extractBySequentialMatching(lines: [String]) {
        var numberLines: [(index: Int, value: Double)] = []
        for (index, line) in lines.enumerated() {
            if let value = extractFirstNumber(from: line) {
                numberLines.append((index, value))
            }
        }
        
        for (i, key) in indicatorKeys.enumerated() {
            if i < numberLines.count, extractedIndicators[key] == nil {
                let value = numberLines[i].value
                if isReasonableThyroidValue(value: value, indicator: key) {
                    extractedIndicators[key] = value
                }
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
                if valueString.hasSuffix("+") || valueString.hasSuffix("-") {
                    valueString.removeLast()
                }
                if valueString.hasPrefix("<") || valueString.hasPrefix(">") {
                    valueString.removeFirst()
                }
                return Double(valueString)
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        return nil
    }
    
    /// 根据 THConfig.indicatorSettings 的范围判断是否合理
    private func isReasonableThyroidValue(value: Double, indicator: String) -> Bool {
        if let setting = THConfig.indicatorSettings[indicator] {
            return value >= setting.normalRange.lower * 0.1 &&
                   value <= setting.normalRange.upper * 10.0
            // 宽松一些，避免OCR识别的边缘值被过滤掉
        }
        return value >= 0 && value <= 1000
    }
    
    func reset() {
        recognizedText = ""
        extractedIndicators.removeAll()
        errorMessage = nil
        isProcessing = false
    }
}
