//
//  DateUtils.swift
//  ThyroidHelper
//
//  Created by Assistant on 2025/9/16.
//

import Foundation

// MARK: - Date 扩展
extension Date {
    
    /// 格式化为本地化日期字符串
    /// - Parameter style: 日期样式
    /// - Returns: 格式化后的本地化日期字符串
    func toLocalizedString(style: DateFormatter.Style = .medium) -> String {
        return DateUtils.localizedFormatter(style: style).string(from: self)
    }
    
    /// 格式化为自定义格式的本地化日期字符串
    /// - Parameter format: 自定义日期格式
    /// - Returns: 格式化后的日期字符串
    func toLocalizedString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = DateUtils.currentLocale
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    /// 简短的本地化日期格式
    /// - 中文: 9月16日
    /// - 英文: Sep 16
    /// - 其他语言: 根据系统自动适配
    var localizedShort: String {
        let template = "MMMMd"
        return toLocalizedString(template: template)
    }
    
    /// 标准本地化日期格式
    /// - 中文: 2024年9月16日
    /// - 英文: September 16, 2024
    /// - 其他语言: 根据系统自动适配
    var localizedMedium: String {
        return toLocalizedString(style: .medium)
    }
    
    /// 完整本地化日期格式
    /// - 中文: 2024年9月16日 星期一
    /// - 英文: Monday, September 16, 2024
    /// - 其他语言: 根据系统自动适配
    var localizedFull: String {
        return toLocalizedString(style: .full)
    }
    
    /// 带星期的简短格式
    /// - 中文: 9月16日 周一
    /// - 英文: Sep 16 Mon
    /// - 其他语言: 根据系统自动适配
    var localizedWithWeekday: String {
        let template = "MMMMdE"
        return toLocalizedString(template: template)
    }
    
    /// 年月格式
    /// - 中文: 2024年9月
    /// - 英文: September 2024
    /// - 其他语言: 根据系统自动适配
    var localizedYearMonth: String {
        let template = "yyyyMMMM"
        return toLocalizedString(template: template)
    }
    
    /// 使用模板格式化日期（推荐用法，会根据locale自动调整格式）
    /// - Parameter template: 日期模板 (如: "yyyyMMMMd", "MMMMdE")
    /// - Returns: 本地化的日期字符串
    func toLocalizedString(template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = DateUtils.currentLocale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: self)
    }
    
    /// 获取当天的开始时间 (00:00:00)
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// 获取当天的结束时间 (23:59:59)
    var endOfDay: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }
    
    /// 判断是否为今天
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// 判断是否为本周
    var isThisWeek: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 判断是否为本月
    var isThisMonth: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// 判断是否为本年
    var isThisYear: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    /// 相对时间描述（本地化）
    /// - 中文: 今天, 昨天, 3天前
    /// - 英文: Today, Yesterday, 3 days ago
    /// - 其他语言: 根据系统自动适配
    var relativeDescription: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            return NSLocalizedString("date.today", value: "Today", comment: "今天")
        } else if calendar.isDateInYesterday(self) {
            return NSLocalizedString("date.yesterday", value: "Yesterday", comment: "昨天")
        } else if calendar.isDateInTomorrow(self) {
            return NSLocalizedString("date.tomorrow", value: "Tomorrow", comment: "明天")
        } else {
            let days = calendar.dateComponents([.day], from: self, to: now).day ?? 0
            if days > 0 {
                let format = NSLocalizedString("date.days_ago", value: "%d days ago", comment: "%d天前")
                return String.localizedStringWithFormat(format, days)
            } else {
                let format = NSLocalizedString("date.days_later", value: "%d days later", comment: "%d天后")
                return String.localizedStringWithFormat(format, abs(days))
            }
        }
    }
}

// MARK: - 日期工具类
struct DateUtils {
    
    /// 当前使用的Locale，优先使用应用设置，其次使用系统设置
    static var currentLocale: Locale {
        // 这里可以扩展为从UserDefaults或应用设置中读取用户选择的语言
        // 暂时使用系统当前设置
        return Locale.current
    }
    
    /// 支持的语言列表（将来可以扩展）
    static let supportedLocales: [String: Locale] = [
        "zh_CN": Locale(identifier: "zh_CN"),
        "zh_TW": Locale(identifier: "zh_TW"),
        "en_US": Locale(identifier: "en_US"),
        "ja_JP": Locale(identifier: "ja_JP"),
        "ko_KR": Locale(identifier: "ko_KR")
    ]
    
    /// 设置应用语言（将来可以让用户手动选择语言）
    /// - Parameter localeIdentifier: 语言标识符，如 "zh_CN", "en_US"
    static func setAppLocale(_ localeIdentifier: String) {
        UserDefaults.standard.set(localeIdentifier, forKey: "AppLocale")
        // 这里可以添加通知，让其他视图重新刷新
        NotificationCenter.default.post(name: .localeDidChange, object: nil)
    }
    
