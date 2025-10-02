//
//  THLimitReachedView.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/10/2.
//

import SwiftUI

struct THLimitReachedView: View {
    let limitType: LimitType
    @Environment(\.dismiss) private var dismiss
    @State private var showPremiumView = false
    
    enum LimitType {
        case records
        case exports
        
        var icon: String {
            switch self {
            case .records: return "square.stack.3d.up.fill"
            case .exports: return "square.and.arrow.up.fill"
            }
        }
        
        var title: String {
            switch self {
            case .records: return "record_limit_reached".localized
            case .exports: return "export_limit_reached".localized
            }
        }
        
        var message: String {
            switch self {
            case .records:
                return "record_limit_message".localized
            case .exports:
                return "export_limit_message".localized
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: limitType.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
            }
            
            // 标题和说明
            VStack(spacing: 12) {
                Text(limitType.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(limitType.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // 升级按钮
            Button {
                showPremiumView = true
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("upgrade_to_premium".localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // 取消按钮
            Button("cancel".localized) {
                dismiss()
            }
            .font(.body)
            .foregroundColor(.secondary)
        }
        .padding()
        .sheet(isPresented: $showPremiumView) {
            THPremiumView()
        }
    }
}

// MARK: - 便捷使用的 Alert 修饰符
extension View {
    func limitReachedAlert(
        isPresented: Binding<Bool>,
        limitType: THLimitReachedView.LimitType
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            THLimitReachedView(limitType: limitType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

