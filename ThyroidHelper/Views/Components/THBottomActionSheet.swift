//
//  Untitled.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/23.
//

import SwiftUI

// MARK: - 底部选择组件数据模型
struct THBottomSheetOption {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    init(icon: String, iconColor: Color = .blue, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
}

// MARK: - 底部选择组件
struct THBottomActionSheet: View {
    let title: String
    let options: [THBottomSheetOption]
    let cancelTitle: String
    let onDismiss: () -> Void // ✅ 使用回调而不是 Binding
    
    init(
        title: String,
        options: [THBottomSheetOption],
        cancelTitle: String = "Cancel".localized,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.options = options
        self.cancelTitle = cancelTitle
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding()
            
            Divider()
            
            // 选项列表
            ForEach(options, id: \.id) { option in
                Button(action: {
                    onDismiss() // ✅ 通过回调关闭
                    option.action()
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: option.icon)
                            .font(.title2)
                            .foregroundColor(option.iconColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.headline)
                            
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if option.id != options.last?.id {
                    Divider()
                }
            }
            
            Divider()
            
            // 取消按钮
            Button(cancelTitle, role: .cancel) {
                onDismiss() // ✅ 通过回调关闭
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .foregroundColor(.primary)
    }
}

// MARK: - View 扩展，简化使用
extension View {
    func bottomActionSheet(
        isPresented: Binding<Bool>,
        title: String,
        options: [THBottomSheetOption],
        cancelTitle: String = "Cancel".localized
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            THBottomActionSheet(
                title: title,
                options: options,
                cancelTitle: cancelTitle,
                onDismiss: {
                    print("BottomActionSheet dismissed")
                    isPresented.wrappedValue = false
                }
            )
            .presentationDetents([.height(CGFloat(120 + options.count * 80))])
            .presentationDragIndicator(.visible)
        }
    }
}
