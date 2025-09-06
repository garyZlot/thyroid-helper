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
            return "游离三碘甲状腺原氨酸 (FT3)"
        case "FT4":
            return "游离甲状腺素 (FT4)"
        case "TSH":
            return "促甲状腺激素 (TSH)"
        case "A-TG":
            return "甲状腺球蛋白自身抗体 (A-TG)"
        case "A-TPO":
            return "甲状腺过氧化物酶自身抗体 (A-TPO)"
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
