//
//  ThyroidIndicator+Extensions.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import Foundation

extension Array where Element == ThyroidIndicator {
    /// 按照标准医学顺序排序指标
    func sortedByMedicalOrder() -> [ThyroidIndicator] {
        return self.sorted { first, second in
            let firstIndex = ThyroidConfig.standardOrder.firstIndex(of: first.name) ?? ThyroidConfig.standardOrder.count
            let secondIndex = ThyroidConfig.standardOrder.firstIndex(of: second.name) ?? ThyroidConfig.standardOrder.count
            return firstIndex < secondIndex
        }
    }
}

extension ThyroidIndicator {
    /// 获取指标的标准显示顺序索引
    var displayOrderIndex: Int {
        ThyroidConfig.standardOrder.firstIndex(of: self.name) ?? ThyroidConfig.standardOrder.count
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
        switch self.name {
        case "FT3":
            return (2.77, 6.31)
        case "FT4":
            return (10.44, 24.38)
        case "TSH":
            return (0.380, 4.340)
        case "A-TG":
            return (0, 4.5)
        case "A-TPO":
            return (0, 60)
        default:
            return nil
        }
    }
    
    /// 指标的标准单位
    var standardUnit: String {
        switch self.name {
        case "FT3", "FT4":
            return "pmol/L"
        case "TSH":
            return "μIU/mL"
        case "A-TG", "A-TPO":
            return "IU/mL"
        default:
            return self.unit
        }
    }
}
