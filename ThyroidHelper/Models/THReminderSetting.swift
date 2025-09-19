//
//  THReminderSetting.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/3.
//

import SwiftData
import Foundation

extension THThyroidPanelRecord.CheckupType {
    var defaultInterval: DateComponents {
        switch self {
        case .thyroidFunction5:
            return DateComponents(month: 6)
        case .thyroglobulin:
            return DateComponents(month: 6)
        }
    }
    
    var displayName: String {
        return self.localizedName
    }
}

// 提醒设置模型
@Model
class THReminderSetting {
    // Add default values for CloudKit compatibility
    var id: UUID = UUID()
    var checkupType: THThyroidPanelRecord.CheckupType = THThyroidPanelRecord.CheckupType.thyroidFunction5
    var customReminderDate: Date?
    var isCustomReminderEnabled: Bool = false
    var isActive: Bool = true
    var lastUpdated: Date = Date()
    
    init(
        id: UUID = UUID(),
        checkupType: THThyroidPanelRecord.CheckupType,
        customReminderDate: Date? = nil,
        isCustomReminderEnabled: Bool = false,
        isActive: Bool = true,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.checkupType = checkupType
        self.customReminderDate = customReminderDate
        self.isCustomReminderEnabled = isCustomReminderEnabled
        self.isActive = isActive
        self.lastUpdated = lastUpdated
    }
    
    // 计算下次提醒日期
    func nextReminderDate(basedOn lastRecordDate: Date?) -> Date? {
        if isCustomReminderEnabled, let customDate = customReminderDate {
            return customDate
        }
        
        guard let lastDate = lastRecordDate else { return nil }
        return Calendar.current.date(byAdding: checkupType.defaultInterval, to: lastDate)
    }
}

// 辅助扩展
extension Array where Element == THReminderSetting {
    func setting(for type: THThyroidPanelRecord.CheckupType) -> THReminderSetting? {
        first(where: { $0.checkupType == type })
    }
}
