//
//  ShoppingListItem.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

/// Связующая сущность для отношения many-to-many между списками и товарами.
/// Количество, единица измерения и статус покупки относятся к позиции списка.
@Model
final class ShoppingListItem {
    @Attribute(.unique) private(set) var id: UUID
    private(set) var quantity: Int
    private(set) var unit: MeasurementUnit
    private(set) var isPurchased: Bool
    private(set) var createdAt: Date
    private(set) var shoppingList: ShoppingList?
    private(set) var product: Product?

    init(
        id: UUID = UUID(),
        quantity: Int,
        unit: MeasurementUnit,
        isPurchased: Bool = false,
        createdAt: Date = .now,
        shoppingList: ShoppingList,
        product: Product
    ) throws {
        try ShoppingDomainValidation.unit(unit, isSupportedBy: product)

        self.id = id
        self.quantity = try ShoppingDomainValidation.quantity(quantity)
        self.unit = unit
        self.isPurchased = isPurchased
        self.createdAt = createdAt
        self.shoppingList = shoppingList
        self.product = product
    }

    func update(
        product: Product,
        unit: MeasurementUnit,
        quantity: Int
    ) throws {
        try ShoppingDomainValidation.unit(unit, isSupportedBy: product)
        let validatedQuantity = try ShoppingDomainValidation.quantity(quantity)

        self.product = product
        self.unit = unit
        self.quantity = validatedQuantity
    }

    func increaseQuantity(by amount: Int) throws {
        let validatedAmount = try ShoppingDomainValidation.quantity(amount)
        let result = quantity.addingReportingOverflow(validatedAmount)
        guard !result.overflow else {
            throw ShoppingDomainError.quantityOverflow
        }
        quantity = result.partialValue
    }

    func changeUnit(to unit: MeasurementUnit) throws {
        guard let product else { return }
        try ShoppingDomainValidation.unit(unit, isSupportedBy: product)
        self.unit = unit
    }

    func mergePurchaseStatus(with item: ShoppingListItem) {
        isPurchased = isPurchased && item.isPurchased
    }

    func togglePurchased() {
        isPurchased.toggle()
    }
}
