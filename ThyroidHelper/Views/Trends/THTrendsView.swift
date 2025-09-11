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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(THConfig.standardOrder, id: \.self) { indicatorName in
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
            "A-TPO": .orange,
            "TG 2": .brown
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
    
    // 计算Y轴的显示范围
    private var yAxisRange: (min: Double, max: Double) {
        guard !data.isEmpty else { return (0, 10) }
        
        let values = data.map { $0.1 }
        let dataMin = values.min()!
        let dataMax = values.max()!
        
        // 考虑正常范围
        var min = dataMin
        var max = dataMax
        
        if let normalRange = config.normalRange {
            min = Swift.min(min, normalRange.0)
            max = Swift.max(max, normalRange.1)
        }
        
        // 增加一些边距
        let margin = (max - min) * 0.2
        return (min - margin, max + margin)
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
                    .chartYScale(domain: yAxisRange.min...yAxisRange.max)
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
                        // 添加日期标签和数值标签覆盖层
                        ChartLabelsOverlay(
                            data: data,
                            extendedDateRange: extendedDateRange,
                            yAxisRange: yAxisRange,
                            geometry: geometry,
                            color: config.color
                        )
                    )
                }
                .frame(height: 280) // 增加高度以容纳标签
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

// 图表标签覆盖层（包含日期和数值标签）
struct ChartLabelsOverlay: View {
    let data: [(Date, Double)]
    let extendedDateRange: (start: Date, end: Date)
    let yAxisRange: (min: Double, max: Double)
    let geometry: GeometryProxy
    let color: Color
    let leftSpace: CGFloat = 60.0
    
    // 计算数值标签的位置策略
    private func calculateValueLabelPositions() -> [(position: CGPoint, value: Double, isAbove: Bool)] {
        var positions: [(position: CGPoint, value: Double, isAbove: Bool)] = []
        
        for (index, point) in data.enumerated() {
            let xPosition = leftSpace + positionForDate(point.0, in: geometry.size.width - leftSpace)
            let yPosition = positionForValue(point.1, in: geometry.size.height - 40) // 减去底部padding
            
            // 决定标签显示在线上方还是下方
            let isAbove = shouldShowAbove(for: index, value: point.1, in: data)
            let labelY = isAbove ? yPosition - 25 : yPosition + 20
            
            positions.append((
                position: CGPoint(x: xPosition, y: labelY),
                value: point.1,
                isAbove: isAbove
            ))
        }
        
        return positions
    }
    
    // 决定标签应该显示在点的上方还是下方
    private func shouldShowAbove(for index: Int, value: Double, in data: [(Date, Double)]) -> Bool {
        // 如果是第一个或最后一个点，根据相邻点决定
        if index == 0 && data.count > 1 {
            return value > data[1].1
        } else if index == data.count - 1 && data.count > 1 {
            return value > data[index - 1].1
        } else if data.count > 1 {
            // 中间的点，比较与前后点的关系
            let prevValue = index > 0 ? data[index - 1].1 : value
            let nextValue = index < data.count - 1 ? data[index + 1].1 : value
            let avgNeighbor = (prevValue + nextValue) / 2
            return value > avgNeighbor
        }
        
        // 默认显示在上方
        return true
    }
    
    var body: some View {
        ZStack {
            // 日期标签
            ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                let xPosition = leftSpace + positionForDate(point.0, in: geometry.size.width - leftSpace)
                Text(DateFormatter.shortDateWithYear.string(from: point.0))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(-45))
                    .position(x: xPosition, y: geometry.size.height - 15)
            }
            
            // 数值标签
            ForEach(Array(calculateValueLabelPositions().enumerated()), id: \.offset) { index, labelInfo in
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", labelInfo.value))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                }
                .position(labelInfo.position)
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
    
    // 计算数值在图表中的Y位置
    private func positionForValue(_ value: Double, in height: CGFloat) -> CGFloat {
        let valueRange = yAxisRange.max - yAxisRange.min
        let valueFromMin = value - yAxisRange.min
        let positionRatio = valueFromMin / valueRange
        return height - (positionRatio * height) // Y轴是反向的
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
