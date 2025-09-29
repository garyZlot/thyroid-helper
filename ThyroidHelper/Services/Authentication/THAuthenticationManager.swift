//
//  AuthenticationManager.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import AuthenticationServices

@MainActor
class THAuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: AuthenticatedUser?
    
    struct AuthenticatedUser {
        let userID: String
        let fullName: String?
        let email: String?
    }
    
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                let fullName = credential.fullName?.formatted()
                let email = credential.email
                
                // 保存用户ID（必须）
                THKeychainHelper.save(userID, key: "userID")
                
                // fullName 和 email 只在非空时保存（避免覆盖旧值）
                if let fullName, !fullName.isEmpty {
                    THKeychainHelper.save(fullName, key: "fullName")
                }
                if let email, !email.isEmpty {
                    THKeychainHelper.save(email, key: "email")
                }
                
                // 从 Keychain 读取最新的数据（保证非空时保留旧值）
                let storedFullName = THKeychainHelper.read(key: "fullName")
                let storedEmail = THKeychainHelper.read(key: "email")
                
                self.user = AuthenticatedUser(userID: userID, fullName: storedFullName, email: storedEmail)
                self.isAuthenticated = true
            }
        case .failure(let error):
            print("授权失败: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        isAuthenticated = false
        user = nil
        THKeychainHelper.delete(key: "userID")
        THKeychainHelper.delete(key: "fullName")
        THKeychainHelper.delete(key: "email")
    }
    
    func checkExistingAuthentication() {
        #if targetEnvironment(simulator)
        // 模拟器里直接读取 Keychain，假装是已登录
        if let userID = THKeychainHelper.read(key: "userID") {
            self.isAuthenticated = true
            self.user = AuthenticatedUser(
                userID: userID,
                fullName: KeychainHelper.read(key: "fullName"),
                email: KeychainHelper.read(key: "email")
            )
        }
        #else
        if let userID = THKeychainHelper.read(key: "userID") {
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { [weak self] state, error in
                DispatchQueue.main.async {
                    switch state {
                    case .authorized:
                        self?.isAuthenticated = true
                        self?.user = AuthenticatedUser(
                            userID: userID,
                            fullName: THKeychainHelper.read(key: "fullName"),
                            email: THKeychainHelper.read(key: "email")
                        )
                    case .revoked, .notFound:
                        self?.signOut()
                    default:
                        break
                    }
                }
            }
        }
        #endif
    }
}
