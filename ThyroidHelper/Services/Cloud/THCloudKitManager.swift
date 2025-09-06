//
//  THCloudKitManager.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import AuthenticationServices
import CloudKit

@MainActor
class THCloudKitManager: ObservableObject {
    @Published var isSignedInToiCloud = false
    @Published var userName = ""
    @Published var userEmail = ""
    @Published var syncStatus = "未同步"
    
    private let container = CKContainer.default()
    
    init() {
        checkiCloudStatus()
    }
    
    func checkiCloudStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedInToiCloud = true
                    self?.syncStatus = "已连接iCloud"
                    self?.fetchUserInfo()
                case .noAccount:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "请登录iCloud"
                case .restricted, .couldNotDetermine:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "iCloud不可用"
                case .temporarilyUnavailable:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "iCloud暂时不可用，请在设置中验证您的凭据"
                @unknown default:
                    self?.isSignedInToiCloud = false
                }
            }
        }
    }
    
    private func fetchUserInfo() {
        container.fetchUserRecordID { [weak self] recordID, error in
            if let recordID = recordID {
                self?.container.discoverUserIdentity(withUserRecordID: recordID) { identity, error in
                    DispatchQueue.main.async {
                        if let identity = identity {
                            self?.userName = identity.nameComponents?.formatted() ?? "用户"
                            // 注意：邮箱需要用户授权才能获取
                        }
                    }
                }
            }
        }
    }
    
    func requestiCloudPermission() {
        // 引导用户到设置中登录iCloud
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
