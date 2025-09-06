//
//  THTrendsView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import Charts
import _SwiftData_SwiftUI

struct THTrendsView: View {
    @Query(sort: \THThyroidPanelRecord.date, order: .forward) private var records: [THThyroidPanelRecord]
    
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
        let tempIndicator = THThyroidIndicator(name: indicatorName, value: 0, unit: "", normalRange: "", status: .normal)
        
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
    
    // 计算扩展后的日期范围（前后各扩展一个月）
    private var extendedDateRange: (start: Date, end: Date) {
        guard !data.isEmpty else {
            let now = Date()
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            let end = calendar.date(byAdding: .month, value: 1, to: now)!
            return (start, end)
        }
        
        let dates = data.map { $0.0 }
        let minDate = dates.min()!
        let maxDate = dates.max()!
        
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: minDate)!
        let end = calendar.date(byAdding: .month, value: 1, to: maxDate)!
        
        return (start, end)
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
                // 使用 GeometryReader 获取图表尺寸
                GeometryReader { geometry in
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
                    .chartXScale(domain: extendedDateRange.start...extendedDateRange.end)
                    .chartYAxisLabel(config.unit, position: .leading)
                    .chartXAxis {
                        // 隐藏X轴刻度标签
                        AxisMarks(values: .automatic(desiredCount: 0))
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
                            .padding(.bottom, 40) // 增加底部内边距以避免标签被截断
                    }
                    .overlay(
                        // 添加日期标签覆盖层
                        DateLabelsOverlay(
                            data: data,
                            extendedDateRange: extendedDateRange,
                            geometry: geometry
                        )
                    )
                }
                .frame(height: 240) // 增加高度以容纳日期标签
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

// 日期标签覆盖层
struct DateLabelsOverlay: View {
    let data: [(Date, Double)]
    let extendedDateRange: (start: Date, end: Date)
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                // 计算日期标签的位置
                let xPosition = positionForDate(point.0, in: geometry.size.width)
                Text(DateFormatter.shortDateWithYear.string(from: point.0))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(-45))
                    .position(x: xPosition, y: geometry.size.height - 15) // 放在图表底部
            }
        }
    }
    
    // 计算日期在图表中的X位置
    private func positionForDate(_ date: Date, in width: CGFloat) -> CGFloat {
        let totalDuration = extendedDateRange.end.timeIntervalSince(extendedDateRange.start)
        let timeFromStart = date.timeIntervalSince(extendedDateRange.start)
        let positionRatio = timeFromStart / totalDuration
        return positionRatio * width
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

// 扩展DateFormatter，添加日期格式
extension DateFormatter {
    static let shortDateWithYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"  // 格式：年/月/日
        return formatter
    }()
}
