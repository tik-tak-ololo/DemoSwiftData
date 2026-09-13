//
//  ShoppingListItem.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

/// Основные единицы измерения, используемые для покупок в России.
enum MeasurementUnit: String, CaseIterable, Codable {
    case piece = "штуки"
    case kilogram = "килограммы"
    case gram = "граммы"
    case liter = "литры"
    case milliliter = "миллилитры"
    case meter = "метры"
    case centimeter = "сантиметры"
    case squareMeter = "квадратные метры"
    case cubicMeter = "кубические метры"
    case package = "упаковки"
}

/// Связующая сущность для отношения many-to-many между списками и товарами.
/// Количество, единица измерения и статус покупки относятся к позиции списка.
@Model
final class ShoppingListItem {
    @Attribute(.unique) var id: UUID
    var quantity: Int
    var unit: MeasurementUnit
    var isPurchased: Bool
    var createdAt: Date
    var shoppingList: ShoppingList?
    var product: Product?

    init(
        id: UUID = UUID(),
        quantity: Int,
        unit: MeasurementUnit,
        isPurchased: Bool = false,
        createdAt: Date = .now,
        shoppingList: ShoppingList,
        product: Product
    ) {
        self.id = id
        self.quantity = quantity
        self.unit = unit
        self.isPurchased = isPurchased
        self.createdAt = createdAt
        self.shoppingList = shoppingList
        self.product = product
    }
}
