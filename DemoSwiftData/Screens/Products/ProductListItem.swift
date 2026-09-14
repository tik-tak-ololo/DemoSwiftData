//
//  ProductListItem.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 14.09.2026.
//

import Foundation

/// Неизменяемый снимок товара, подготовленный для отображения.
struct ProductListItem: Identifiable {
    let id: UUID
    let name: String
    let measurementUnits: [MeasurementUnit]
    let defaultMeasurementUnit: MeasurementUnit?
    let shoppingListItemsCount: Int

    init(details: ProductDetails) {
        id = details.id
        name = details.name
        measurementUnits = details.measurementUnits
        defaultMeasurementUnit = details.defaultMeasurementUnit
        shoppingListItemsCount = details.shoppingListItemsCount
    }
}
