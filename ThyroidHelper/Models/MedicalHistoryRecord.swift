//
//  MedicalHistoryRecord.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/4.
//

import Foundation
import SwiftData

@Model
class MedicalHistoryRecord {
    // 遵循现有模式，使用String类型的ID和默认值，确保CloudKit兼容性
    var id: String = ""
    var date: Date = Date()
    var title: String = ""
    var imageData: Data? = nil
    var notes: String = ""
    var createdAt: Date = Date()
    
    init(date: Date, title: String, imageData: Data? = nil, notes: String = "") {
        self.id = UUID().uuidString  // 遵循CheckupRecord的ID模式
        self.date = date
        self.title = title
        self.imageData = imageData
        self.notes = notes
        self.createdAt = Date()
    }
    
    /// 检查记录类型枚举，扩展现有类型概念
    enum RecordType: String, CaseIterable, Codable {
        case ultrasound = "B超检查"
        case pathology = "病理检查"
        case bloodTest = "血液检查"
        case imaging = "影像检查"
        case consultation = "问诊记录"
        case other = "其他检查"
        
        var icon: String {
            switch self {
            case .ultrasound: return "waveform.path.ecg"
            case .pathology: return "eye.trianglebadge.exclamationmark"
            case .bloodTest: return "drop.fill"
            case .imaging: return "xmark.bin.fill"
            case .consultation: return "stethoscope"
            case .other: return "doc.text.fill"
            }
        }
    }
}
