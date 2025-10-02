//
//  THUsageManager.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/10/2.
//

import SwiftUI
import SwiftData

/// 使用限制管理器
@MainActor
class THUsageManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = THUsageManager()
    
    // MARK: - Published Properties
    @Published var currentRecordCount = 0
    @Published var currentExportCount = 0
    
    // MARK: - Free User Limits
    struct FreeLimits {
        static let maxRecords = 10          // 免费用户最多10条记录
        static let maxExports = 5           // 总共最多导出5次
    }
    
    // MARK: - Database Context
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    private init() {
        // 初始化时不加载数据，等待注入 context
    }
    
    // MARK: - Inject ModelContext
    func injectModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadRecordCountFromDatabase()
        loadExportCountFromUserDefaults()
    }
    
    // MARK: - Limit Checking Methods
    
    /// 检查是否可以添加新记录
    func canAddNewRecord() -> Bool {
        if THPurchaseManager.shared.isPremiumUser {
            return true
        }
        return currentRecordCount < FreeLimits.maxRecords
    }
    
    /// 检查是否可以导出数据
    func canExportData() -> Bool {
        if THPurchaseManager.shared.isPremiumUser {
            return true
        }
        return currentExportCount < FreeLimits.maxExports
    }
    
    /// 从数据库加载记录计数
    private func loadRecordCountFromDatabase() {
        guard let context = modelContext else {
            print("⚠️ ModelContext 未注入，无法加载记录计数")
            return
        }
        
        do {
            let historyDescriptor = FetchDescriptor<THHistoryRecord>()
            let historyCount = try context.fetchCount(historyDescriptor)
            
            let checkupDescriptor = FetchDescriptor<THCheckupRecord>()
            let checkupCount = try context.fetchCount(checkupDescriptor)
            
            let totalCount = historyCount + checkupCount
            let previousCount = currentRecordCount
            currentRecordCount = totalCount
            if previousCount != totalCount {
                print("📊 从数据库加载记录总数: \(totalCount) (之前: \(previousCount))")
            }
        } catch {
            print("❌ 查询记录计数失败: \(error)")
            currentRecordCount = 0
        }
    }
    
    /// 从 UserDefaults 加载导出计数
    private func loadExportCountFromUserDefaults() {
        let storedCount = UserDefaults.standard.integer(forKey: "TotalExportCount")
        let previousCount = currentExportCount
        currentExportCount = storedCount
        if previousCount != storedCount {
            print("📤 从 UserDefaults 加载导出总数: \(storedCount) (之前: \(previousCount))")
        }
    }
    
    /// 增加导出计数
    func incrementExportCount() {
        let previousCount = currentExportCount
        currentExportCount += 1
        UserDefaults.standard.set(currentExportCount, forKey: "TotalExportCount")
        print("📤 导出计数增加: \(currentExportCount)/\(FreeLimits.maxExports) (之前: \(previousCount))")
    }
    
    // MARK: - Upgrade Prompt
    /// 是否应该显示升级提示
    func shouldShowUpgradePrompt() -> Bool {
        let isPremium = THPurchaseManager.shared.isPremiumUser
        let nearRecordLimit = currentRecordCount >= FreeLimits.maxRecords - 2
        let nearExportLimit = currentExportCount >= FreeLimits.maxExports - 1
        
        return !isPremium && (nearRecordLimit || nearExportLimit)
    }
    
    // MARK: - Formatted Display
    func remainingRecords() -> String {
        if THPurchaseManager.shared.isPremiumUser {
            return "unlimited".localized
        }
        let remaining = max(0, FreeLimits.maxRecords - currentRecordCount)
        return "\(remaining)/\(FreeLimits.maxRecords)"
    }
    
    func remainingExports() -> String {
        if THPurchaseManager.shared.isPremiumUser {
            return "unlimited".localized
        }
        let remaining = max(0, FreeLimits.maxExports - currentExportCount)
        return "\(remaining)/\(FreeLimits.maxExports)"
    }
    
    /// 同步记录计数（从数据库） - 在添加/删除记录后调用
    func syncRecordCount() {
        loadRecordCountFromDatabase()
    }
    
    /// 刷新所有计数 - 可在视图 onAppear 等地方调用
    func refreshCounts() {
        loadRecordCountFromDatabase()
        loadExportCountFromUserDefaults()
    }
}
