//
//  RussianQuantityStrings.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation

enum RussianQuantityStrings {

    static func packagingPhrase(count: Int) -> String {
        "\(count) \(packagingForm(for: count))"
    }

    static func packagingForm(for count: Int) -> String {
        let n = abs(count)
        let mod100 = n % 100
        if (11...14).contains(mod100) {
            return "упаковок"
        }
        switch n % 10 {
        case 1: return "упаковка"
        case 2, 3, 4: return "упаковки"
        default: return "упаковок"
        }
    }
}
