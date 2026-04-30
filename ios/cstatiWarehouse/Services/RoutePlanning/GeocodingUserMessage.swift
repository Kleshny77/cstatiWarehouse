//
//  GeocodingUserMessage.swift
//  cstatiWarehouse
//
//  Created by Артём on 26.04.2026.
//

import CoreLocation
import Foundation

enum GeocodingUserMessage {

    static func message(for error: AddressGeocoderError) -> String {
        switch error {
        case .emptyQuery:
            return "Введите адрес."
        case .notFound:
            return "Такой адрес на карте не найден. Укажите город, улицу и дом."
        case .underlying(let error):
            return message(forUnderlying: error)
        }
    }

    static func message(forUnderlying error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == kCLErrorDomain else {
            return "Не удалось найти адрес на карте. Уточните формулировку или попробуйте позже."
        }
        switch CLError.Code(rawValue: ns.code) {
        case .some(.geocodeFoundNoResult):
            return "Такой адрес на карте не найден. Укажите город, улицу и дом."
        case .some(.network):
            return "Нет сети или сервис адресов временно недоступен. Проверьте подключение и попробуйте снова."
        case .some(.denied):
            return "Доступ к службам геолокации ограничен. Разрешите доступ в настройках — без этого адрес не проверить."
        case .some(.geocodeCanceled):
            return "Проверка адреса прервана. Попробуйте ещё раз."
        case .some(.locationUnknown):
            return "Не удалось определить местоположение. Попробуйте чуть позже."
        default:
            return "Не удалось найти адрес на карте. Уточните формулировку или попробуйте позже."
        }
    }
}
