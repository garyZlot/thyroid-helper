//
//  LoginView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import _AuthenticationServices_SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App图标和标题
            VStack(spacing: 16) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("甲状腺复查助手")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("科学管理检查数据，守护甲状腺健康")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // 功能介绍
            VStack(spacing: 20) {
                FeatureRow(icon: "camera.fill", title: "拍照识别", description: "智能识别检查报告数值")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "趋势分析", description: "可视化指标变化趋势")
                FeatureRow(icon: "icloud.fill", title: "云端同步", description: "数据安全存储在iCloud")
                FeatureRow(icon: "bell.fill", title: "智能提醒", description: "不错过每次复查时间")
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
            
            Text("使用Apple ID登录，数据加密存储")
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
