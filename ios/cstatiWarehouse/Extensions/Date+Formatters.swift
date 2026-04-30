//
// Date+Formatters.swift
// cstatiWarehouse
//
// Created by Артём on 29.04.2026.
//

import Foundation

extension Date {
    enum Formatters {
        private static let russianLocale = Locale(identifier: "ru_RU")
        
        static let iso8601Fractional: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        
        static let iso8601Basic: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
        
        static let dateTime: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .year()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        }()
        
        static let dateOnly: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .year()
                .month(.abbreviated)
                .day()
        }()
        
        static let expiry: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .day()
                .month(.abbreviated)
                .year()
        }()
        
        static let shortDateTime: Date.FormatStyle = {
            Date.FormatStyle()
                .locale(russianLocale)
                .day()
                .month(.twoDigits)
                .hour()
                .minute()
        }()
    }
}

// MARK: - Convenience Methods

extension Date {
    func formattedDateTime() -> String {
        self.formatted(Formatters.dateTime)
    }
    
    func formattedDate() -> String {
        self.formatted(Formatters.dateOnly)
    }
    
    func formattedExpiry() -> String {
        self.formatted(Formatters.expiry)
    }
    
    func formattedShort() -> String {
        self.formatted(Formatters.shortDateTime)
    }
}
