//
//  THPanelOCRResultView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

//
//  THPanelOCRResultView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

import SwiftUI

struct THPanelOCRResultView: View {
    @StateObject private var ocrService: THThyroidPanelOCRService
    let capturedImage: UIImage
    let indicatorType: THThyroidPanelRecord.CheckupType
    let onConfirm: ([String: Double]) -> Void
    let onDateExtracted: (Date?) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var manualAdjustments: [String: String] = [:]
    @State private var showingRawText = false
    @State private var showingImageViewer = false  // 🆕 用于弹出全屏图片查看器

    init(capturedImage: UIImage,
         indicatorType: THThyroidPanelRecord.CheckupType,
         onConfirm: @escaping ([String: Double]) -> Void,
         onDateExtracted: @escaping (Date?) -> Void = { _ in }) {
        self.capturedImage = capturedImage
        self.indicatorType = indicatorType
        self.onConfirm = onConfirm
        self.onDateExtracted = onDateExtracted
        _ocrService = StateObject(wrappedValue: THThyroidPanelOCRService(indicatorKeys: indicatorType.indicators))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 🆕 可点击的图片展示
                    Button {
                        showingImageViewer = true
                    } label: {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // 识别状态
                    if ocrService.isProcessing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)

                            Text("正在识别检查报告...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }

                    // 错误信息
                    if let error = ocrService.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundColor(.orange)

                            Text("识别出错")
                                .font(.headline)

                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("重新识别") {
                                ocrService.processImage(capturedImage)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // 识别结果
                    if !ocrService.isProcessing && ocrService.errorMessage == nil {
                        THPanelOCRResultsSection(
                            extractedIndicators: ocrService.extractedIndicators,
                            manualAdjustments: $manualAdjustments
                        )
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                // 底部操作按钮
                if !ocrService.extractedIndicators.isEmpty {
                    VStack(spacing: 12) {
                        Divider()
                        HStack(spacing: 16) {
                            Button("查看原文") {
                                showingRawText = true
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("确认数据") {
                                confirmData()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(getFinalIndicators().isEmpty)
                        }
                        .padding()
                    }
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("识别结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showingRawText) {
                THPanelOCRRawTextView(text: ocrService.recognizedText)
            }
            .fullScreenCover(isPresented: $showingImageViewer) {
                THImageZoomViewer(image: capturedImage)
            }
            .onAppear {
                ocrService.processImage(capturedImage)
            }
            .onChange(of: ocrService.extractedDate) { _, newDate in
                onDateExtracted(newDate)
            }
            .onTapGesture {
                UIApplication.shared.dismissKeyboard()
            }
        }
    }

    private func getFinalIndicators() -> [String: Double] {
        var result = ocrService.extractedIndicators
        for (key, valueString) in manualAdjustments {
            if !valueString.isEmpty, let value = Double(valueString) {
                result[key] = value
            }
        }
        return result
    }

    private func confirmData() {
        onConfirm(getFinalIndicators())
        dismiss()
    }
}
