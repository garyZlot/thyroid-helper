//
//  AboutView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("甲状腺复查助手")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("版本 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("应用介绍") {
                Text("甲状腺复查助手是专为甲状腺疾病患者设计的健康管理工具，帮助您：")
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("科学记录检查数据", systemImage: "doc.text")
                    Label("可视化展示指标趋势", systemImage: "chart.line.uptrend.xyaxis")
                    Label("智能提醒复查时间", systemImage: "bell")
                    Label("安全的iCloud数据同步", systemImage: "icloud")
                }
                .font(.subheadline)
            }
            
            Section("技术支持") {
                Link("用户反馈", destination: URL(string: "mailto:support@thyroidhelper.com")!)
                Link("隐私政策", destination: URL(string: "https://thyroidhelper.com/privacy")!)
                Link("用户协议", destination: URL(string: "https://thyroidhelper.com/terms")!)
            }
            
            Section {
                Text("本应用仅用于健康数据记录，不提供医疗建议。如有健康问题，请咨询专业医生。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
