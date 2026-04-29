//
// Date+Formatters.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import Foundation

extension Date {
    /// Централизованные статические форматтеры для переиспользования
    /// Создание DateFormatter - дорогая операция, поэтому используем статические экземпляры
    enum Formatters {
        /// Русская локаль для всех форматтеров
        private static let russianLocale = Locale(identifier: "ru_RU")
        
        /// ISO8601 с дробными секундами для API
        static let iso8601Fractional: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        
        /// ISO8601 базовый для API
        static let iso8601Basic: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
        
        /// Дата и время для отображения пользователю (ru_RU)
        static let dateTime: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .year()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        }()
        
        /// Только дата для отображения (ru_RU)
        static let dateOnly: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .year()
                .month(.abbreviated)
                .day()
        }()
        
        /// Дата истечения срока годности (ru_RU)
        static let expiry: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .day()
                .month(.abbreviated)
                .year()
        }()
        
        /// Короткий формат даты и времени для списков (ru_RU)
        static let shortDateTime: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .day()
                .month(.numeric)
                .hour()
                .minute()
        }()
    }
}

// MARK: - Convenience Methods

extension Date {
    /// Форматирует дату для отображения пользователю
    func formattedDateTime() -> String {
        self.formatted(Formatters.dateTime)
    }
    
    /// Форматирует только дату
    func formattedDate() -> String {
        self.formatted(Formatters.dateOnly)
    }
    
    /// Форматирует дату истечения
    func formattedExpiry() -> String {
        self.formatted(Formatters.expiry)
    }
    
    /// Короткий формат для списков
    func formattedShort() -> String {
        self.formatted(Formatters.shortDateTime)
    }
}
