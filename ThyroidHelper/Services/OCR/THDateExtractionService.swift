//
//  THDateExtractionService.swift
//  ThyroidHelper
//
//  Created by gdliu on 2025/9/8.
//

import Foundation
import os.log

/// 通用日期提取服务，用于从OCR文本中识别日期
class THDateExtractionService {
    
    /// 日志记录器
    private static let logger = Logger(subsystem: "ThyroidHelper", category: "DateExtraction")
    
    /// 日期识别正则表达式模式
    /// 按优先级排序，越靠前的模式匹配优先级越高
    private static let datePatterns: [DatePattern] = [
        // 报告专用格式（优先级最高）
        DatePattern(
            name: "检查日期标签",
            pattern: "检查日期[：:\\s]*([0-9]{4})[\\-/年]([0-9]{1,2})[\\-/月]([0-9]{1,2})日?",
            format: .yearFirst
        ),
        DatePattern(
            name: "日期标签",
            pattern: "日期[：:\\s]*([0-9]{4})[年\\-/\\.\\s]+([0-9]{1,2})[月\\-/\\.\\s]+([0-9]{1,2})[日]?",
            format: .yearFirst
        ),
        
        // 标准中文格式
        DatePattern(
            name: "完整中文格式",
            pattern: "([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日",
            format: .yearFirst
        ),
        DatePattern(
            name: "简化中文格式",
            pattern: "([0-9]{4})[年\\-/\\.\\s]+([0-9]{1,2})[月\\-/\\.\\s]+([0-9]{1,2})[日]?",
            format: .yearFirst
        ),
        
        // 数字分隔符格式
        DatePattern(
            name: "点分隔格式",
            pattern: "([0-9]{4})\\.([0-9]{1,2})\\.([0-9]{1,2})",
            format: .yearFirst
        ),
        DatePattern(
            name: "横线分隔格式",
            pattern: "([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})",
            format: .yearFirst
        ),
        
        // 国外格式（优先级较低）
        DatePattern(
            name: "美式格式",
            pattern: "([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})",
            format: .monthFirst
        ),
        DatePattern(
            name: "欧式格式",
            pattern: "([0-9]{1,2})\\.([0-9]{1,2})\\.([0-9]{4})",
            format: .dayFirst
        )
    ]
    
    /// 日期格式类型
    private enum DateFormatType {
        case yearFirst   // YYYY-MM-DD
        case monthFirst  // MM/DD/YYYY
        case dayFirst    // DD.MM.YYYY
    }
    
    /// 日期模式结构
    private struct DatePattern {
        let name: String
        let pattern: String
        let format: DateFormatType
    }
    
    /// 从文本中提取日期
    /// - Parameter text: 待解析的文本
    /// - Returns: 提取到的日期，如果未找到返回nil
    static func extractDate(from text: String) -> Date? {
        logger.info("🔍 [DateExtraction] 开始提取日期")
        logger.debug("📄 待解析文本: \(text)")
        
        // 遍历所有日期模式进行匹配
        for (index, datePattern) in datePatterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: datePattern.pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    logger.info("📍 匹配到模式[\(index)] \(datePattern.name): \(datePattern.pattern)")
                    
                    // 确保有足够的捕获组
                    guard match.numberOfRanges >= 4 else {
                        logger.warning("⚠️ 捕获组数量不足: \(match.numberOfRanges)")
                        continue
                    }
                    
                    // 提取三个数字部分
                    guard let part1Range = Range(match.range(at: 1), in: text),
                          let part2Range = Range(match.range(at: 2), in: text),
                          let part3Range = Range(match.range(at: 3), in: text) else {
                        logger.warning("⚠️ 无法创建字符串范围")
                        continue
                    }
                    
                    let part1Str = String(text[part1Range])
                    let part2Str = String(text[part2Range])
                    let part3Str = String(text[part3Range])
                    
                    logger.debug("📅 提取到数字: \(part1Str)-\(part2Str)-\(part3Str)")
                    
                    // 转换为整数
                    guard let part1 = Int(part1Str),
                          let part2 = Int(part2Str),
                          let part3 = Int(part3Str) else {
                        logger.warning("⚠️ 数字转换失败")
                        continue
                    }
                    
                    // 根据模式类型确定年月日
                    let (year, month, day) = parseDateParts(
                        part1: part1,
                        part2: part2,
                        part3: part3,
                        format: datePattern.format
                    )
                    
                    logger.debug("📅 解析结果: 年=\(year), 月=\(month), 日=\(day)")
                    
                    // 构建并验证日期
                    if let date = createAndValidateDate(year: year, month: month, day: day) {
                        logger.info("✅ 成功提取日期: \(date.formatted(date: .abbreviated, time: .omitted)) (使用模式: \(datePattern.name))")
                        return date
                    }
                }
            } catch {
                logger.error("❌ 正则表达式错误[\(index)]: \(error.localizedDescription)")
            }
        }
        
        logger.warning("❌ 未找到有效日期")
        return nil
    }
    
    /// 根据格式类型解析日期部分
    private static func parseDateParts(part1: Int, part2: Int, part3: Int, format: DateFormatType) -> (year: Int, month: Int, day: Int) {
        switch format {
        case .yearFirst:
            return (year: part1, month: part2, day: part3)
        case .monthFirst:
            return (year: part3, month: part1, day: part2)
        case .dayFirst:
            return (year: part3, month: part2, day: part1)
        }
    }
    
    /// 创建并验证日期
    private static func createAndValidateDate(year: Int, month: Int, day: Int) -> Date? {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month, day: day)
        
        guard let date = calendar.date(from: dateComponents) else {
            logger.warning("⚠️ 无法创建日期: \(year)-\(month)-\(day)")
            return nil
        }
        
        // 日期合理性检查
        if isDateReasonable(date) {
            return date
        } else {
            logger.warning("⚠️ 日期不在合理范围内: \(date.formatted())")
            return nil
        }
    }
    
    /// 检查日期是否在合理范围内
    private static func isDateReasonable(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // 不能是未来日期（允许今天和明天，考虑时区差异）
        let twoDaysLater = calendar.date(byAdding: .day, value: 2, to: now)!
        if date >= twoDaysLater {
            return false
        }
        
        // 不能太久远（15年前，医疗记录可能更久远）
        let fifteenYearsAgo = calendar.date(byAdding: .year, value: -15, to: now)!
        if date < fifteenYearsAgo {
            return false
        }
        
        return true
    }
}
