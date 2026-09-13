//
//  Product.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

@Model
final class Product {
    private(set) var name: String
    @Attribute(.unique) private(set) var normalizedName: String
    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.product)
    var listItems: [ShoppingListItem]
    @Relationship(deleteRule: .cascade, inverse: \ProductMeasurementUnit.product)
    private(set) var measurementUnits: [ProductMeasurementUnit]

    init(name: String, measurementUnits: [MeasurementUnit]) {
        precondition(!measurementUnits.isEmpty, "У товара должна быть хотя бы одна единица измерения.")

        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedName = Self.normalize(name)
        listItems = []
        self.measurementUnits = []

        Array(Set(measurementUnits))
            .sorted { $0.rawValue < $1.rawValue }
            .forEach { addMeasurementUnit($0) }
    }

    static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    func rename(to name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedName = Self.normalize(name)
    }

    func supports(_ unit: MeasurementUnit) -> Bool {
        measurementUnits.contains { $0.unit == unit }
    }

    @discardableResult
    func addMeasurementUnit(_ unit: MeasurementUnit) -> ProductMeasurementUnit? {
        guard !supports(unit) else { return nil }

        let measurementUnit = ProductMeasurementUnit(unit: unit, product: self)
        if !measurementUnits.contains(where: { $0 === measurementUnit }) {
            measurementUnits.append(measurementUnit)
        }
        return measurementUnit
    }
}
