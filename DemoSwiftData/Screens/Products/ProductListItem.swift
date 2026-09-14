//
//  ProductListItem.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 14.09.2026.
//

import SwiftData

/// Неизменяемый снимок SwiftData-модели, подготовленный для отображения.
struct ProductListItem: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let measurementUnits: [MeasurementUnit]
    let defaultMeasurementUnit: MeasurementUnit?
    let shoppingListItemsCount: Int

    init(product: Product) {
        id = product.persistentModelID
        name = product.name
        measurementUnits = product.measurementUnits
            .map(\.unit)
            .sorted { $0.rawValue < $1.rawValue }
        defaultMeasurementUnit = product.defaultMeasurementUnit?.unit
        shoppingListItemsCount = product.listItems.count
    }
}
