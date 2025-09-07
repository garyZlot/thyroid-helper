//
//  THCheckupRecord.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftData
import Foundation

@Model
class THThyroidPanelRecord {
    // 移除@Attribute(.unique)，因为CloudKit不支持唯一约束
    var id: String = ""
    var date: Date = Date()
    var type: CheckupType = CheckupType.thyroidFunction5
    var notes: String? = nil
    
    // 关系：一对多，设为可选
    @Relationship(deleteRule: .cascade) var indicators: [THThyroidIndicator]? = []
    
    init(date: Date, type: CheckupType, notes: String? = nil) {
        self.id = UUID().uuidString
        self.date = date
        self.type = type
        self.notes = notes
        self.indicators = []
    }
    
    enum CheckupType: String, CaseIterable, Codable {
        case thyroidFunction5 = "甲功五项"
        case thyroglobulin = "甲状腺球蛋白"
        
        var indicators: [String] {
            switch self {
            case .thyroidFunction5:
                return ["FT3", "FT4", "TSH", "A-TG", "A-TPO"]
            case .thyroglobulin:
                return ["TG 2"]
            }
        }
    }
}
