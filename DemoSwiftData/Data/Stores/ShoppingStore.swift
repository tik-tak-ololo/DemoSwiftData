//
//  ShoppingStore.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation
import SwiftData

enum ShoppingStoreError: LocalizedError {
    case emptyListName
    case emptyProductName
    case duplicateProductName
    case invalidQuantity
    case emptyMeasurementUnits
    case unsupportedMeasurementUnit(productName: String, unit: MeasurementUnit)
    case measurementUnitInUse

    var errorDescription: String? {
        switch self {
        case .emptyListName:
            "Введите название списка."
        case .emptyProductName:
            "Введите название товара."
        case .duplicateProductName:
            "Товар с таким названием уже существует."
        case .invalidQuantity:
            "Количество должно быть больше нуля."
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
final class ShoppingStore: ShoppingStoreProtocol, DemoDataApplying {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        let modelContext = modelContainer.mainContext
        self.modelContainer = modelContainer
        self.modelContext = modelContext
    }

    func fetchShoppingLists() throws -> [ShoppingList] {
        try modelContext.fetch(Self.shoppingListsDescriptor)
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

    func fetchShoppingListItems() throws -> [ShoppingListItem] {
        try modelContext.fetch(Self.shoppingListItemsDescriptor)
    }

    @discardableResult
    func createList(
        named name: String,
        iconColor: ShoppingListIconColor,
        iconDesign: ShoppingListIconDesign
    ) throws -> ShoppingList {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShoppingStoreError.emptyListName
        }

        let shoppingList = ShoppingList(
            name: trimmedName,
            iconColor: iconColor,
            iconDesign: iconDesign
        )
        modelContext.insert(shoppingList)
        try saveChanges()
        return shoppingList
    }
    
    func deleteList(_ shoppingList: ShoppingList) throws {
        modelContext.delete(shoppingList)
        try saveChanges()
    }

    func renameProduct(_ product: Product, to name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShoppingStoreError.emptyProductName
        }

        let normalizedName = Product.normalize(trimmedName)
        if normalizedName != product.normalizedName,
           try findProduct(normalizedName: normalizedName) != nil {
            throw ShoppingStoreError.duplicateProductName
        }

        product.rename(to: trimmedName)
        try saveChanges()
    }

    func setMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        for product: Product
    ) throws {
        guard !units.isEmpty else {
            throw ShoppingStoreError.emptyMeasurementUnits
        }

        let usedUnits = Set(product.listItems.map(\.unit))
        guard usedUnits.isSubset(of: units) else {
            throw ShoppingStoreError.measurementUnitInUse
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

    func addItem(
        named name: String,
        unit: MeasurementUnit,
        quantity: Int,
        to shoppingList: ShoppingList
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShoppingStoreError.emptyProductName
        }
        guard quantity > 0 else {
            throw ShoppingStoreError.invalidQuantity
        }

        let product = try findOrCreateProduct(
            named: trimmedName,
            initialMeasurementUnits: [unit]
        )
        try validate(unit, for: product)

        let normalizedName = product.normalizedName
        if let existingItem = shoppingList.items.first(where: {
            $0.product?.normalizedName == normalizedName && $0.unit == unit
        }) {
            existingItem.quantity += quantity
            try saveChanges()
            return
        }

        let item = ShoppingListItem(
            quantity: quantity,
            unit: unit,
            shoppingList: shoppingList,
            product: product
        )
        modelContext.insert(item)
        try saveChanges()
    }

    func updateItem(
        _ item: ShoppingListItem,
        name: String,
        unit: MeasurementUnit,
        quantity: Int
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShoppingStoreError.emptyProductName
        }
        guard quantity > 0 else {
            throw ShoppingStoreError.invalidQuantity
        }

        let product = try findOrCreateProduct(
            named: trimmedName,
            initialMeasurementUnits: [unit]
        )
        try validate(unit, for: product)

        let normalizedName = product.normalizedName
        if let existingItem = item.shoppingList?.items.first(where: {
            $0 !== item &&
                $0.product?.normalizedName == normalizedName &&
                $0.unit == unit
        }) {
            existingItem.quantity += quantity
            existingItem.isPurchased = existingItem.isPurchased && item.isPurchased
            modelContext.delete(item)
            try saveChanges()
            return
        }

        item.product = product
        item.unit = unit
        item.quantity = quantity
        try saveChanges()
    }
    
