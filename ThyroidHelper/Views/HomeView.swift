//
//  HomeView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckupRecord.date, order: .reverse) private var records: [CheckupRecord]
    @State private var showingAddRecord = false
    
    var latestRecord: CheckupRecord? {
        records.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // 复查提醒卡片
                    CheckupReminderCard(latestRecord: latestRecord)
                        .padding(.vertical, 8)
                    
                    // 最新检查结果
                    if let record = latestRecord {
                        LatestResultCard(record: record)
                    } else {
                        EmptyStateCard()
                    }
                    
                    // 快速操作按钮
                    QuickActionButtons(showingAddRecord: $showingAddRecord)
                }
                .padding()
            }
            .navigationTitle("甲状腺助手")
            .sheet(isPresented: $showingAddRecord) {
                AddRecordView()
            }
        }
    }
}

struct CheckupReminderCard: View {
    let latestRecord: CheckupRecord?
    
    private var nextCheckupDate: Date? {
        guard let lastDate = latestRecord?.date else { return nil }
        return Calendar.current.date(byAdding: .month, value: 6, to: lastDate)
    }
    
    private var formattedNextCheckupDate: String? {
        guard let date = nextCheckupDate else { return nil }
            
        let formatter = DateFormatter()
        formatter.locale = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0) } ?? Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if formatter.locale.identifier.starts(with: "zh") {
            formatter.dateFormat = "yyyy年MM月dd日"
        }
        
        return formatter.string(from: date)
    }
    
    private var daysUntilCheckup: Int? {
        guard let nextDate = nextCheckupDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day
        return days
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("下次复查提醒")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let days = daysUntilCheckup {
                        if days > 0 {
                            Text("距离下次检查还有")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            + Text("\(days)")
                                .font(.headline)
                                .foregroundColor(.orange.opacity(1.0))
                            + Text(" 天")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            Text("该复查了！")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .fontWeight(.bold)
                        }
                    } else {
                        Text("添加检查记录开始追踪")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if let nextDate = formattedNextCheckupDate {
                        Text("下次检查日期：\(nextDate)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
}

struct LatestResultCard: View {
    let record: CheckupRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text("最新检查结果")
                    .font(.headline)
                
                Text("\(record.date.formatted(date: .abbreviated, time: .omitted)) · \(record.type.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 6) {
                ForEach((record.indicators ?? []).sortedByMedicalOrder(), id: \.name) { indicator in
                    IndicatorCard(indicator: indicator)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct IndicatorCard: View {
    let indicator: ThyroidIndicator
    
    var body: some View {
        VStack(spacing: 4) {
            Text(indicator.name)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(indicator.value, format: .number.precision(.fractionLength(ThyroidConfig.decimalPlaces(for: indicator.name))))
                .font(.title3)
                .fontWeight(.bold)
            
            Text(indicator.unit)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("参考: \(indicator.normalRange)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundColorForStatus(indicator.status))
        .cornerRadius(12)
    }
    
    private func backgroundColorForStatus(_ status: ThyroidIndicator.IndicatorStatus) -> Color {
        switch status {
        case .normal:
            return Color.green.opacity(0.1)
        case .high:
            return Color.red.opacity(0.1)
        case .low:
            return Color.blue.opacity(0.1)
        }
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("暂无检查记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("添加您的第一条检查记录开始健康管理")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct QuickActionButtons: View {
    @Binding var showingAddRecord: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: { showingAddRecord = true }) {
                Label("拍照录入", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
            
            NavigationLink(destination: TrendsView()) {
                Label("查看趋势", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
        }
    }
}
