//
//  ProductStore.swift
//  DemoSwiftData
//
//  Created by Codex on 13.09.2026.
//

import Foundation
import SwiftData

enum ProductStoreError: LocalizedError {
    case duplicateProductName
    case duplicateMeasurementUnit
    case lastMeasurementUnit
    case measurementUnitInUse
    case measurementUnitWithoutProduct

    var errorDescription: String? {
        switch self {
        case .duplicateProductName:
            "Товар с таким названием уже существует."
        case .duplicateMeasurementUnit:
            "Такая единица измерения уже добавлена товару."
        case .lastMeasurementUnit:
            "У товара должна остаться хотя бы одна единица измерения."
        case .measurementUnitInUse:
            "Нельзя удалить единицу измерения, которая используется в списке покупок."
        case .measurementUnitWithoutProduct:
            "У единицы измерения отсутствует связанный товар."
        }
    }
}

@MainActor
final class ProductStore: ProductStoreCoordinating {
    /// ModelContext не владеет временем жизни контейнера, поэтому store удерживает оба объекта.
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    func replaceModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchProducts() throws -> [Product] {
        try modelContext.fetch(Self.productsDescriptor)
    }

    func fetchProductMeasurementUnits() throws -> [ProductMeasurementUnit] {
        try modelContext.fetch(FetchDescriptor<ProductMeasurementUnit>())
            .sorted {
                let firstProduct = $0.product?.normalizedName ?? ""
                let secondProduct = $1.product?.normalizedName ?? ""
                if firstProduct != secondProduct {
                    return firstProduct < secondProduct
                }
                return $0.unit.rawValue < $1.unit.rawValue
            }
    }

    @discardableResult
    func createProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws -> Product {
        let trimmedName = try ShoppingDomainValidation.productName(name)
        _ = try ShoppingDomainValidation.measurementUnits(measurementUnits)
        guard try findProduct(normalizedName: Product.normalize(trimmedName)) == nil else {
            throw ProductStoreError.duplicateProductName
        }

        let product = try insertProduct(
            named: trimmedName,
            measurementUnits: measurementUnits
        )
        try saveChanges()
        return product
    }

    func updateProduct(
        _ product: Product,
        name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws {
        let trimmedName = try ShoppingDomainValidation.productName(name)
        _ = try ShoppingDomainValidation.measurementUnits(measurementUnits)

        let normalizedName = Product.normalize(trimmedName)
        if normalizedName != product.normalizedName,
           try findProduct(normalizedName: normalizedName) != nil {
            throw ProductStoreError.duplicateProductName
        }

        let usedUnits = Set(product.listItems.map(\.unit))
        guard usedUnits.isSubset(of: measurementUnits) else {
            throw ProductStoreError.measurementUnitInUse
        }

        try product.rename(to: trimmedName)
        applyMeasurementUnits(measurementUnits, to: product)
        try saveChanges()
    }

    func deleteProduct(_ product: Product) throws {
        modelContext.delete(product)
        try saveChanges()
    }

    @discardableResult
    func createMeasurementUnit(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws -> ProductMeasurementUnit {
        guard !product.supports(unit) else {
            throw ProductStoreError.duplicateMeasurementUnit
        }
        guard let measurementUnit = product.addMeasurementUnit(unit) else {
            throw ProductStoreError.duplicateMeasurementUnit
        }

        modelContext.insert(measurementUnit)
        try saveChanges()
        return measurementUnit
    }

    func updateMeasurementUnit(
        _ measurementUnit: ProductMeasurementUnit,
        to unit: MeasurementUnit
    ) throws {
        guard measurementUnit.unit != unit else { return }

        guard let product = measurementUnit.product else {
            throw ProductStoreError.measurementUnitWithoutProduct
        }
        guard !product.supports(unit) else {
            throw ProductStoreError.duplicateMeasurementUnit
        }

        let previousUnit = measurementUnit.unit
        measurementUnit.changeUnit(to: unit)
        for item in product.listItems where item.unit == previousUnit {
            try item.changeUnit(to: unit)
        }
        try saveChanges()
    }

    func deleteMeasurementUnit(_ measurementUnit: ProductMeasurementUnit) throws {
        guard let product = measurementUnit.product else {
            throw ProductStoreError.measurementUnitWithoutProduct
        }
        guard product.measurementUnits.count > 1 else {
            throw ProductStoreError.lastMeasurementUnit
        }
        guard !product.listItems.contains(where: { $0.unit == measurementUnit.unit }) else {
            throw ProductStoreError.measurementUnitInUse
        }

        modelContext.delete(measurementUnit)
        try saveChanges()
    }

    func renameProduct(_ product: Product, to name: String) throws {
        let trimmedName = try ShoppingDomainValidation.productName(name)

        let normalizedName = Product.normalize(trimmedName)
        if normalizedName != product.normalizedName,
           try findProduct(normalizedName: normalizedName) != nil {
            throw ProductStoreError.duplicateProductName
        }

        try product.rename(to: trimmedName)
        try saveChanges()
    }

    func setMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        for product: Product
    ) throws {
        _ = try ShoppingDomainValidation.measurementUnits(units)

        let usedUnits = Set(product.listItems.map(\.unit))
        guard usedUnits.isSubset(of: units) else {
            throw ProductStoreError.measurementUnitInUse
        }

        applyMeasurementUnits(units, to: product)
        try saveChanges()
    }

    func findOrCreateProduct(
        named name: String,
        initialMeasurementUnits: Set<MeasurementUnit>
    ) throws -> Product {
        let trimmedName = try ShoppingDomainValidation.productName(name)

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
        let trimmedName = try ShoppingDomainValidation.productName(name)
        let validatedUnits = try ShoppingDomainValidation.measurementUnits(measurementUnits)

        let product = try Product(
            name: trimmedName,
            measurementUnits: Array(validatedUnits)
        )
        modelContext.insert(product)
        return product
    }

    func addMissingMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        to product: Product
    ) throws {
        let validatedUnits = try ShoppingDomainValidation.measurementUnits(units)
        for unit in validatedUnits where !product.supports(unit) {
            if let measurementUnit = product.addMeasurementUnit(unit) {
                modelContext.insert(measurementUnit)
            }
        }
    }

    func validate(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws {
        try ShoppingDomainValidation.unit(unit, isSupportedBy: product)
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

    private func applyMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        to product: Product
    ) {
        for measurementUnit in product.measurementUnits where !units.contains(measurementUnit.unit) {
            modelContext.delete(measurementUnit)
        }

        for unit in units where !product.supports(unit) {
            if let measurementUnit = product.addMeasurementUnit(unit) {
                modelContext.insert(measurementUnit)
            }
        }
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
