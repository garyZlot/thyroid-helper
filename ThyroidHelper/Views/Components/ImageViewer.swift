//
//  ImageViewer.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/9/4.
//

import SwiftUI
import Photos

struct ImageViewer: View {
    let imageDatas: [Data]
    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingSaveSuccess = false
    
    init(imageDatas: [Data], initialIndex: Int = 0) {
        self.imageDatas = imageDatas
        self._currentIndex = State(initialValue: min(initialIndex, imageDatas.count - 1))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !imageDatas.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(imageDatas.enumerated()), id: \.offset) { index, imageData in
                        if let uiImage = UIImage(data: imageData) {
                            ZoomableImageView(image: uiImage)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            let threshold: CGFloat = 50
                            if gesture.translation.height > threshold {
                                dismiss()
                            }
                        }
                )
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
                
                // 底部页面指示器（多图时显示）
                if imageDatas.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<imageDatas.count, id: \.self) { index in
                            Circle()
                                .fill(currentIndex == index ? Color.white : Color.gray)
                                .frame(width: 8, height: 8)
                                .onTapGesture {
                                    withAnimation {
                                        currentIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 40)
                }
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
              let uiImage = UIImage(data: currentImageData) else {
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showingSaveSuccess = true
                    }
                }
            }
        }
    }
}

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
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1.0, min(value, 5.0))
                            }
                            .onEnded { _ in
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                }
                            },
                        
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                                
                                // 边界检查
                                let maxOffset = (scale - 1) * min(geometry.size.width, geometry.size.height) / 2
                                offset = CGSize(
                                    width: min(max(offset.width, -maxOffset), maxOffset),
                                    height: min(max(offset.height, -maxOffset), maxOffset)
                                )
                                lastOffset = offset
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
