//
//  THDeviceInfo.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/29.
//

import UIKit

/// 设备信息获取工具类
struct THDeviceInfo {
    
    /// 获取设备标识符（如 iPhone15,2）
    static func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    /// 获取设备可读名称（如 iPhone 15 Pro）
    static func getDeviceModel() -> String {
        let identifier = getDeviceIdentifier()
        return deviceNamesByCode[identifier] ?? identifier
    }
    
    /// 获取完整的设备信息
    static func getFullDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            identifier: getDeviceIdentifier(),
            modelName: getDeviceModel(),
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        )
    }
    
    /// 设备信息结构
    struct DeviceInfo {
        let identifier: String      // 设备标识符
        let modelName: String        // 设备型号名称
        let systemName: String       // 系统名称 (iOS)
        let systemVersion: String    // 系统版本
        let appVersion: String       // 应用版本
        let buildNumber: String      // 构建号
        
        /// 格式化为邮件内容
        func formatForEmail() -> String {
            return """
            App Version: \(appVersion) (\(buildNumber))
            \(systemName) Version: \(systemVersion)
            Device Model: \(modelName)
            Device Identifier: \(identifier)
            """
        }
    }
    
    // MARK: - Device Model Mapping
    
    /// 设备型号映射表
    private static let deviceNamesByCode: [String: String] = [
        
        // MARK: - iPhone
        
        // iPhone 16 系列 (2024)
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        
        // iPhone 15 系列 (2023)
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        
        // iPhone 14 系列 (2022)
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        
        // iPhone 13 系列 (2021)
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        
        // iPhone 12 系列 (2020)
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        
        // iPhone 11 系列 (2019)
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        
        // iPhone XS/XR 系列 (2018)
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max (China)",
        "iPhone11,8": "iPhone XR",
        
        // iPhone X (2017)
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X (Global)",
        
        // iPhone 8 系列 (2017)
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8 (Global)",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus (Global)",
        
        // iPhone 7 系列 (2016)
        "iPhone9,1": "iPhone 7",
        "iPhone9,3": "iPhone 7 (Global)",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,4": "iPhone 7 Plus (Global)",
        
        // iPhone SE
        "iPhone8,4": "iPhone SE (1st generation)",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone14,6": "iPhone SE (3rd generation)",
        
        // iPhone 6s 系列 (2015)
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        
        // iPhone 6 系列 (2014)
        "iPhone7,2": "iPhone 6",
        "iPhone7,1": "iPhone 6 Plus",
        
        // MARK: - iPad Pro
        
        // iPad Pro 12.9-inch
        "iPad6,7": "iPad Pro 12.9-inch (1st generation)",
        "iPad6,8": "iPad Pro 12.9-inch (1st generation, Wi-Fi + Cellular)",
        "iPad7,1": "iPad Pro 12.9-inch (2nd generation)",
        "iPad7,2": "iPad Pro 12.9-inch (2nd generation, Wi-Fi + Cellular)",
        "iPad8,5": "iPad Pro 12.9-inch (3rd generation)",
        "iPad8,6": "iPad Pro 12.9-inch (3rd generation, Wi-Fi + Cellular)",
        "iPad8,11": "iPad Pro 12.9-inch (4th generation)",
        "iPad8,12": "iPad Pro 12.9-inch (4th generation, Wi-Fi + Cellular)",
        "iPad13,8": "iPad Pro 12.9-inch (5th generation)",
        "iPad13,9": "iPad Pro 12.9-inch (5th generation, Wi-Fi + Cellular)",
        "iPad14,5": "iPad Pro 12.9-inch (6th generation)",
        "iPad14,6": "iPad Pro 12.9-inch (6th generation, Wi-Fi + Cellular)",
        
        // iPad Pro 11-inch
        "iPad8,1": "iPad Pro 11-inch (1st generation)",
        "iPad8,2": "iPad Pro 11-inch (1st generation, Wi-Fi + Cellular)",
        "iPad8,9": "iPad Pro 11-inch (2nd generation)",
        "iPad8,10": "iPad Pro 11-inch (2nd generation, Wi-Fi + Cellular)",
        "iPad13,4": "iPad Pro 11-inch (3rd generation)",
        "iPad13,5": "iPad Pro 11-inch (3rd generation, Wi-Fi + Cellular)",
        "iPad14,3": "iPad Pro 11-inch (4th generation)",
        "iPad14,4": "iPad Pro 11-inch (4th generation, Wi-Fi + Cellular)",
        
        // iPad Pro 10.5-inch
        "iPad7,3": "iPad Pro 10.5-inch",
        "iPad7,4": "iPad Pro 10.5-inch (Wi-Fi + Cellular)",
        
        // iPad Pro 9.7-inch
        "iPad6,3": "iPad Pro 9.7-inch",
        "iPad6,4": "iPad Pro 9.7-inch (Wi-Fi + Cellular)",
        
        // MARK: - iPad Air
        
        "iPad11,3": "iPad Air (3rd generation)",
        "iPad11,4": "iPad Air (3rd generation, Wi-Fi + Cellular)",
        "iPad13,1": "iPad Air (4th generation)",
        "iPad13,2": "iPad Air (4th generation, Wi-Fi + Cellular)",
        "iPad13,16": "iPad Air (5th generation)",
        "iPad13,17": "iPad Air (5th generation, Wi-Fi + Cellular)",
        "iPad14,8": "iPad Air 11-inch (M2)",
        "iPad14,9": "iPad Air 11-inch (M2, Wi-Fi + Cellular)",
        "iPad14,10": "iPad Air 13-inch (M2)",
        "iPad14,11": "iPad Air 13-inch (M2, Wi-Fi + Cellular)",
        
        // MARK: - iPad
        
        "iPad7,5": "iPad (6th generation)",
        "iPad7,6": "iPad (6th generation, Wi-Fi + Cellular)",
        "iPad7,11": "iPad (7th generation)",
        "iPad7,12": "iPad (7th generation, Wi-Fi + Cellular)",
        "iPad11,6": "iPad (8th generation)",
        "iPad11,7": "iPad (8th generation, Wi-Fi + Cellular)",
        "iPad12,1": "iPad (9th generation)",
        "iPad12,2": "iPad (9th generation, Wi-Fi + Cellular)",
        "iPad13,18": "iPad (10th generation)",
        "iPad13,19": "iPad (10th generation, Wi-Fi + Cellular)",
        
        // MARK: - iPad mini
        
        "iPad11,1": "iPad mini (5th generation)",
        "iPad11,2": "iPad mini (5th generation, Wi-Fi + Cellular)",
        "iPad14,1": "iPad mini (6th generation)",
        "iPad14,2": "iPad mini (6th generation, Wi-Fi + Cellular)",
        
        // MARK: - iPod touch
        
        "iPod9,1": "iPod touch (7th generation)",
        
        // MARK: - Apple Watch
        
        "Watch1,1": "Apple Watch (1st generation)",
        "Watch1,2": "Apple Watch (1st generation)",
        "Watch2,6": "Apple Watch Series 1",
        "Watch2,7": "Apple Watch Series 1",
        "Watch2,3": "Apple Watch Series 2",
        "Watch2,4": "Apple Watch Series 2",
        "Watch3,1": "Apple Watch Series 3",
        "Watch3,2": "Apple Watch Series 3",
        "Watch3,3": "Apple Watch Series 3",
        "Watch3,4": "Apple Watch Series 3",
        "Watch4,1": "Apple Watch Series 4",
        "Watch4,2": "Apple Watch Series 4",
        "Watch4,3": "Apple Watch Series 4",
        "Watch4,4": "Apple Watch Series 4",
        "Watch5,1": "Apple Watch Series 5",
        "Watch5,2": "Apple Watch Series 5",
        "Watch5,3": "Apple Watch Series 5",
        "Watch5,4": "Apple Watch Series 5",
        "Watch5,9": "Apple Watch SE",
        "Watch5,10": "Apple Watch SE",
        "Watch5,11": "Apple Watch SE",
        "Watch5,12": "Apple Watch SE",
        "Watch6,1": "Apple Watch Series 6",
        "Watch6,2": "Apple Watch Series 6",
        "Watch6,3": "Apple Watch Series 6",
        "Watch6,4": "Apple Watch Series 6",
        "Watch6,6": "Apple Watch Series 7",
        "Watch6,7": "Apple Watch Series 7",
        "Watch6,8": "Apple Watch Series 7",
        "Watch6,9": "Apple Watch Series 7",
        "Watch6,10": "Apple Watch SE (2nd generation)",
        "Watch6,11": "Apple Watch SE (2nd generation)",
        "Watch6,12": "Apple Watch SE (2nd generation)",
        "Watch6,13": "Apple Watch SE (2nd generation)",
        "Watch6,14": "Apple Watch Series 8",
        "Watch6,15": "Apple Watch Series 8",
        "Watch6,16": "Apple Watch Series 8",
        "Watch6,17": "Apple Watch Series 8",
        "Watch6,18": "Apple Watch Ultra",
        "Watch7,1": "Apple Watch Series 9",
        "Watch7,2": "Apple Watch Series 9",
        "Watch7,3": "Apple Watch Series 9",
        "Watch7,4": "Apple Watch Series 9",
        "Watch7,5": "Apple Watch Ultra 2",
        
        // MARK: - Simulator
        
        "i386": "iPhone Simulator (32-bit)",
        "x86_64": "iPhone Simulator (64-bit)",
        "arm64": "iPhone Simulator (Apple Silicon)"
    ]
}

// MARK: - Convenience Extensions

extension THDeviceInfo {
    
    /// 是否是 iPhone
    static var isiPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    /// 是否是 iPad
    static var isiPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// 是否是模拟器
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// 是否支持 Face ID
    static var supportsFaceID: Bool {
        let identifier = getDeviceIdentifier()
        // iPhone X 及以后的设备（除 SE 系列）
        return identifier.contains("iPhone") &&
               !identifier.contains("iPhone8,4") &&
               !identifier.contains("iPhone12,8") &&
               !identifier.contains("iPhone14,6") &&
               (identifier.compare("iPhone10,3") != .orderedAscending)
    }
}
