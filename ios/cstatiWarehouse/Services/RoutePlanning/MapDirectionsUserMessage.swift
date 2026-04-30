//
//  MapDirectionsUserMessage.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import Foundation
import MapKit

enum MapDirectionsUserMessage {

    static func friendlyDirectionsFailure(from error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == MKError.errorDomain else {
            return "Не удалось построить маршрут по дорогам. Проверьте адреса и тип транспорта."
        }
        switch ns.code {
        case 5:
            return "Маршрут по дорогам между точками не найден (нет пути для выбранного транспорта или точки слишком далеко). На карте можно показать прямую между точками — проверьте адреса."
        case 4:
            return "Не удалось найти точку на карте для одного из адресов."
        case 3:
            return "Сервис маршрутов временно ограничил запросы. Попробуйте позже."
        default:
            return "Не удалось построить маршрут по дорогам (\(ns.code)). Уточните адреса."
        }
    }
}
