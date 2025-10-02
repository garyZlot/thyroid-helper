//
//  THPremiumView.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/10/2.
//

import SwiftUI
import StoreKit

struct THPremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var usageManager = THUsageManager.shared
    @StateObject private var purchaseManager = THPurchaseManager.shared
    
    @State private var showingError = false
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部图标
                    headerSection
                    
                    // 功能列表
                    featuresSection
                    
                    // 升级按钮
                    if !purchaseManager.isPremiumUser {
                        upgradeButtonSection
                    }
                    
                    // 当前状态
                    currentStatusSection
                    
                    // 底部说明
                    footerSection
                }
                .padding()
            }
            .navigationTitle("premium_version".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
                
                if !purchaseManager.isPremiumUser {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("restore".localized) {
                            Task {
                                await purchaseManager.restorePurchases()
                            }
                        }
                        .disabled(purchaseManager.isLoading)
                    }
                }
            }
            .overlay {
                if purchaseManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .alert("purchase_error".localized, isPresented: $showingError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                if let error = purchaseManager.purchaseError {
                    Text(error)
                }
            }
            .alert("purchase_success".localized, isPresented: $showingSuccess) {
                Button("ok".localized, role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("purchase_success_message".localized)
            }
        }
        .onChange(of: purchaseManager.isPremiumUser) { _, isPremium in
            if isPremium {
                showingSuccess = true
            }
        }
        .onChange(of: purchaseManager.purchaseError) { _, error in
            if error != nil {
                showingError = true
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("unlock_premium".localized)
                .font(.title)
                .fontWeight(.bold)
            
            Text("premium_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 16) {
            ForEach(purchaseManager.premiumFeatures, id: \.title) { feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.headline)
                        
                        Text(feature.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Upgrade Button Section
    private var upgradeButtonSection: some View {
        VStack(spacing: 16) {
            if let product = purchaseManager.allProducts.first {
                Button {
                    Task {
                        do {
                            try await purchaseManager.purchase(product)
                        } catch {
                            // Error handled by alert
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(product.description)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text(product.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }
                .disabled(purchaseManager.isLoading)
            } else {
                ProgressView("loading_products".localized)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Current Status Section
    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            Text("current_usage".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Records Progress
                usageProgressView(
                    title: "records_limit".localized,
                    current: usageManager.currentRecordCount,
                    max: THUsageManager.FreeLimits.maxRecords,
                    unlimited: purchaseManager.isPremiumUser,
                    color: .blue
                )
                
                // Exports Progress
                usageProgressView(
                    title: "exports_limit".localized,
                    current: usageManager.currentExportCount,
                    max: THUsageManager.FreeLimits.maxExports,
                    unlimited: purchaseManager.isPremiumUser,
                    color: .orange
                )
            }
        }
    }
    
    private func usageProgressView(title: String, current: Int, max: Int, unlimited: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(unlimited ? "unlimited".localized : "\(current)/\(max)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(unlimited ? .green : (current >= max ? .red : .primary))
            }
            
            if !unlimited {
                ProgressView(value: Double(current), total: Double(max))
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(height: 8)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                NavigationLink {
                    THWebDocumentView(documentType: .termsOfService)
                } label: {
                    Text("terms_of_service".localized)
                        .font(.caption)
                }
                
                Text("•")
                    .foregroundColor(.secondary)
                
                NavigationLink {
                    THWebDocumentView(documentType: .privacyPolicy)
                } label: {
                    Text("privacy_policy".localized)
                        .font(.caption)
                }
            }
        }
        .padding(.top)
    }
}
