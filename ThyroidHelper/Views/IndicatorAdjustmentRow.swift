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
        switch indicator {
        case "TSH": return "μIU/mL"
        case "FT3", "FT4": return "pmol/L"
        case "A-TG", "A-TPO": return "IU/mL"
        default: return ""
        }
    }
    
    private var normalRange: String {
        switch indicator {
        case "TSH": return "0.380-4.340"
        case "FT3": return "2.77-6.31"
        case "FT4": return "10.44-24.38"
        case "A-TG": return "0-4.5"
        case "A-TPO": return "0-60"
        default: return ""
        }
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
                                
                                Text(displayValue, format: .number.precision(.fractionLength(2)))
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
                    Text("原识别值: \(originalValue, format: .number.precision(.fractionLength(2)))")
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
