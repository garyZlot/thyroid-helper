//
//  THHistoryRecord.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/4.
//

import Foundation
import SwiftData

@Model
class THHistoryRecord {
    // 遵循现有模式，使用String类型的ID和默认值，确保CloudKit兼容性
    var id: String = ""
    var date: Date = Date()
    var title: String = ""
    var imageDatas: [Data] = [] // 新增：支持多张图片
    var notes: String = ""
    var createdAt: Date = Date()
    
    init(date: Date, title: String, imageDatas: [Data] = [], notes: String = "") {
        self.id = UUID().uuidString  // 遵循CheckupRecord的ID模式
        self.date = date
        self.title = title
        self.imageDatas = imageDatas
        self.notes = notes
        self.createdAt = Date()
    }
}
