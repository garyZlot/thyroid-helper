// THAboutView.swift
// ThyroidHelper
//
// Created by gdlium2p on 2025/8/25.
//

import SwiftUI

struct THAboutView: View {
    var body: some View {
        Form {
            // App Header Section - 更紧凑的设计
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 45)) // 从60减小到45
                        .foregroundColor(.blue)
                    
                    Text("app_title".localized)
                        .font(.title3) // 从title2改为title3
                        .fontWeight(.semibold)
                    
                    Text("version_1_0_0".localized)
                        .font(.caption) // 从subheadline改为caption，更小
                        .foregroundColor(.secondary) // 更淡的颜色
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8) // 减少垂直padding
            }
            
            // App Introduction Section - 更突出的设计
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // 应用描述
                    Text("app_description".localized)
                        .font(.body)
                        .lineLimit(nil)
                        .padding(.bottom, 8)
                    
                    // 功能特性 - 使用卡片式设计
                    VStack(spacing: 12) {
                        THFeatureRow(
                            icon: "doc.text",
                            title: "feature_record_data".localized,
                            color: .green
                        )
                        
                        THFeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "feature_visualize_trends".localized,
                            color: .orange
                        )
                        
                        THFeatureRow(
                            icon: "square.and.arrow.up.on.square",
                            title: "feature_data_export".localized,
                            color: .purple
                        )
                        
                        THFeatureRow(
                            icon: "icloud",
                            title: "feature_icloud_sync".localized,
                            color: .blue
                        )
                    }
                    .padding(.horizontal, 2)
                }
            } header: {
                Text("app_introduction".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // Technical Support Section
            Section("technical_support".localized) {
                NavigationLink(destination: EmptyView()) {
                    Label("user_feedback".localized, systemImage: "envelope")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: EmptyView()) {
                    Label("privacy_policy".localized, systemImage: "hand.raised")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: EmptyView()) {
                    Label("user_agreement".localized, systemImage: "doc.text")
                        .foregroundColor(.primary)
                }
            }
            
            // Medical Disclaimer
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("medical_disclaimer_title".localized, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("medical_disclaimer".localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("about".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 自定义功能行组件
struct THFeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NavigationView {
        THAboutView()
    }
}
