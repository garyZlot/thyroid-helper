//
//  AuthenticationManager.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import AuthenticationServices

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
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
                
                // 保存用户信息
                UserDefaults.standard.set(userID, forKey: "userID")
                UserDefaults.standard.set(fullName, forKey: "fullName")
                UserDefaults.standard.set(email, forKey: "email")
                
                self.user = AuthenticatedUser(userID: userID, fullName: fullName, email: email)
                self.isAuthenticated = true
            }
        case .failure(let error):
            print("授权失败: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        isAuthenticated = false
        user = nil
        UserDefaults.standard.removeObject(forKey: "userID")
        UserDefaults.standard.removeObject(forKey: "fullName")
        UserDefaults.standard.removeObject(forKey: "email")
    }
    
    func checkExistingAuthentication() {
        if let userID = UserDefaults.standard.string(forKey: "userID") {
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { [weak self] state, error in
                DispatchQueue.main.async {
                    switch state {
                    case .authorized:
                        self?.isAuthenticated = true
                        self?.user = AuthenticatedUser(
                            userID: userID,
                            fullName: UserDefaults.standard.string(forKey: "fullName"),
                            email: UserDefaults.standard.string(forKey: "email")
                        )
                    case .revoked, .notFound:
                        self?.signOut()
                    default:
                        break
                    }
                }
            }
        }
    }
}
