//
//  DoubleExtension.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/8/31.
//

import Foundation

extension Double {
    func formatted(decimalPlaces: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.\(decimalPlaces)f", self)
    }
}
