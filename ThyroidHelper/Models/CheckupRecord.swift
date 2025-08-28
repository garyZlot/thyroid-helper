//
//  CheckupRecord.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftData
import Foundation

@Model
class CheckupRecord {
    // 移除@Attribute(.unique)，因为CloudKit不支持唯一约束
    var id: String = ""
    var date: Date = Date()
    var type: CheckupType = CheckupType.comprehensive
    var notes: String? = nil
    
    // 关系：一对多，设为可选
    @Relationship(deleteRule: .cascade) var indicators: [ThyroidIndicator]? = []
    
    init(date: Date, type: CheckupType, notes: String? = nil) {
        self.id = UUID().uuidString
        self.date = date
        self.type = type
        self.notes = notes
        self.indicators = []
    }
    
    enum CheckupType: String, CaseIterable, Codable {
        case comprehensive = "甲功五项"
        case thyroglobulin = "甲状腺球蛋白"
        case ultrasound = "甲状腺B超"
        
        var defaultIndicators: [String] {
            switch self {
            case .comprehensive:
                return ["TSH", "FT3", "FT4", "TG", "TPO"]
            case .thyroglobulin:
                return ["TG"]
            case .ultrasound:
                return []
            }
        }
    }
}
