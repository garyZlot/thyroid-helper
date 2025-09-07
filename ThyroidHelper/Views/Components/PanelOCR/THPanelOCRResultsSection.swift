//
//  THOCRResultsSection.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

import SwiftUI

struct THPanelOCRResultsSection: View {
    let extractedIndicators: [String: Double]
    @Binding var manualAdjustments: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Text("识别到的指标")
                    .font(.headline)
                
                Spacer()
                
                Text("\(extractedIndicators.count) 项")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if extractedIndicators.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("未识别到甲状腺指标")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("请确保图片清晰，包含FT3、FT4、TSH、A-TG、A-TPO等指标数值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                // 指标列表，按standardOrder排序
                LazyVStack(spacing: 12) {
                    ForEach(Array(extractedIndicators.keys).sorted { first, second in
                        let firstIndex = THConfig.standardOrder.firstIndex(of: first) ?? THConfig.standardOrder.count
                        let secondIndex = THConfig.standardOrder.firstIndex(of: second) ?? THConfig.standardOrder.count
                        return firstIndex < secondIndex
                    }, id: \.self) { indicator in
                        THIndicatorAdjustmentRow(
                            indicator: indicator,
                            originalValue: extractedIndicators[indicator] ?? 0,
                            adjustment: Binding(
                                get: { manualAdjustments[indicator] ?? "" },
                                set: { manualAdjustments[indicator] = $0 }
                            )
                        )
                    }
                }
            }
            
            // 提示信息
            if !extractedIndicators.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                    
                    Text("可以手动调整识别不准确的数值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