    func deleteItem(_ item: ShoppingListItem) throws {
        modelContext.delete(item)
        try saveChanges()
    }

    func togglePurchased(_ item: ShoppingListItem) throws {
        item.isPurchased.toggle()
        try saveChanges()
    }

    func deletePurchasedItems(from shoppingList: ShoppingList) throws {
        shoppingList.items
            .filter(\.isPurchased)
            .forEach(modelContext.delete)
        try saveChanges()
    }

    func applyInitialDemoDataIfEmpty(_ data: DemoData) throws {
        guard try fetchShoppingLists().isEmpty else { return }

        let existingProducts = try fetchProducts()
        let productsByNormalizedName = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.normalizedName, $0) }
        )

        try performTransaction {
            insert(data, productsByNormalizedName: productsByNormalizedName)
        }
    }

    func replaceAllData(with data: DemoData) throws {
        try performTransaction {
            try deleteAllData()
            insert(data, productsByNormalizedName: [:])
        }
    }

    private static var shoppingListsDescriptor: FetchDescriptor<ShoppingList> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\ShoppingList.name)]
        )
    }

    private static var productsDescriptor: FetchDescriptor<Product> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\Product.normalizedName)]
        )
    }

    private static var shoppingListItemsDescriptor: FetchDescriptor<ShoppingListItem> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\ShoppingListItem.createdAt)]
        )
    }

    private func deleteAllData() throws {
        try modelContext.fetch(Self.shoppingListItemsDescriptor)
            .forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<ProductMeasurementUnit>())
            .forEach(modelContext.delete)
        try modelContext.fetch(Self.shoppingListsDescriptor)
            .forEach(modelContext.delete)
        try modelContext.fetch(Self.productsDescriptor)
            .forEach(modelContext.delete)
    }

    private func insert(
        _ data: DemoData,
        productsByNormalizedName initialProducts: [String: Product]
    ) {
        var productsByNormalizedName = initialProducts

        for listData in data.lists {
            let shoppingList = ShoppingList(
                name: listData.name,
                iconColor: listData.iconColor,
                iconDesign: listData.iconDesign
            )
            modelContext.insert(shoppingList)

            for itemData in listData.items {
                let normalizedName = Product.normalize(itemData.name)
                let product: Product

                if let existingProduct = productsByNormalizedName[normalizedName] {
                    product = existingProduct
                } else {
                    product = Product(
                        name: itemData.name,
                        measurementUnits: Array(itemData.productMeasurementUnits)
                    )
                    modelContext.insert(product)
                    productsByNormalizedName[normalizedName] = product
                }

                modelContext.insert(
                    ShoppingListItem(
                        quantity: itemData.quantity,
                        unit: itemData.unit,
                        shoppingList: shoppingList,
                        product: product
                    )
                )
            }
        }
    }

    private func findOrCreateProduct(
        named name: String,
        initialMeasurementUnits: Set<MeasurementUnit>
    ) throws -> Product {
        let normalizedName = Product.normalize(name)
        if let existingProduct = try findProduct(normalizedName: normalizedName) {
            return existingProduct
        }

        guard !initialMeasurementUnits.isEmpty else {
            throw ShoppingStoreError.emptyMeasurementUnits
        }

        let product = Product(
            name: name,
            measurementUnits: Array(initialMeasurementUnits)
        )
        modelContext.insert(product)
        return product
    }

    private func validate(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws {
        guard product.supports(unit) else {
            throw ShoppingStoreError.unsupportedMeasurementUnit(
                productName: product.name,
                unit: unit
            )
        }
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

    private func performTransaction(_ operation: () throws -> Void) throws {
        do {
            try modelContext.transaction(block: operation)
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
