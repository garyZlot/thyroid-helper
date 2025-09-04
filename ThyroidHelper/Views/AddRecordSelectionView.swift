//
//  AddRecordSelectionView.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/9/4.
//

import SwiftUI

struct AddRecordSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelectionMade: (AddRecordType) -> Void
    
    enum AddRecordType {
        case ocrRecognition
        case manual
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("添加档案记录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("选择您喜欢的添加方式")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    // 图片识别添加
                    Button {
                        onSelectionMade(.ocrRecognition)
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("图片识别添加")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("拍照或选择图片，自动识别日期和内容")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 手动添加
                    Button {
                        onSelectionMade(.manual)
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "square.and.pencil")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("手动添加")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("手动输入所有信息，完全自定义")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("添加记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddRecordSelectionView { type in
        print("Selected: \(type)")
    }
}
