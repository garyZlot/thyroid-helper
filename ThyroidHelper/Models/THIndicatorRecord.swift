//
//  THIndicatorRecord.swift
//  ThyroidHelper
//

import SwiftData
import Foundation

@Model
class THIndicatorRecord {
    // 所有属性都需要有默认值
    var name: String = ""
    var value: Double = 0.0
    var unit: String = ""
    var normalRange: String = ""
    var status: IndicatorStatus = IndicatorStatus.normal
    
    // 反向关系，设为可选
    var checkupRecord: THCheckupRecord? = nil
    
    init(name: String, value: Double, unit: String, normalRange: String, status: IndicatorStatus = .normal) {
        self.name = name
        self.value = value
        self.unit = unit
        self.normalRange = normalRange
        self.status = status
    }
    
    enum IndicatorStatus: String, CaseIterable, Codable {
        case low = "偏低"
        case normal = "正常"
        case high = "偏高"
        
        var color: String {
            switch self {
            case .low: return "blue"
            case .normal: return "green"
            case .high: return "red"
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


extension Array where Element == THIndicatorRecord {
    /// 按照标准医学顺序排序指标
    func sortedByMedicalOrder() -> [THIndicatorRecord] {
        return self.sorted { first, second in
            let firstIndex = THConfig.standardOrder.firstIndex(of: first.name) ?? THConfig.standardOrder.count
            let secondIndex = THConfig.standardOrder.firstIndex(of: second.name) ?? THConfig.standardOrder.count
            return firstIndex < secondIndex
        }
    }
}

extension THIndicatorRecord {
    /// 获取指标的标准显示顺序索引
    var displayOrderIndex: Int {
        THConfig.standardOrder.firstIndex(of: self.name) ?? THConfig.standardOrder.count
    }
    
    /// 指标的完整显示名称
    var fullDisplayName: String {
        switch self.name {
        case "FT3":
            return "indicator_ft3".localized
        case "FT4":
            return "indicator_ft4".localized
        case "TSH":
            return "indicator_tsh".localized
        case "A-TG":
            return "indicator_anti_tg".localized
        case "A-TPO":
            return "indicator_anti_tpo".localized
        case "TG 2":
            return "indicator_tg".localized
        default:
            return self.name
        }
    }
    
    /// 指标的标准参考范围
    var standardNormalRange: (Double, Double)? {
        THConfig.indicatorSettings[name]?.normalRange
    }
    
    /// 指标的标准单位
    var standardUnit: String {
        THConfig.indicatorSettings[name]?.unit ?? ""
    }
}
