//
//  ThyroidIndicator+Extensions.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import Foundation

extension Array where Element == THThyroidIndicator {
    /// 按照标准医学顺序排序指标
    func sortedByMedicalOrder() -> [THThyroidIndicator] {
        return self.sorted { first, second in
            let firstIndex = THConfig.standardOrder.firstIndex(of: first.name) ?? THConfig.standardOrder.count
            let secondIndex = THConfig.standardOrder.firstIndex(of: second.name) ?? THConfig.standardOrder.count
            return firstIndex < secondIndex
        }
    }
}

extension THThyroidIndicator {
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
