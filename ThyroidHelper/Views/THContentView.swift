//
//  THContentView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/25.
//

import SwiftUI
import SwiftData

struct THContentView: View {
    @StateObject private var authManager = THAuthenticationManager()
    @StateObject private var cloudManager = THCloudKitManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                THMainTabView()
                    .environmentObject(authManager)
                    .environmentObject(cloudManager)
            } else {
                THLoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            authManager.checkExistingAuthentication()
        }
    }
}
