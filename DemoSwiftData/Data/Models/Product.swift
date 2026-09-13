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
    /// Отображаемое название товара.
    private(set) var name: String
    /// Нормализованное название для поиска и проверки уникальности.
    @Attribute(.unique, originalName: "normalized_name")
    private(set) var normalizedName: String
    /// Позиции списков, в которых используется товар.
    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.product)
    private(set) var listItems: [ShoppingListItem]
    /// Допустимые для товара единицы измерения.
    @Relationship(deleteRule: .cascade, inverse: \ProductMeasurementUnit.product)
    private(set) var measurementUnits: [ProductMeasurementUnit]

    init(name: String, measurementUnits: [MeasurementUnit]) throws {
        let validatedName = try ShoppingDomainValidation.productName(name)
        let validatedUnits = try ShoppingDomainValidation.measurementUnits(Set(measurementUnits))

        self.name = validatedName
        normalizedName = Self.normalize(validatedName)
        listItems = []
        self.measurementUnits = []

        Array(validatedUnits)
            .sorted { $0.rawValue < $1.rawValue }
            .forEach { addMeasurementUnit($0) }
    }

    static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    func rename(to name: String) throws {
        let validatedName = try ShoppingDomainValidation.productName(name)
        self.name = validatedName
        normalizedName = Self.normalize(validatedName)
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
