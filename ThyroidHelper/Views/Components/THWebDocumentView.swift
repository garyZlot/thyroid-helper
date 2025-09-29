//
//  THWebDocumentView.swift
//  ThyroidHelper
//
//  Created by gdlium2p on 2025/9/29.
//

import SwiftUI
import WebKit

struct THWebDocumentView: View {
    let documentType: DocumentType
    @Environment(\.locale) private var locale
    
    enum DocumentType {
        case privacyPolicy
        case termsOfService
        
        var title: String {
            switch self {
            case .privacyPolicy:
                return "privacy_policy".localized
            case .termsOfService:
                return "terms_of_service".localized
            }
        }
        
        var fileName: String {
            switch self {
            case .privacyPolicy:
                return "privacy_policy"
            case .termsOfService:
                return "terms_of_service"
            }
        }
    }
    
    var body: some View {
        WebView(htmlFileName: documentType.fileName, locale: locale)
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WebView Component
struct WebView: UIViewRepresentable {
    let htmlFileName: String
    let locale: Locale
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        loadHTML(into: webView)
    }
    
    private func loadHTML(into webView: WKWebView) {
        // 判断语言
        let language = locale.language.languageCode?.identifier ?? "en"
        let isChineseUser = language.hasPrefix("zh")
        
        // 获取 HTML 文件名
        let fileName = isChineseUser ? "\(htmlFileName)_zh" : "\(htmlFileName)_en"
        
        // 尝试从 Bundle 加载
        if let htmlPath = Bundle.main.path(forResource: fileName, ofType: "html"),
           let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
        } else {
            // 如果文件不存在，显示默认内容
            let fallbackHTML = generateFallbackHTML(isChineseUser: isChineseUser)
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }
    }
    
    private func generateFallbackHTML(isChineseUser: Bool) -> String {
        let title = isChineseUser ? "文档加载中..." : "Loading..."
        let message = isChineseUser ? "正在加载文档内容" : "Loading document content"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro", sans-serif;
                    padding: 20px;
                    text-align: center;
                    color: #666;
                }
            </style>
        </head>
        <body>
            <h2>\(title)</h2>
            <p>\(message)</p>
        </body>
        </html>
        """
    }
}

#Preview {
    NavigationView {
        THWebDocumentView(documentType: .privacyPolicy)
    }
}
