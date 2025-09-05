//
//  THImageViewer.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/9/5.
//

import SwiftUI
import Photos

struct THImageViewer: View {
    let imageDatas: [Data]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingSaveSuccess = false
    
    init(imageDatas: [Data], initialIndex: Int = 0) {
        self.imageDatas = imageDatas
        _currentIndex = State(initialValue: min(initialIndex, imageDatas.count - 1))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !imageDatas.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(imageDatas.enumerated()), id: \.offset) { index, data in
                        if let uiImage = UIImage(data: data) {
                            ZoomableImageView(image: uiImage)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // 顶部工具栏
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    
                    Spacer()
                    
                    if imageDatas.count > 1 {
                        Text("\(currentIndex + 1) / \(imageDatas.count)")
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button {
                            saveCurrentImageToPhotos()
                        } label: {
                            Label("保存到相册", systemImage: "square.and.arrow.down")
                        }
                        
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showingShareSheet) {
            if let currentImageData = imageDatas[safe: currentIndex],
               let uiImage = UIImage(data: currentImageData) {
                ShareSheet(items: [uiImage])
            }
        }
        .alert("已保存到相册", isPresented: $showingSaveSuccess) {
            Button("好的") { }
        }
    }
    
    private func saveCurrentImageToPhotos() {
        guard let currentImageData = imageDatas[safe: currentIndex],
              let uiImage = UIImage(data: currentImageData) else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        showingSaveSuccess = true
                    }
                }
            }
        }
    }
}

// MARK: - 可缩放图片视图
struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(1.0, min(value, 5.0))
                        }
                        .onEnded { _ in
                            if scale < 1.0 { resetZoom() }
                        }
                )
                .gesture(
                    scale > 1.0 ? DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            clampOffset(screenSize: geometry.size)
                        }
                    : nil // 不放大时禁用拖拽手势，让 TabView 接管
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if scale > 1.0 {
                            resetZoom()
                        } else {
                            scale = 2.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                }
        }
    }
    
    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    private func clampOffset(screenSize: CGSize) {
        let imageSize = getImageDisplaySize(screenSize: screenSize)
        let maxOffsetX = max(0, (imageSize.width * scale - screenSize.width) / 2)
        let maxOffsetY = max(0, (imageSize.height * scale - screenSize.height) / 2)
        
        let clampedOffset = CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
        
        withAnimation(.easeOut(duration: 0.3)) {
            offset = clampedOffset
            lastOffset = clampedOffset
        }
    }
    
    private func getImageDisplaySize(screenSize: CGSize) -> CGSize {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        let screenAspectRatio = screenSize.width / screenSize.height
        
        if aspectRatio > screenAspectRatio {
            let displayWidth = screenSize.width
            let displayHeight = displayWidth / aspectRatio
            return CGSize(width: displayWidth, height: displayHeight)
        } else {
            let displayHeight = screenSize.height
            let displayWidth = displayHeight * aspectRatio
            return CGSize(width: displayWidth, height: displayHeight)
        }
    }
}

// MARK: - 安全下标
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
