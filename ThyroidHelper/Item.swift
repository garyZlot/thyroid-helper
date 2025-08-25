//
//  Item.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
