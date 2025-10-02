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
    @StateObject private var purchaseManager = THPurchaseManager.shared
    
    @State private var selectedProduct: Product?
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
                    
                    // 产品选择
                    if !purchaseManager.isPremiumUser {
                        productsSection
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
    
    // MARK: - Products Section
    private var productsSection: some View {
        VStack(spacing: 16) {
            Text("choose_plan".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(purchaseManager.allProducts, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isPopular: product.id == THPurchaseManager.ProductID.premiumLifetime.rawValue
                ) {
                    selectedProduct = product
                }
            }
            
            if let product = selectedProduct {
                Button {
                    Task {
                        do {
                            try await purchaseManager.purchase(product)
                        } catch {
                            // Error handled by alert
                        }
                    }
                } label: {
                    Text("purchase_now".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(purchaseManager.isLoading)
            }
        }
    }
    
    // MARK: - Current Status Section
    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            Text("current_usage".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("records_limit".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(purchaseManager.remainingRecords())
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("exports_limit".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(purchaseManager.remainingExports())
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("premium_footer".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("terms_of_service".localized) {
                    // 打开服务条款
                }
                .font(.caption)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Button("privacy_policy".localized) {
                    // 打开隐私政策
                }
                .font(.caption)
            }
        }
        .padding(.top)
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        
                        if isPopular {
                            Text("popular".localized)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let subscription = product.subscription {
                        Text(periodDescription(for: subscription.subscriptionPeriod))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func periodDescription(for period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return "per_day".localized
        case .week:
            return "per_week".localized
        case .month:
            return "per_month".localized
        case .year:
            return "per_year".localized
        @unknown default:
            return ""
        }
    }
}
