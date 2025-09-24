//
//  THAboutView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI

struct THAboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("app_title".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("version_1_0_0".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("app_introduction".localized) {
                Text("app_description".localized)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("feature_record_data".localized, systemImage: "doc.text")
                    Label("feature_visualize_trends".localized, systemImage: "chart.line.uptrend.xyaxis")
                    Label("feature_smart_reminders".localized, systemImage: "bell")
                    Label("feature_icloud_sync".localized, systemImage: "icloud")
                }
                .font(.subheadline)
            }
            
            Section("technical_support".localized) {
                Link("user_feedback".localized, destination: URL(string: "mailto:support@thyroidhelper.com")!)
                Link("privacy_policy".localized, destination: URL(string: "https://thyroidhelper.com/privacy")!)
                Link("user_agreement".localized, destination: URL(string: "https://thyroidhelper.com/terms")!)
            }
            
            Section {
                Text("medical_disclaimer".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("about".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
