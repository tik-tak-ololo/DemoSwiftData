//
//  ProductStore.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 13.09.2026.
//

import Foundation
import SwiftData

enum ProductStoreError: LocalizedError {
    case duplicateProductName
    case duplicateMeasurementUnit
    case lastMeasurementUnit
    case measurementUnitInUse
    case productNotFound

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
        case .productNotFound:
            "Товар больше не существует. Обновите список."
        }
    }
}

@MainActor
final class ProductStore: ProductStoreCoordinating {
    /// ModelContext не владеет временем жизни контейнера, поэтому store удерживает оба объекта.
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext
    /// UI получает обычный UUID, а соответствие с PersistentIdentifier
    /// остаётся деталью реализации store.
    private var catalogIDByPersistentID: [PersistentIdentifier: UUID] = [:]
    private var persistentIDByCatalogID: [UUID: PersistentIdentifier] = [:]

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    func replaceModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        catalogIDByPersistentID.removeAll()
        persistentIDByCatalogID.removeAll()
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
}

// MARK: - Product catalog boundary

extension ProductStore {
    func fetchProductCatalog() throws -> [ProductDetails] {
        let products = try fetchProducts()
        removeCatalogIDsForDeletedProducts(products)

        return products.map { product in
            ProductDetails(
                id: catalogID(for: product),
                name: product.name,
                measurementUnits: product.measurementUnits
                    .map(\.unit)
                    .sorted { $0.rawValue < $1.rawValue },
                defaultMeasurementUnit: product.defaultMeasurementUnit?.unit,
                shoppingListItemsCount: product.listItems.count
            )
        }
    }

    func createProduct(_ input: ProductInput) throws {
        try createProduct(
            named: input.name,
            measurementUnits: input.measurementUnits,
            defaultMeasurementUnit: input.defaultMeasurementUnit
        )
    }

    func updateProduct(
        id: ProductDetails.ID,
        with input: ProductInput
    ) throws {
        let product = try product(forCatalogID: id)
        try updateProduct(
            product,
            name: input.name,
            measurementUnits: input.measurementUnits,
            defaultMeasurementUnit: input.defaultMeasurementUnit
        )
    }

    func deleteProduct(id: ProductDetails.ID) throws {
        let product = try product(forCatalogID: id)
        let persistentID = product.persistentModelID
        try deleteProduct(product)
        catalogIDByPersistentID[persistentID] = nil
        persistentIDByCatalogID[id] = nil
    }

    private func catalogID(for product: Product) -> UUID {
        let persistentID = product.persistentModelID
        if let id = catalogIDByPersistentID[persistentID] {
            return id
        }

        let id = UUID()
        catalogIDByPersistentID[persistentID] = id
        persistentIDByCatalogID[id] = persistentID
        return id
    }

    private func product(forCatalogID id: UUID) throws -> Product {
        guard let persistentID = persistentIDByCatalogID[id],
              let product = try fetchProducts().first(where: {
                  $0.persistentModelID == persistentID
              }) else {
            throw ProductStoreError.productNotFound
        }
        return product
    }

    private func removeCatalogIDsForDeletedProducts(_ products: [Product]) {
        let existingPersistentIDs = Set(products.map(\.persistentModelID))
        let deletedPersistentIDs = catalogIDByPersistentID.keys.filter {
            !existingPersistentIDs.contains($0)
        }

        for persistentID in deletedPersistentIDs {
            guard let catalogID = catalogIDByPersistentID.removeValue(
                forKey: persistentID
            ) else { continue }
            persistentIDByCatalogID[catalogID] = nil
        }
    }
}

// MARK: - Product CRUD

extension ProductStore {
    @discardableResult
    func createProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>,
        defaultMeasurementUnit: MeasurementUnit?
    ) throws -> Product {
        let trimmedName = try ShoppingDomainValidation.productName(name)
        _ = try ShoppingDomainValidation.measurementUnits(measurementUnits)
        try validate(
            defaultMeasurementUnit,
            isIncludedIn: measurementUnits,
            productName: trimmedName
        )
        guard try findProduct(normalizedName: Product.normalize(trimmedName)) == nil else {
            throw ProductStoreError.duplicateProductName
        }

        let product = try insertProduct(
            named: trimmedName,
            measurementUnits: measurementUnits
        )
        if let defaultMeasurementUnit {
            product.setDefaultMeasurementUnit(defaultMeasurementUnit)
        }
        try saveChanges()
        return product
    }

    func updateProduct(
        _ product: Product,
        name: String,
        measurementUnits: Set<MeasurementUnit>,
        defaultMeasurementUnit: MeasurementUnit?
    ) throws {
        let trimmedName = try ShoppingDomainValidation.productName(name)
        _ = try ShoppingDomainValidation.measurementUnits(measurementUnits)
        try validate(
            defaultMeasurementUnit,
            isIncludedIn: measurementUnits,
            productName: trimmedName
        )

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
        if let defaultMeasurementUnit {
            product.setDefaultMeasurementUnit(defaultMeasurementUnit)
        }
        try saveChanges()
    }

    func deleteProduct(_ product: Product) throws {
        modelContext.delete(product)
        try saveChanges()
    }
}

// MARK: - Measurement unit CRUD

extension ProductStore {
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

        let product = measurementUnit.product
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

    func setDefaultMeasurementUnit(_ measurementUnit: ProductMeasurementUnit) throws {
        measurementUnit.makeDefault()
        try saveChanges()
    }

    func deleteMeasurementUnit(_ measurementUnit: ProductMeasurementUnit) throws {
        let product = measurementUnit.product
        guard product.measurementUnits.count > 1 else {
            throw ProductStoreError.lastMeasurementUnit
        }
        guard !product.listItems.contains(where: { $0.unit == measurementUnit.unit }) else {
            throw ProductStoreError.measurementUnitInUse
        }

        if measurementUnit.isDefault {
            product.measurementUnits
                .filter { $0 !== measurementUnit }
                .sorted { $0.unit.rawValue < $1.unit.rawValue }
                .first?
                .makeDefault()
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
}

// MARK: - ShoppingStore coordination

extension ProductStore {
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

    private func validate(
        _ defaultMeasurementUnit: MeasurementUnit?,
        isIncludedIn measurementUnits: Set<MeasurementUnit>,
        productName: String
    ) throws {
        guard let defaultMeasurementUnit else { return }
        guard measurementUnits.contains(defaultMeasurementUnit) else {
            throw ShoppingDomainError.unsupportedMeasurementUnit(
                productName: productName,
                unit: defaultMeasurementUnit
            )
        }
    }

    private func applyMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        to product: Product
    ) {
        let previousDefaultUnit = product.defaultMeasurementUnit?.unit

        for measurementUnit in product.measurementUnits where !units.contains(measurementUnit.unit) {
            modelContext.delete(measurementUnit)
        }

        for unit in units where !product.supports(unit) {
            if let measurementUnit = product.addMeasurementUnit(unit) {
                modelContext.insert(measurementUnit)
            }
        }

        let resultingDefaultUnit = previousDefaultUnit.flatMap { units.contains($0) ? $0 : nil }
            ?? units.sorted { $0.rawValue < $1.rawValue }.first
        if let resultingDefaultUnit {
            product.setDefaultMeasurementUnit(resultingDefaultUnit)
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
