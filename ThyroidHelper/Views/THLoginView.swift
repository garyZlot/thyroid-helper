//
//  THLoginView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import AuthenticationServices

struct THLoginView: View {
    @EnvironmentObject var authManager: THAuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App图标和标题
            VStack(spacing: 16) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("app_title".localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("app_subtitle".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // 功能介绍
            VStack(spacing: 20) {
                FeatureRow(icon: "camera.fill", title: "feature_photo_recognition".localized, description: "feature_photo_recognition_desc".localized)
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "feature_trend_analysis".localized, description: "feature_trend_analysis_desc".localized)
                FeatureRow(icon: "icloud.fill", title: "feature_cloud_sync".localized, description: "feature_cloud_sync_desc".localized)
                FeatureRow(icon: "square.and.arrow.up.on.square", title: "feature_professional_export".localized, description: "feature_professional_export_desc".localized)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Apple登录按钮
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                authManager.handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 30)
            
            Text("apple_signin_note".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
        }
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
