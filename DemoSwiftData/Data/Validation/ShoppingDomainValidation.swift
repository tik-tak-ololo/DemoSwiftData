//
//  ShoppingDomainValidation.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 13.09.2026.
//

import Foundation

enum ShoppingDomainError: LocalizedError {
    case emptyListName
    case emptyProductName
    case invalidQuantity
    case quantityOverflow
    case emptyMeasurementUnits
    case unsupportedMeasurementUnit(productName: String, unit: MeasurementUnit)

    var errorDescription: String? {
        switch self {
        case .emptyListName:
            "Введите название списка."
        case .emptyProductName:
            "Введите название товара."
        case .invalidQuantity:
            "Количество должно быть больше нуля."
        case .quantityOverflow:
            "Указано слишком большое количество товара."
        case .emptyMeasurementUnits:
            "У товара должна быть хотя бы одна единица измерения."
        case let .unsupportedMeasurementUnit(productName, unit):
            "Для товара «\(productName)» нельзя использовать единицу «\(unit.rawValue)»."
        }
    }
}

enum ShoppingDomainValidation {
    nonisolated static func listName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw ShoppingDomainError.emptyListName
        }
        return value
    }

    nonisolated static func productName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw ShoppingDomainError.emptyProductName
        }
        return value
    }

    nonisolated static func quantity(_ quantity: Int) throws -> Int {
        guard quantity > 0 else {
            throw ShoppingDomainError.invalidQuantity
        }
        return quantity
    }

    nonisolated static func measurementUnits(
        _ measurementUnits: Set<MeasurementUnit>
    ) throws -> Set<MeasurementUnit> {
        guard !measurementUnits.isEmpty else {
            throw ShoppingDomainError.emptyMeasurementUnits
        }
        return measurementUnits
    }

    nonisolated static func unit(
        _ unit: MeasurementUnit,
        isSupportedBy product: Product
    ) throws {
        guard product.supports(unit) else {
            throw ShoppingDomainError.unsupportedMeasurementUnit(
                productName: product.name,
                unit: unit
            )
        }
    }
}
