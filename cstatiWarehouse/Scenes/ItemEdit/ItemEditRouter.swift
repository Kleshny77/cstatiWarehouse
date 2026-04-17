//
//  ItemEditRouter.swift
//  cstatiWarehouse
//
//  Created by Артём on 17.04.2026.
//

import Foundation

protocol ItemEditRouterProtocol: AnyObject {
    // Сейчас у сцены редактирования нет дальнейшей навигации — закрытие sheet
    // происходит через onFinish на уровне родителя. Роутер оставлен для
    // консистентности с архитектурой: сюда будут добавляться переходы
    // (например, к сканированию штрихкода или выбору категории).
}

final class ItemEditRouter: ItemEditRouterProtocol {
    
}
