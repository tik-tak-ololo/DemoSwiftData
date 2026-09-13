//
//  ShoppingStore.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation
import SwiftData

@MainActor
final class ShoppingStore: ShoppingStoreProtocol, DemoDataApplying {
    /// ModelContext не владеет временем жизни контейнера, поэтому store удерживает оба объекта.
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext
    private let productStore: any ProductStoreCoordinating

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext,
        productStore: any ProductStoreCoordinating
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
        self.productStore = productStore
    }

    func fetchShoppingLists() throws -> [ShoppingList] {
        try modelContext.fetch(Self.shoppingListsDescriptor)
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
        let shoppingList = try ShoppingList(
            name: name,
            iconColor: iconColor,
            iconDesign: iconDesign
        )
        modelContext.insert(shoppingList)
        try saveChanges()
        return shoppingList
    }

    func updateList(
        _ shoppingList: ShoppingList,
        name: String,
        iconColor: ShoppingListIconColor,
        iconDesign: ShoppingListIconDesign
    ) throws {
        try shoppingList.update(
            name: name,
            iconColor: iconColor,
            iconDesign: iconDesign
        )
        try saveChanges()
    }

    func deleteList(_ shoppingList: ShoppingList) throws {
        modelContext.delete(shoppingList)
        try saveChanges()
    }

    func addItem(
        named name: String,
        unit: MeasurementUnit,
        quantity: Int,
        to shoppingList: ShoppingList
    ) throws {
        let trimmedName = try ShoppingDomainValidation.productName(name)
        let validatedQuantity = try ShoppingDomainValidation.quantity(quantity)

        let product = try productStore.findOrCreateProduct(
            named: trimmedName,
            initialMeasurementUnits: [unit]
        )
        try productStore.validate(unit, for: product)

        let normalizedName = product.normalizedName
        if let existingItem = shoppingList.items.first(where: {
            $0.product?.normalizedName == normalizedName && $0.unit == unit
        }) {
            try existingItem.increaseQuantity(by: validatedQuantity)
            try saveChanges()
            return
        }

        let item = try ShoppingListItem(
            quantity: validatedQuantity,
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
        let trimmedName = try ShoppingDomainValidation.productName(name)
        let validatedQuantity = try ShoppingDomainValidation.quantity(quantity)

        let product = try productStore.findOrCreateProduct(
            named: trimmedName,
            initialMeasurementUnits: [unit]
        )
        try productStore.validate(unit, for: product)

        let normalizedName = product.normalizedName
        if let existingItem = item.shoppingList?.items.first(where: {
            $0 !== item &&
                $0.product?.normalizedName == normalizedName &&
                $0.unit == unit
        }) {
            try existingItem.increaseQuantity(by: validatedQuantity)
            existingItem.mergePurchaseStatus(with: item)
            modelContext.delete(item)
            try saveChanges()
            return
        }

        try item.update(
            product: product,
            unit: unit,
            quantity: validatedQuantity
        )
        try saveChanges()
    }

    func deleteItem(_ item: ShoppingListItem) throws {
        modelContext.delete(item)
        try saveChanges()
    }

    func togglePurchased(_ item: ShoppingListItem) throws {
        item.togglePurchased()
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
        try validate(data)

        let existingProducts = try productStore.fetchProducts()
        let productsByNormalizedName = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.normalizedName, $0) }
        )

        try performTransaction {
            try insert(data, productsByNormalizedName: productsByNormalizedName)
        }
    }

    func replaceAllData(with data: DemoData) throws {
        try validate(data)
        try performTransaction {
            try deleteAllDataInCurrentContext()
            try insert(data, productsByNormalizedName: [:])
        }
        replaceSharedContext()
    }

    private func deleteAllDataInCurrentContext() throws {
        // Явное удаление дочерних моделей предотвращает создание некорректных
        // relationship snapshots при удалении и повторной вставке в одной транзакции.
        try modelContext.fetch(Self.shoppingListItemsDescriptor)
            .forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<ProductMeasurementUnit>())
            .forEach(modelContext.delete)
        try modelContext.fetch(Self.shoppingListsDescriptor)
            .forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<Product>())
            .forEach(modelContext.delete)
    }

    private func replaceSharedContext() {
        let freshContext = ModelContext(modelContainer)
        modelContext = freshContext
        productStore.replaceModelContext(freshContext)
    }

    private static var shoppingListsDescriptor: FetchDescriptor<ShoppingList> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\ShoppingList.name)]
        )
    }

    private static var shoppingListItemsDescriptor: FetchDescriptor<ShoppingListItem> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\ShoppingListItem.createdAt)]
        )
    }

    private func insert(
        _ data: DemoData,
        productsByNormalizedName initialProducts: [String: Product]
    ) throws {
        var productsByNormalizedName = initialProducts

        for listData in data.lists {
            let shoppingList = try ShoppingList(
                name: listData.name,
                iconColor: listData.iconColor,
                iconDesign: listData.iconDesign
            )
            modelContext.insert(shoppingList)

            for itemData in listData.items {
                let normalizedName = Product.normalize(itemData.name)
                let requiredUnits = itemData.productMeasurementUnits.union([itemData.unit])
                let product: Product

                if let existingProduct = productsByNormalizedName[normalizedName] {
                    product = existingProduct
                    try productStore.addMissingMeasurementUnits(
                        requiredUnits,
                        to: product
                    )
                } else {
                    product = try productStore.insertProduct(
                        named: itemData.name,
                        measurementUnits: requiredUnits
                    )
                    productsByNormalizedName[normalizedName] = product
                }

                try productStore.validate(itemData.unit, for: product)
                modelContext.insert(
                    try ShoppingListItem(
                        quantity: itemData.quantity,
                        unit: itemData.unit,
                        shoppingList: shoppingList,
                        product: product
                    )
                )
            }
        }
    }

    private func validate(_ data: DemoData) throws {
        for list in data.lists {
            _ = try ShoppingDomainValidation.listName(list.name)

            for item in list.items {
                _ = try ShoppingDomainValidation.productName(item.name)
                _ = try ShoppingDomainValidation.quantity(item.quantity)
                _ = try ShoppingDomainValidation.measurementUnits(
                    item.productMeasurementUnits.union([item.unit])
                )
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

    private func performTransaction(_ operation: () throws -> Void) throws {
        do {
            try modelContext.transaction(block: operation)
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
