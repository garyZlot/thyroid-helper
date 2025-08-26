//
//  TrendsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import Charts
import _SwiftData_SwiftUI

struct TrendsView: View {
    @Query(sort: \CheckupRecord.date, order: .forward) private var records: [CheckupRecord]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // TSH 趋势
                    TrendChartCard(
                        title: "TSH 趋势",
                        unit: "mIU/L",
                        data: getTrendData(for: "TSH"),
                        color: .blue,
                        normalRange: (0.27, 4.2)
                    )
                    
                    // TG 趋势
                    TrendChartCard(
                        title: "甲状腺球蛋白 (TG)",
                        unit: "ng/mL",
                        data: getTrendData(for: "TG"),
                        color: .green,
                        normalRange: (3.5, 77)
                    )
                    
                    // TPO 趋势
                    TrendChartCard(
                        title: "甲状腺过氧化物酶抗体 (TPO)",
                        unit: "IU/mL",
                        data: getTrendData(for: "TPO"),
                        color: .orange,
                        normalRange: (0, 34)
                    )
                }
                .padding()
            }
            .navigationTitle("指标趋势")
        }
    }
    
    private func getTrendData(for indicatorName: String) -> [(Date, Double)] {
        return records.compactMap { record in
            guard let indicator = record.indicators.first(where: { $0.name == indicatorName }) else {
                return nil
            }
            return (record.date, indicator.value)
        }
    }
}

struct TrendChartCard: View {
    let title: String
    let unit: String
    let data: [(Date, Double)]
    let color: Color
    let normalRange: (Double, Double)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            if data.isEmpty {
                Text("暂无\(title)数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        LineMark(
                            x: .value("日期", point.0),
                            y: .value("数值", point.1)
                        )
                        .foregroundStyle(color)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(80)
                        
                        PointMark(
                            x: .value("日期", point.0),
                            y: .value("数值", point.1)
                        )
                        .foregroundStyle(color)
                        .symbolSize(50)
                    }
                    
                    // 参考线
                    if let range = normalRange {
                        RuleMark(y: .value("下限", range.0))
                            .foregroundStyle(.red.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .topLeading) {
                                Text("下限: \(range.0, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        
                        RuleMark(y: .value("上限", range.1))
                            .foregroundStyle(.red.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .topTrailing) {
                                Text("上限: \(range.1, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel(unit, position: .leading)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
            } else {
                // iOS 15 及以下的备选方案
                VStack {
                    Text("图表功能需要 iOS 16+")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 显示最新值
                    if let latestValue = data.last {
                        Text("最新值: \(latestValue.1, specifier: "%.2f") \(unit)")
                            .font(.headline)
                            .foregroundColor(color)
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 趋势分析
            if !data.isEmpty {
                TrendAnalysis(data: data, normalRange: normalRange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct TrendAnalysis: View {
    let data: [(Date, Double)]
    let normalRange: (Double, Double)?
    
    private var trendDescription: String {
        guard data.count >= 2 else { return "数据不足以分析趋势" }
        
        let latest = data.last!.1
        let previous = data[data.count - 2].1
        let change = latest - previous
        
        if abs(change) < 0.1 {
            return "📊 指标稳定，变化较小"
        } else if change > 0 {
            return "📈 指标呈上升趋势 (+\(String(format: "%.2f", change)))"
        } else {
            return "📉 指标呈下降趋势 (\(String(format: "%.2f", change)))"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text(trendDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
