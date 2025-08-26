//
//  ContentView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var cloudManager = CloudKitManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(cloudManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            authManager.checkExistingAuthentication()
        }
    }
}
