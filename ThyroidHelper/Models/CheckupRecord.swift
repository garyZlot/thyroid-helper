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
    @Attribute(.unique) var id: String
    var date: Date
    var type: CheckupType
    var notes: String?
    
    // 关系：一对多
    @Relationship(deleteRule: .cascade) var indicators: [ThyroidIndicator] = []
    
    init(date: Date, type: CheckupType, notes: String? = nil) {
        self.id = UUID().uuidString
        self.date = date
        self.type = type
        self.notes = notes
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

