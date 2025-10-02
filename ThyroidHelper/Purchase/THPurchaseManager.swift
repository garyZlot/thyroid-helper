//
//  THPurchaseManager.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/10/2.
//

import StoreKit
import SwiftUI

/// 应用内购买管理器
@MainActor
class THPurchaseManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = THPurchaseManager()
    
    // MARK: - Published Properties
    @Published var isPremiumUser = false
    @Published var isLoading = false
    @Published var purchaseError: String?
    
    // MARK: - Product IDs
    enum ProductID: String {
        case premiumLifetime = "com.thyroidhelper.premium.lifetime"
    }
    
    // MARK: - Product Store
    private var products: [Product] = []
    private var purchasedProductIDs = Set<String>()
    
    // MARK: - Update Task
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    private init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = [
                ProductID.premiumLifetime.rawValue
            ]
            
            products = try await Product.products(for: productIDs)
            print("✅ 成功加载 \(products.count) 个产品")
        } catch {
            print("❌ 加载产品失败: \(error)")
            purchaseError = "failed_to_load_products".localized
        }
    }
    
    // MARK: - Purchase Status Check
    func updatePurchasedProducts() async {
        purchasedProductIDs.removeAll()
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
        
        isPremiumUser = !purchasedProductIDs.isEmpty
        print("📱 用户状态: \(isPremiumUser ? "高级用户" : "免费用户")")
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                await transaction.finish()
                await self.updatePurchasedProducts()
            }
        }
    }
    
    // MARK: - Purchase Methods
    func purchase(_ product: Product) async throws {
        isLoading = true
        purchaseError = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updatePurchasedProducts()
                    print("✅ 购买成功: \(product.displayName)")
                    
                case .unverified(_, let error):
                    throw error
                }
                
            case .userCancelled:
                print("ℹ️ 用户取消购买")
                purchaseError = "purchase_cancelled".localized
                
            case .pending:
                print("⏳ 购买待处理")
                purchaseError = "purchase_pending".localized
                
            @unknown default:
                print("⚠️ 未知购买结果")
            }
        } catch {
            print("❌ 购买失败: \(error)")
            purchaseError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            print("✅ 恢复购买成功")
        } catch {
            print("❌ 恢复购买失败: \(error)")
            purchaseError = "restore_failed".localized
        }
    }
    
    // MARK: - Product Accessors
    func getProduct(for productID: ProductID) -> Product? {
        return products.first { $0.id == productID.rawValue }
    }
    
    var allProducts: [Product] {
        return products
    }
    
    // MARK: - Feature Descriptions
    struct PremiumFeature {
        let icon: String
        let title: String
        let description: String
    }
    
    var premiumFeatures: [PremiumFeature] {
        return [
            PremiumFeature(
                icon: "square.stack.3d.up.fill",
                title: "unlimited_records".localized,
                description: "unlimited_records_desc".localized
            ),
            PremiumFeature(
                icon: "square.and.arrow.up.fill",
                title: "unlimited_exports".localized,
                description: "unlimited_exports_desc".localized
            ),
            PremiumFeature(
                icon: "icloud.fill",
                title: "icloud_sync".localized,
                description: "icloud_sync_desc".localized
            ),
            PremiumFeature(
                icon: "sparkles",
                title: "future_features".localized,
                description: "future_features_desc".localized
            )
        ]
    }
}
