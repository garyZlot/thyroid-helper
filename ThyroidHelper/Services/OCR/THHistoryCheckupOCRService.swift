//
//  MedicalRecordOCRService.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/9/4.
//

@preconcurrency import Vision
import UIKit
import Foundation

@MainActor
class THHistoryCheckupOCRService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var extractedDate: Date?
    @Published var extractedCheckupName: String = ""
    @Published var extractedNotes: String = ""
    @Published var errorMessage: String?
    
    // 检查项目关键词
    private let checkupKeywords: [String] = [
        "B超",
        "超声",
        "彩超",
        "病理",
        "血液",
        "血常规",
        "甲功",
        "甲状腺",
        "CT",
        "核磁",
        "MRI",
        "X光",
        "胸片",
        "心电图",
        "脑电图",
        "内镜",
        "胃镜",
        "肠镜",
        "活检",
        "生化",
        "免疫",
        "尿液",
        "尿常规",
        "肝功",
        "肾功",
        "血糖"
    ]
    
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "图片处理失败"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        resetExtractedData()
        
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
        
        // 按位置排序文本
        let sortedObservations = observations.sorted { a, b in
            let aBox = a.boundingBox
            let bBox = b.boundingBox
            
            if abs(aBox.midY - bBox.midY) > 0.01 {
                return aBox.maxY > bBox.maxY
            } else {
                return aBox.minX < bBox.minX
            }
        }
        
        let recognizedStrings = sortedObservations.compactMap { observation in
            return observation.topCandidates(1).first?.string
        }
        recognizedText = recognizedStrings.joined(separator: "\n")
        
        // 提取信息
        extractMedicalInfo(from: recognizedText)
    }
    
    private func extractMedicalInfo(from text: String) {
        print("🔍 开始提取医疗记录信息:")
        print("原始文本: \(text)")
        
        // 提取日期
        extractedDate = THDateExtractionService.extractDate(from: text)
        
        // 提取检查项目
        extractedCheckupName = extractCheckupName(from: text)
        
        var notes = text
        extractedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📅 提取的日期: \(extractedDate?.formatted() ?? "无")")
        print("📝 提取的标题: \(extractedCheckupName)")
        print("📄 提取的备注: \(extractedNotes)")
    }
    
    // 优化的检查项目提取方法 - 按优先级识别
    private func extractCheckupName(from text: String) -> String {
        print("🎯 开始按优先级提取检查项目...")
        
        // 第一优先级：查找 "检查项目" 标签
        if let checkupName = extractFromCheckupLabel(text) {
            print("✅ [优先级1] 从检查项目标签提取: \(checkupName)")
            return checkupName
        }
        
        // 第二优先级：从标题行识别检查项目
        if let checkupName = extractFromTitleLine(text) {
            print("✅ [优先级2] 从标题行提取: \(checkupName)")
            return checkupName
        }
        
        // 第三优先级：使用关键词匹配
        if let checkupName = extractFromKeywordLines(text) {
            print("✅ [优先级3] 从关键词匹配提取: \(checkupName)")
            return checkupName
        }
        
        print("❌ 未找到具体检查项目")
        return ""
    }

    // 第一优先级：从 "检查项目" 标签提取
    private func extractFromCheckupLabel(_ text: String) -> String? {
        // 匹配 "检查项目：XXX" 或 "检查项目: XXX" 格式
        let patterns = [
            "检查项目[：:][\\s]*([^\\n\\r]{1,30})",
            "医嘱名称[：:][\\s]*([^\\n\\r]{1,30})",
            "项目名称[：:][\\s]*([^\\n\\r]{1,30})",
            "检查名称[：:][\\s]*([^\\n\\r]{1,30})"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    guard let itemRange = Range(match.range(at: 1), in: text) else { continue }
                    
                    let itemName = String(text[itemRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    print("🔍 [标签匹配] 找到检查项目: '\(itemName)'")
                    
                    return itemName
                }
            } catch {
                print("❌ 检查项目标签正则表达式错误: \(error)")
            }
        }
        
        return nil
    }

    // 第二优先级：从标题行识别检查项目
    private func extractFromTitleLine(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 通常标题在前几行，检查前5行
        for (index, line) in lines.prefix(5).enumerated() {
            print("🔍 [标题行\(index)] 检查: '\(line)'")
            
            // 跳过明显不是标题的行
            if line.count < 3 || line.count > 50 {
                continue
            }
            
            // 跳过日期行
            if line.contains("年") && line.contains("月") && line.contains("日") {
                continue
            }
            
            // 检查是否包含检查相关关键词
            let titleKeywords = ["检查", "报告", "结果", "超声", "B超", "CT", "核磁", "X光", "血液", "病理"]
            let containsCheckupKeyword = titleKeywords.contains { line.contains($0) }
            
            if containsCheckupKeyword {
                print("🎯 [标题行] 找到可能的检查项目标题: '\(line)'")
                
                return line
            }
        }
        
        return nil
    }

    // 第三优先级：使用关键词匹配
    private func extractFromKeywordLines(_ text: String) -> String? {
        print("🔍 [关键词行匹配] 开始匹配...")
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 20 }  // 只考虑20字符以内的行
        
        var matchedLines: [(line: String, keyword: String)] = []
        
        // 查找包含关键词的行
        for line in lines {
            for keyword in checkupKeywords {
                if line.contains(keyword) {
                    print("🔍 [关键词匹配] 行 '\(line)' 包含关键词 '\(keyword)'")
                    matchedLines.append((line: line, keyword: keyword))
                    break  // 找到一个关键词就跳出，避免重复
                }
            }
        }
        
        if matchedLines.isEmpty {
            print("❌ [关键词匹配] 未找到包含关键词的行")
            return nil
        }
        
        // 如果有多个匹配行，选择最短的
        let shortestMatch = matchedLines.min { first, second in
            return first.line.count < second.line.count
        }
        
        if let result = shortestMatch {
            print("✅ [关键词匹配] 选择最短匹配行: '\(result.line)' (关键词: \(result.keyword))")
            return result.line
        }
        
        return nil
    }
    
    private func resetExtractedData() {
        recognizedText = ""
        extractedDate = nil
        extractedCheckupName = ""
        extractedNotes = ""
    }
    
    func reset() {
        resetExtractedData()
        errorMessage = nil
        isProcessing = false
    }
}
