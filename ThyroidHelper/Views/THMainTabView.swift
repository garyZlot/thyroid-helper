//
//  MainTabView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData

struct THMainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: THAuthenticationManager
    @EnvironmentObject var cloudManager: THCloudKitManager
    
    var body: some View {
        TabView {
            THHomeView()
                .tabItem {
                    Label("home".localized, systemImage: "house.fill")
                }
            
            THTrendsView()
                .tabItem {
                    Label("trends".localized, systemImage: "chart.line.uptrend.xyaxis")
                }
            
            THIndicatorsView()
                .tabItem {
                    Label("indicators".localized, systemImage: "doc.text.fill")
                }
            
            THHistoryView()
                .tabItem {
                    Label("history".localized, systemImage: "clock.fill")
                }
            
            THProfileView()
                .tabItem {
                    Label("profile".localized, systemImage: "person.fill")
                }
        }
        .onAppear {
            // 添加示例数据（仅首次运行）
            addSampleDataIfNeeded()
        }
    }
    
    private func addSampleDataIfNeeded() {
        let descriptor = FetchDescriptor<THCheckupRecord>()
        let existingRecords = try? modelContext.fetch(descriptor)
        
        if existingRecords?.isEmpty ?? true {
            createSampleData()
        }
    }
    
    private func createSampleData() {
        let sampleRecords = [
            createSampleRecord(
                daysAgo: 30,
                indicators: [
                    ("TSH", 0.565, "μIU/mL", "0.27-4.2"),
                    ("FT3", 4.8, "pmol/L", "3.1-6.8"),
                    ("FT4", 18.2, "pmol/L", "12-22"),
                    ("A-TG", 2.84, "IU/mL", "3.5-77"),
                    ("A-TPO", 81.20, "IU/mL", "<34")
                ]
            ),
            createSampleRecord(
                daysAgo: 210,
                indicators: [
                    ("TSH", 0.42, "μIU/mL", "0.27-4.2"),
                    ("FT3", 4.9, "pmol/L", "3.1-6.8"),
                    ("FT4", 16.7, "pmol/L", "12-22"),
                    ("A-TG", 3.2, "IU/mL", "3.5-77"),
                    ("A-TPO", 78.5, "IU/mL", "<34")
                ]
            )
        ]
        
        sampleRecords.forEach { modelContext.insert($0) }
        try? modelContext.save()
    }
    
    private func createSampleRecord(daysAgo: Int, indicators: [(String, Double, String, String)]) -> THCheckupRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let record = THCheckupRecord(date: date, type: .thyroidFunction5)
        
        for (name, value, unit, range) in indicators {
            let status = THIndicatorRecord.determineStatus(value: value, normalRange: range)
            let indicator = THIndicatorRecord(name: name, value: value, unit: unit, normalRange: range, status: status)
            indicator.checkupRecord = record
            record.indicators?.append(indicator)
        }
        
        return record
    }
}
