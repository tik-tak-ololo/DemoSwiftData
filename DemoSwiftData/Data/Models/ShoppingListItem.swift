//
//  ShoppingListItem.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

/// Связующая сущность для отношения many-to-many между списками и товарами.
/// Количество и статус покупки относятся именно к позиции конкретного списка.
@Model
final class ShoppingListItem {
    @Attribute(.unique) var id: UUID
    var quantity: Int
    var isPurchased: Bool
    var createdAt: Date
    var shoppingList: ShoppingList?
    var product: Product?

    init(
        id: UUID = UUID(),
        quantity: Int,
        isPurchased: Bool = false,
        createdAt: Date = .now,
        shoppingList: ShoppingList,
        product: Product
    ) {
        self.id = id
        self.quantity = quantity
        self.isPurchased = isPurchased
        self.createdAt = createdAt
        self.shoppingList = shoppingList
        self.product = product
    }
}
