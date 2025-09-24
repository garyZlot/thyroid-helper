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
    @Published var syncStatus = "sync_status_not_synced".localized
    
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
                    self?.syncStatus = "sync_status_icloud_connected".localized
                    self?.fetchUserInfo()
                case .noAccount:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "sync_status_please_sign_in_icloud".localized
                case .restricted, .couldNotDetermine:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "sync_status_icloud_unavailable".localized
                case .temporarilyUnavailable:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "sync_status_icloud_temporarily_unavailable".localized
                @unknown default:
                    self?.isSignedInToiCloud = false
                    self?.syncStatus = "sync_status_unknown_error".localized
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
                            self?.userName = identity.nameComponents?.formatted() ?? "user_name_default".localized
                        }
                    }
                }
            }
        }
    }
    
    func handleiCloudAction() {
        if isSignedInToiCloud {
            // 如果已登录，只刷新状态
            checkiCloudStatus()
        } else {
            // 如果未登录，引导用户到设置
            requestiCloudPermission()
        }
    }
    
    func requestiCloudPermission() {
        // 引导用户到设置中登录iCloud
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // 获取 iCloud 状态的描述文本和颜色
    var statusColor: Color {
        return isSignedInToiCloud ? .green : .orange
    }
    
    var actionButtonText: String {
        return isSignedInToiCloud ? "refresh_cloud_status".localized : "sign_in_to_icloud".localized
    }
    
    var actionButtonIcon: String {
        return isSignedInToiCloud ? "icloud.and.arrow.down" : "icloud.and.arrow.up"
    }
}
