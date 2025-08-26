//
//  RawTextView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

import SwiftUI

struct RawTextView: View {
    let text: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("OCR识别原始文本")
                        .font(.headline)
                    
                    if text.isEmpty {
                        Text("未识别到任何文本")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("识别文本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