    /// 获取应用设置的语言，如果没有设置则使用系统语言
    static var appLocale: Locale {
        if let localeIdentifier = UserDefaults.standard.string(forKey: "AppLocale"),
           let locale = supportedLocales[localeIdentifier] {
            return locale
        }
        return Locale.current
    }
    
    /// 获取本地化日期格式化器
    /// - Parameter style: 日期样式
    /// - Returns: 配置好的DateFormatter
    static func localizedFormatter(style: DateFormatter.Style = .medium) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter
    }
    
    /// 获取自定义格式的本地化日期格式化器
    /// - Parameter format: 日期格式字符串
    /// - Returns: 配置好的DateFormatter
    static func localizedFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateFormat = format
        return formatter
    }
    
    /// 获取使用模板的本地化日期格式化器（推荐）
    /// - Parameter template: 日期模板
    /// - Returns: 配置好的DateFormatter
    static func localizedFormatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
    
    /// 预定义的格式化器缓存，避免重复创建
    private static var formatterCache: [String: DateFormatter] = [:]
    private static let cacheQueue = DispatchQueue(label: "DateUtils.formatterCache", attributes: .concurrent)
    
    /// 获取缓存的格式化器（线程安全）
    /// - Parameter key: 缓存键
    /// - Returns: DateFormatter实例
    static func cachedFormatter(for key: String, factory: () -> DateFormatter) -> DateFormatter {
        return cacheQueue.sync {
            if let cachedFormatter = formatterCache[key] {
                return cachedFormatter
            }
            let formatter = factory()
            cacheQueue.async(flags: .barrier) {
                formatterCache[key] = formatter
            }
            return formatter
        }
    }
    
    /// 清除格式化器缓存（语言切换时调用）
    static func clearFormatterCache() {
        cacheQueue.async(flags: .barrier) {
            formatterCache.removeAll()
        }
    }
    
    /// 判断两个日期是否为同一天
    /// - Parameters:
    ///   - date1: 第一个日期
    ///   - date2: 第二个日期
    /// - Returns: 是否为同一天
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    /// 获取日期范围内的所有日期
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 日期数组
    static func dateRange(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = startDate.startOfDay
        let calendar = Calendar.current
        
        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return dates
    }
    
    /// 获取本周的日期范围
    /// - Parameter date: 参考日期，默认为今天
    /// - Returns: (weekStart, weekEnd)
    static func weekRange(for date: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
        return (startOfWeek.startOfDay, endOfWeek.endOfDay)
    }
    
    /// 获取本月的日期范围
    /// - Parameter date: 参考日期，默认为今天
    /// - Returns: (monthStart, monthEnd)
    static func monthRange(for date: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end.addingTimeInterval(-1) ?? date
        return (startOfMonth.startOfDay, endOfMonth.endOfDay)
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let localeDidChange = Notification.Name("LocaleDidChange")
}

// MARK: - 使用示例和最佳实践
/*
// 基本使用（推荐）- 会自动根据系统语言显示
let date = Date()
print(date.localizedMedium)        // 中文: 2024年9月16日, 英文: Sep 16, 2024
print(date.localizedShort)         // 中文: 9月16日, 英文: Sep 16
print(date.localizedFull)          // 中文: 2024年9月16日 星期一, 英文: Monday, September 16, 2024
print(date.localizedWithWeekday)   // 中文: 9月16日 周一, 英文: Sep 16 Mon
print(date.relativeDescription)    // 中文: 今天, 英文: Today

// 使用模板（推荐，会根据locale自动调整格式顺序）
print(date.toLocalizedString(template: "yyyyMMMMd"))  // 自动适配格式
print(date.toLocalizedString(template: "MMMMdE"))     // 自动适配格式

// 自定义格式（不推荐，格式固定）
print(date.toLocalizedString(format: "yyyy-MM-dd"))  // 2024-09-16（所有语言都一样）

// 设置应用语言（用户手动选择）
DateUtils.setAppLocale("zh_CN")  // 设置为中文
DateUtils.setAppLocale("en_US")  // 设置为英文

// 在语言设置变化后清除缓存
NotificationCenter.default.addObserver(forName: .localeDidChange, object: nil, queue: .main) { _ in
    DateUtils.clearFormatterCache()
    // 重新刷新UI
}
*/

// MARK: - 本地化字符串文件示例
/*
需要在Localizable.strings文件中添加以下内容：

// Localizable.strings (Base/English)
"date.today" = "Today";
"date.yesterday" = "Yesterday";
"date.tomorrow" = "Tomorrow";
"date.days_ago" = "%d days ago";
"date.days_later" = "%d days later";

// Localizable.strings (Chinese)
"date.today" = "今天";
"date.yesterday" = "昨天";
"date.tomorrow" = "明天";
"date.days_ago" = "%d天前";
"date.days_later" = "%d天后";

// Localizable.strings (Japanese)
"date.today" = "今日";
"date.yesterday" = "昨日";
"date.tomorrow" = "明日";
"date.days_ago" = "%d日前";
"date.days_later" = "%d日後";
*/
