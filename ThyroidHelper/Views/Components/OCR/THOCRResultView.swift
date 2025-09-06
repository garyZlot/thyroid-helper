//
//  THOCRResultView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/8/26.
//

import SwiftUI

struct THOCRResultView: View {
    @StateObject private var ocrService: THThyroidPanelOCRService
    let capturedImage: UIImage
    let indicatorType: THThyroidPanelRecord.CheckupType
    let onConfirm: ([String: Double]) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var manualAdjustments: [String: String] = [:]
    @State private var showingRawText = false
    
    init(capturedImage: UIImage,
         indicatorType: THThyroidPanelRecord.CheckupType,
         onConfirm: @escaping ([String: Double]) -> Void) {
        self.capturedImage = capturedImage
        self.indicatorType = indicatorType
        self.onConfirm = onConfirm
        _ocrService = StateObject(wrappedValue: THThyroidPanelOCRService(indicatorKeys: indicatorType.indicators))
    }

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 拍摄的图片预览
                ScrollView {
                    VStack(spacing: 20) {
                        // 图片展示
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
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
                            THOCRResultsSection(
                                extractedIndicators: ocrService.extractedIndicators,
                                manualAdjustments: $manualAdjustments
                            )
                        }
                    }
                    .padding()
                }
                
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
                THOCRRawTextView(text: ocrService.recognizedText)
            }
        }
        .onAppear {
            ocrService.processImage(capturedImage)
        }
    }
    
    private func getFinalIndicators() -> [String: Double] {
        var result = ocrService.extractedIndicators
        
        // 应用手动调整
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
