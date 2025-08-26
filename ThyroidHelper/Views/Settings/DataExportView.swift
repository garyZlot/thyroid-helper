//
//  DataExportView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import _SwiftData_SwiftUI

struct DataExportView: View {
    @Query private var records: [CheckupRecord]
    @State private var exportFormat = "CSV"
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        Form {
            Section("导出格式") {
                Picker("文件格式", selection: $exportFormat) {
                    Text("CSV").tag("CSV")
                    Text("PDF").tag("PDF")
                    Text("JSON").tag("JSON")
                }
                .pickerStyle(.segmented)
            }
            
            Section("数据范围") {
                HStack {
                    Text("检查记录")
                    Spacer()
                    Text("\(records.count) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("时间范围")
                    Spacer()
                    if let earliest = records.min(by: { $0.date < $1.date }),
                       let latest = records.max(by: { $0.date < $1.date }) {
                        Text("\(earliest.date.formatted(date: .abbreviated, time: .omitted)) - \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    } else {
                        Text("无数据")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: exportData) {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(records.isEmpty)
            }
            
            Section {
                Text("导出的数据可用于备份或医生咨询")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("数据导出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func exportData() {
        // 这里实现数据导出逻辑
        // 为简化演示，这里只是创建一个示例URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        exportURL = documentsPath.appendingPathComponent("thyroid_data.\(exportFormat.lowercased())")
        
        // 实际实现中需要根据选择的格式生成对应的文件
        showingShareSheet = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
