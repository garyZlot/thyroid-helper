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
    
    // 使用标准指标顺序
    private let standardIndicators = ["FT3", "FT4", "TSH", "A-TG", "A-TPO"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(standardIndicators, id: \.self) { indicatorName in
                        TrendChartCard(
                            indicatorName: indicatorName,
                            data: getTrendData(for: indicatorName)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("指标趋势")
        }
    }
    
    private func getTrendData(for indicatorName: String) -> [(Date, Double)] {
        return records.compactMap { record in
            guard let indicator = (record.indicators ?? []).first(where: { $0.name == indicatorName }) else {
                return nil
            }
            return (record.date, indicator.value)
        }
    }
}

struct TrendChartCard: View {
    let indicatorName: String
    let data: [(Date, Double)]
    
    // 根据指标名称获取配置
    private var config: (title: String, unit: String, color: Color, normalRange: (Double, Double)?) {
        // 创建临时指标对象来获取配置信息
        let tempIndicator = ThyroidIndicator(name: indicatorName, value: 0, unit: "", normalRange: "", status: .normal)
        
        let colors: [String: Color] = [
            "FT3": .blue,
            "FT4": .purple,
            "TSH": .indigo,
            "A-TG": .green,
            "A-TPO": .orange
        ]
        
        return (
            title: tempIndicator.fullDisplayName,
            unit: tempIndicator.standardUnit,
            color: colors[indicatorName] ?? .gray,
            normalRange: tempIndicator.standardNormalRange
        )
    }
    
    // 计算合适的日期显示间隔
    private var dateAxisValues: [Date] {
        guard !data.isEmpty else { return [] }
        
        let sortedDates = data.map(\.0).sorted()
        let dateCount = sortedDates.count
        
        // 根据数据点数量决定显示间隔
        let interval: Int
        if dateCount <= 3 {
            interval = 1  // 显示所有
        } else if dateCount <= 6 {
            interval = 2  // 显示一半
        } else {
            interval = max(3, dateCount / 4)  // 最多显示4-5个标签
        }
        
        return stride(from: 0, to: dateCount, by: interval).compactMap { index in
            index < sortedDates.count ? sortedDates[index] : nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(config.title)
                    .font(.headline)
                    .foregroundColor(config.color)
                
                Spacer()
                
                // 显示正常范围
                if let range = config.normalRange {
                    Text("正常: \(range.0, specifier: "%.1f")-\(range.1, specifier: "%.1f") \(config.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            if data.isEmpty {
                Text("暂无\(config.title)数据")
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
                        .foregroundStyle(config.color)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(60)
                        
                        PointMark(
                            x: .value("日期", point.0),
                            y: .value("数值", point.1)
                        )
                        .foregroundStyle(config.color)
                        .symbolSize(30)
                    }
                    
                    // 正常范围背景区域
                    if let range = config.normalRange {
                        RectangleMark(
                            yStart: .value("下限", range.0),
                            yEnd: .value("上限", range.1)
                        )
                        .foregroundStyle(.green.opacity(0.1))
                        
                        // 参考线 - 简化标注
                        RuleMark(y: .value("下限", range.0))
                            .foregroundStyle(.red.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        
                        RuleMark(y: .value("上限", range.1))
                            .foregroundStyle(.red.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel(config.unit, position: .leading)
                .chartXAxis {
                    AxisMarks(values: dateAxisValues) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            // 自定义标签格式
                            if let date = value.as(Date.self) {
                                Text(DateFormatter.shortDate.string(from: date))
                                    .font(.caption2)
                                    .rotationEffect(.degrees(-45))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel() {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.1f", doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(.clear)
                }
            } else {
                // iOS 15 及以下的备选方案
                VStack {
                    Text("图表功能需要 iOS 16+")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 显示最新值
                    if let latestValue = data.last {
                        Text("最新值: \(latestValue.1, specifier: "%.2f") \(config.unit)")
                            .font(.headline)
                            .foregroundColor(config.color)
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 趋势分析
            if !data.isEmpty {
                TrendAnalysis(data: data, normalRange: config.normalRange)
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

// 扩展DateFormatter，添加简短日期格式
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"  // 简短格式：月/日
        return formatter
    }()
}
