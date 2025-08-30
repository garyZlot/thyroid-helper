//
//  IndicatorAdjustmentRow.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

import SwiftUI

struct IndicatorAdjustmentRow: View {
    let indicator: String
    let originalValue: Double
    @Binding var adjustment: String
    
    @State private var isEditing = false
    
    private var unit: String {
        ThyroidConfig.indicatorSettings[indicator]?.unit ?? ""
    }
    
    private var normalRange: String {
        ThyroidConfig.indicatorSettings[indicator]?.normalRangeString ?? ""
    }
    
    private var displayValue: Double {
        if !adjustment.isEmpty, let adjustedValue = Double(adjustment) {
            return adjustedValue
        }
        return originalValue
    }
    
    private var isAdjusted: Bool {
        !adjustment.isEmpty && adjustment != String(originalValue)
    }
    
    // 动态设置小数位数
    private var decimalPlaces: Int {
        ThyroidConfig.decimalPlaces(for: indicator)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // 指标名称
                VStack(alignment: .leading, spacing: 4) {
                    Text(indicator)
                        .font(.headline)
                    
                    Text("参考: \(normalRange)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80, alignment: .leading)
                
                Spacer()
                
                // 原始识别值
                if isEditing {
                    TextField("数值", text: $adjustment)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .onSubmit {
                            isEditing = false
                        }
                } else {
                    Button(action: {
                        if adjustment.isEmpty {
                            adjustment = String(originalValue)
                        }
                        isEditing = true
                    }) {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                if isAdjusted {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                                
                                // 动态设置精度
                                Text(displayValue, format: .number.precision(.fractionLength(decimalPlaces)))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isAdjusted ? .blue : .primary)
                            }
                            
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isAdjusted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 调整状态提示
            if isAdjusted {
                HStack {
                    Text("原识别值: \(originalValue, format: .number.precision(.fractionLength(decimalPlaces)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("恢复") {
                        adjustment = ""
                        isEditing = false
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
