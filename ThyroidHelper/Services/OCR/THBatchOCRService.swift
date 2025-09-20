//
//  THBatchOCRService.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/20.
//

import SwiftUI
import PhotosUI
import SwiftData
import UIKit

@MainActor
class THBatchOCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var currentProgress = 0.0
    @Published var currentImageIndex = 0
    @Published var totalImages = 0
    @Published var statusMessage = ""
    @Published var completedRecords: [THHistoryRecord] = []
    
    private let ocrService = THHistoryCheckupOCRService()
    
    /// 批量处理图片并创建历史记录
    func processImagesAndCreateRecords(
        from photoItems: [PhotosPickerItem],
        modelContext: ModelContext,
        completion: @escaping () -> Void
    ) {
        Task {
            await batchProcessImages(photoItems: photoItems, modelContext: modelContext)
            completion()
        }
    }
    
    private func batchProcessImages(
        photoItems: [PhotosPickerItem],
        modelContext: ModelContext
    ) async {
        isProcessing = true
        totalImages = photoItems.count
        currentImageIndex = 0
        currentProgress = 0.0
        completedRecords.removeAll()
        
        statusMessage = "processing_images".localized
        
        for (index, photoItem) in photoItems.enumerated() {
            currentImageIndex = index + 1
            statusMessage = String(format: "processing_image_format".localized, currentImageIndex, totalImages)
            
            // 加载图片数据
            guard let imageData = await loadImageData(from: photoItem),
                  let uiImage = UIImage(data: imageData) else {
                // 如果无法加载图片，创建一个失败的记录
                let record = createFallbackRecord(with: [])
                saveRecord(record, to: modelContext)
                updateProgress(for: index)
                continue
            }
            
            // 进行OCR识别
            statusMessage = String(format: "ocr_recognizing_format".localized, currentImageIndex, totalImages)
            let ocrResult = await performOCR(on: uiImage)
            
            // 创建历史记录
            let record = createHistoryRecord(
                from: ocrResult,
                imageData: imageData,
                fallbackDate: Date()
            )
            
            // 保存到数据库
            saveRecord(record, to: modelContext)
            completedRecords.append(record)
            
            // 更新进度
            updateProgress(for: index)
            
            // 短暂延迟，让用户能看到进度变化
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        }
        
        statusMessage = "processing_completed".localized
        
        // 2秒后自动完成
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        isProcessing = false
    }
    
    private func loadImageData(from photoItem: PhotosPickerItem) async -> Data? {
        do {
            return try await photoItem.loadTransferable(type: Data.self)
        } catch {
            print("❌ 加载图片失败: \(error)")
            return nil
        }
    }
    
    private func performOCR(on image: UIImage) async -> OCRResult {
        // 简化版OCR处理，直接使用基础信息
        return await withCheckedContinuation { continuation in
            // 方案A：尝试使用原有OCR服务
            Task {
                do {
                    // 重置OCR服务状态
                    await MainActor.run {
                        ocrService.reset()
                        ocrService.processImage(image)
                    }
                    
                    // 等待处理完成，最多等待3秒
                    var attempts = 0
                    let maxAttempts = 30 // 3秒，每次0.1秒
                    
                    while attempts < maxAttempts {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                        
                        let isProcessing = await MainActor.run { ocrService.isProcessing }
                        let recognizedText = await MainActor.run { ocrService.recognizedText }
                        let hasError = await MainActor.run { ocrService.errorMessage != nil }
                        
                        if !isProcessing && (!recognizedText.isEmpty || hasError) {
                            let extractedDate = await MainActor.run { ocrService.extractedDate }
                            let extractedTitle = await MainActor.run { ocrService.extractedCheckupName }
                            let extractedNotes = await MainActor.run { ocrService.recognizedText }
                            
                            let result = OCRResult(
                                extractedDate: extractedDate,
                                extractedTitle: extractedTitle,
                                extractedNotes: extractedNotes.isEmpty ? "OCR processing completed" : extractedNotes,
                                isSuccess: !extractedNotes.isEmpty
                            )
                            continuation.resume(returning: result)
                            return
                        }
                        
                        attempts += 1
                    }
                    
                    // 超时处理 - 创建默认记录
                    let result = OCRResult(
                        extractedDate: Date(),
                        extractedTitle: "Medical Report \(DateFormatter.shortDate.string(from: Date()))",
                        extractedNotes: "OCR processing timeout - please add details manually",
                        isSuccess: false
                    )
                    continuation.resume(returning: result)
                    
                } catch {
                    // 错误处理 - 创建默认记录
                    let result = OCRResult(
                        extractedDate: Date(),
                        extractedTitle: "Medical Report \(DateFormatter.shortDate.string(from: Date()))",
                        extractedNotes: "OCR processing error: \(error.localizedDescription)",
                        isSuccess: false
                    )
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    private func createHistoryRecord(
        from ocrResult: OCRResult,
        imageData: Data,
        fallbackDate: Date
    ) -> THHistoryRecord {
        let date = ocrResult.extractedDate ?? fallbackDate
        let title = ocrResult.extractedTitle.isEmpty ?
                   "medical_report".localized + " " + DateFormatter.shortDate.string(from: date) :
                   ocrResult.extractedTitle
        
        let notes = ocrResult.isSuccess ?
                   ocrResult.extractedNotes :
                   "ocr_failed_note".localized
        
        return THHistoryRecord(
            date: date,
            title: title,
            imageDatas: [imageData],
            notes: notes
        )
    }
    
    private func createFallbackRecord(with imageDatas: [Data]) -> THHistoryRecord {
        let date = Date()
        let title = "medical_report".localized + " " + DateFormatter.shortDate.string(from: date)
        
        return THHistoryRecord(
            date: date,
            title: title,
            imageDatas: imageDatas,
            notes: "image_load_failed_note".localized
        )
    }
    
    private func saveRecord(_ record: THHistoryRecord, to modelContext: ModelContext) {
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            print("✅ 历史记录保存成功: \(record.title)")
        } catch {
            print("❌ 保存历史记录失败: \(error)")
        }
    }
    
    private func updateProgress(for index: Int) {
        currentProgress = Double(index + 1) / Double(totalImages)
    }
    
    func reset() {
        isProcessing = false
        currentProgress = 0.0
        currentImageIndex = 0
        totalImages = 0
        statusMessage = ""
        completedRecords.removeAll()
        ocrService.reset()
    }
}

// MARK: - 辅助结构体
struct OCRResult {
    let extractedDate: Date?
    let extractedTitle: String
    let extractedNotes: String
    let isSuccess: Bool
}

// MARK: - 日期格式化扩展
private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
}
