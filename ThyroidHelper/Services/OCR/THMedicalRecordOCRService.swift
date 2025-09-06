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
class THMedicalRecordOCRService: ObservableObject {
    @Published var recognizedText = ""
    @Published var isProcessing = false
    @Published var extractedDate: Date?
    @Published var extractedTitle: String = ""
    @Published var extractedNotes: String = ""
    @Published var errorMessage: String?
    
    // 日期识别模式
    private let datePatterns: [String] = [
        // YYYY-MM-DD 格式
        "([0-9]{4})[年\\-/\\.\\s]+([0-9]{1,2})[月\\-/\\.\\s]+([0-9]{1,2})[日]?",
        // YYYY.MM.DD 格式
        "([0-9]{4})\\.([0-9]{1,2})\\.([0-9]{1,2})",
        // MM/DD/YYYY 格式
        "([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})",
        // DD.MM.YYYY 格式
        "([0-9]{1,2})\\.([0-9]{1,2})\\.([0-9]{4})"
    ]
    
    // 检查项目关键词
    private let checkupKeywords: [String: String] = [
        "B超": "甲状腺B超检查",
        "超声": "甲状腺超声检查",
        "彩超": "甲状腺彩超检查",
        "病理": "病理检查",
        "血液": "血液检查",
        "血常规": "血常规检查",
        "甲功": "甲状腺功能检查",
        "甲状腺": "甲状腺检查",
        "CT": "CT检查",
        "核磁": "核磁共振检查",
        "MRI": "核磁共振检查",
        "X光": "X光检查",
        "胸片": "胸部X光检查"
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
        extractedDate = extractDate(from: text)
        
        // 提取检查项目
        extractedTitle = extractCheckupType(from: text)
        
        // 将识别的文本作为备注（去掉已提取的信息）
        var notes = text
        if let title = extractedTitle.isEmpty ? nil : extractedTitle {
            notes = notes.replacingOccurrences(of: title, with: "")
        }
        extractedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📅 提取的日期: \(extractedDate?.formatted() ?? "无")")
        print("📝 提取的标题: \(extractedTitle)")
        print("📄 提取的备注: \(extractedNotes)")
    }
    
    private func extractDate(from text: String) -> Date? {
        for pattern in datePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let yearRange = Range(match.range(at: 1), in: text)!
                    let monthRange = Range(match.range(at: 2), in: text)!
                    let dayRange = Range(match.range(at: 3), in: text)!
                    
                    let yearStr = String(text[yearRange])
                    let monthStr = String(text[monthRange])
                    let dayStr = String(text[dayRange])
                    
                    if let year = Int(yearStr),
                       let month = Int(monthStr),
                       let day = Int(dayStr) {
                        
                        // 处理不同的日期格式
                        let calendar = Calendar.current
                        var dateComponents = DateComponents()
                        
                        if year > 31 { // 年份在前
                            dateComponents.year = year
                            dateComponents.month = month
                            dateComponents.day = day
                        } else { // 可能是 MM/DD/YYYY 格式
                            dateComponents.year = day
                            dateComponents.month = yearStr == "1" || yearStr == "2" ? Int(yearStr) : month
                            dateComponents.day = Int(dayStr) ?? day
                        }
                        
                        if let date = calendar.date(from: dateComponents) {
                            // 验证日期的合理性（不能是未来日期，不能太久以前）
                            let now = Date()
                            let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: now)!
                            
                            if date <= now && date >= tenYearsAgo {
                                return date
                            }
                        }
                    }
                }
            } catch {
                print("日期正则表达式错误: \(error)")
            }
        }
        
        return nil
    }
    
    private func extractCheckupType(from text: String) -> String {
        for (keyword, title) in checkupKeywords {
            if text.contains(keyword) {
                return title
            }
        }
        
        // 如果没有找到特定关键词，尝试提取可能的检查名称
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.count > 2 && trimmedLine.count < 20 {
                // 可能是检查项目名称的行
                if trimmedLine.contains("检查") || trimmedLine.contains("报告") {
                    return trimmedLine
                }
            }
        }
        
        return ""
    }
    
    private func resetExtractedData() {
        recognizedText = ""
        extractedDate = nil
        extractedTitle = ""
        extractedNotes = ""
    }
    
    func reset() {
        resetExtractedData()
        errorMessage = nil
        isProcessing = false
    }
}
