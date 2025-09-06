//
//  THConfig.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/30.
//

import Foundation

/// 甲状腺相关配置
struct THConfig {
    /// 标准甲状腺指标显示顺序
    public static let standardOrder: [String] = ["FT3", "FT4", "TSH", "A-TG", "A-TPO"]
    
    /// 指标的配置信息
    public static let indicatorSettings: [String: IndicatorSetting] = [
        "FT3": IndicatorSetting(unit: "pmol/L", normalRange: (2.77, 6.31)),
        "FT4": IndicatorSetting(unit: "pmol/L", normalRange: (10.44, 24.38)),
        "TSH": IndicatorSetting(unit: "μIU/mL", normalRange: (0.380, 4.340)),
        "A-TG": IndicatorSetting(unit: "IU/mL", normalRange: (0, 4.5)),
        "A-TPO": IndicatorSetting(unit: "IU/mL", normalRange: (0, 60))
    ]
    
    /// 动态设置指标的小数位数
    public static func decimalPlaces(for indicator: String) -> Int {
        switch indicator {
        case "TSH": return 3
        case "FT3", "FT4", "A-TG", "A-TPO": return 2
        default: return 2
        }
    }
    
    public static func indicatorsForType(_ type: THThyroidPanelRecord.CheckupType) -> [String] {
        switch type {
        case .thyroidFunction5:
            return standardOrder
        default:
            return []
        }
    }
}

/// 指标配置结构体
struct IndicatorSetting {
    let unit: String
    let normalRange: (lower: Double, upper: Double)
    
    /// 格式化为字符串表示
    var normalRangeString: String {
        "\(normalRange.lower)-\(normalRange.upper)"
    }
}
