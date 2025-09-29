// THAboutView.swift
// ThyroidHelper
//
// Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import MessageUI

struct THAboutView: View {
    @State private var showingMailComposer = false
    @State private var showingMailAlert = false
    
    var body: some View {
        Form {
            // App Header Section - 更紧凑的设计
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 45))
                        .foregroundColor(.blue)
                    
                    Text("app_title".localized)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("version_1_0_0".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
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
                Button(action: {
                    sendFeedbackEmail()
                }) {
                    Label("user_feedback".localized, systemImage: "envelope")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: EmptyView()) {
                    Label("privacy_policy".localized, systemImage: "hand.raised")
                        .foregroundColor(.primary)
                }
                
                NavigationLink(destination: EmptyView()) {
                    Label("terms_of_service".localized, systemImage: "doc.text")
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
        .sheet(isPresented: $showingMailComposer) {
            MailComposeView(
                recipients: ["support@thyroidhelper.com"],
                subject: generateEmailSubject(),
                body: generateEmailBody()
            )
        }
        .alert("mail_not_available".localized, isPresented: $showingMailAlert) {
            Button("copy_email".localized) {
                UIPasteboard.general.string = "support@thyroidhelper.com"
            }
            Button("ok".localized, role: .cancel) {}
        } message: {
            VStack(spacing: 8) {
                Text("mail_not_configured_message".localized)
                Text("support_email_label".localized + ": support@thyroidhelper.com")
                    .font(.footnote)
            }
        }
    }
    
    // MARK: - Email Functions
    
    private func sendFeedbackEmail() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            showingMailAlert = true
        }
    }
    
    private func generateEmailSubject() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return String(format: "feedback_email_subject".localized, appVersion)
    }
    
    private func generateEmailBody() -> String {
        let deviceInfo = THDeviceInfo.getFullDeviceInfo()
        
        return """
        \("feedback_email_info_header".localized)
                
                
        
        
                
        
        ──────────────────
        \("app_version_label".localized): \(deviceInfo.appVersion) (\(deviceInfo.buildNumber))
        \("ios_version_label".localized): \(deviceInfo.systemName) \(deviceInfo.systemVersion)
        \("device_model_label".localized): \(deviceInfo.modelName)
        ──────────────────
        """
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
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
