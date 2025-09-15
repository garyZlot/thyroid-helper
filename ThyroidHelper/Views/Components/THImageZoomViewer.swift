//
//  Untitled.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/15.
//

import SwiftUI

struct THImageZoomViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(1.0, lastScale * value)
                        }
                        .onEnded { value in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) { // 🆕 双击放大/还原
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
                .onTapGesture { // 单击关闭
                    dismiss()
                }
                .animation(.spring(), value: scale)
                .animation(.spring(), value: offset)
        }
    }
}
