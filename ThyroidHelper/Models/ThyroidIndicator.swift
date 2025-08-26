//
//  ThyroidIndicator.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftData
import Foundation

@Model
class ThyroidIndicator {
    var name: String
    var value: Double
    var unit: String
    var normalRange: String
    var status: IndicatorStatus
    
    // 反向关系
    var record: CheckupRecord?
    
    init(name: String, value: Double, unit: String, normalRange: String, status: IndicatorStatus) {
        self.name = name
        self.value = value
        self.unit = unit
        self.normalRange = normalRange
        self.status = status
    }
    
    enum IndicatorStatus: String, CaseIterable, Codable {
        case normal = "正常"
        case high = "偏高"
        case low = "偏低"
        
        var color: String {
            switch self {
            case .normal: return "green"
            case .high: return "red"
            case .low: return "blue"
            }
        }
    }
    
    // 自动判断状态的便利方法
    static func determineStatus(value: Double, normalRange: String) -> IndicatorStatus {
        // 解析参考范围，如 "0.27-4.2" 或 "<34"
        if normalRange.contains("-") {
            let components = normalRange.components(separatedBy: "-")
            if components.count == 2,
               let lower = Double(components[0]),
               let upper = Double(components[1]) {
                if value < lower { return .low }
                if value > upper { return .high }
                return .normal
            }
        } else if normalRange.hasPrefix("<") {
            let upperString = String(normalRange.dropFirst())
            if let upper = Double(upperString) {
                return value > upper ? .high : .normal
            }
        }
        return .normal
    }
}
