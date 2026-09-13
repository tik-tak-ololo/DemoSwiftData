//
//  ProductStore.swift
//  DemoSwiftData
//
//  Created by Codex on 13.09.2026.
//

import Foundation
import SwiftData

enum ProductStoreError: LocalizedError {
    case emptyProductName
    case duplicateProductName
    case emptyMeasurementUnits
    case unsupportedMeasurementUnit(productName: String, unit: MeasurementUnit)
    case measurementUnitInUse

    var errorDescription: String? {
        switch self {
        case .emptyProductName:
            "Введите название товара."
        case .duplicateProductName:
            "Товар с таким названием уже существует."
        case .emptyMeasurementUnits:
            "У товара должна быть хотя бы одна единица измерения."
        case let .unsupportedMeasurementUnit(productName, unit):
            "Для товара «\(productName)» нельзя использовать единицу «\(unit.rawValue)»."
        case .measurementUnitInUse:
            "Нельзя удалить единицу измерения, которая используется в списке покупок."
        }
    }
}

@MainActor
final class ProductStore: ProductStoreCoordinating {
    /// ModelContext не владеет временем жизни контейнера, поэтому store удерживает оба объекта.
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    func fetchProducts() throws -> [Product] {
        try modelContext.fetch(Self.productsDescriptor)
    }

    func fetchProductMeasurementUnits() throws -> [ProductMeasurementUnit] {
        try modelContext.fetch(FetchDescriptor<ProductMeasurementUnit>())
            .sorted {
                let firstProduct = $0.product.normalizedName
                let secondProduct = $1.product.normalizedName
                if firstProduct != secondProduct {
                    return firstProduct < secondProduct
                }
                return $0.unit.rawValue < $1.unit.rawValue
            }
    }

    func renameProduct(_ product: Product, to name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProductStoreError.emptyProductName
        }

        let normalizedName = Product.normalize(trimmedName)
        if normalizedName != product.normalizedName,
           try findProduct(normalizedName: normalizedName) != nil {
            throw ProductStoreError.duplicateProductName
        }

        product.rename(to: trimmedName)
        try saveChanges()
    }

    func setMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        for product: Product
    ) throws {
        guard !units.isEmpty else {
            throw ProductStoreError.emptyMeasurementUnits
        }

        let usedUnits = Set(product.listItems.map(\.unit))
        guard usedUnits.isSubset(of: units) else {
            throw ProductStoreError.measurementUnitInUse
        }

        for measurementUnit in product.measurementUnits where !units.contains(measurementUnit.unit) {
            modelContext.delete(measurementUnit)
        }

        for unit in units where !product.supports(unit) {
            if let measurementUnit = product.addMeasurementUnit(unit) {
                modelContext.insert(measurementUnit)
            }
        }

        try saveChanges()
    }

    func findOrCreateProduct(
        named name: String,
        initialMeasurementUnits: Set<MeasurementUnit>
    ) throws -> Product {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProductStoreError.emptyProductName
        }

        let normalizedName = Product.normalize(trimmedName)
        if let existingProduct = try findProduct(normalizedName: normalizedName) {
            return existingProduct
        }

        return try insertProduct(
            named: trimmedName,
            measurementUnits: initialMeasurementUnits
        )
    }

    func insertProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws -> Product {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProductStoreError.emptyProductName
        }
        guard !measurementUnits.isEmpty else {
            throw ProductStoreError.emptyMeasurementUnits
        }

        let product = Product(
            name: trimmedName,
            measurementUnits: Array(measurementUnits)
        )
        modelContext.insert(product)
        return product
    }

    func validate(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws {
        guard product.supports(unit) else {
            throw ProductStoreError.unsupportedMeasurementUnit(
                productName: product.name,
                unit: unit
            )
        }
    }

    func deleteAllProducts() throws {
        try modelContext.fetch(FetchDescriptor<ProductMeasurementUnit>())
            .forEach(modelContext.delete)
        try modelContext.fetch(Self.productsDescriptor)
            .forEach(modelContext.delete)
    }

    private static var productsDescriptor: FetchDescriptor<Product> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\Product.normalizedName)]
        )
    }

    private func findProduct(normalizedName: String) throws -> Product? {
        let predicate = #Predicate<Product> { product in
            product.normalizedName == normalizedName
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func saveChanges() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
