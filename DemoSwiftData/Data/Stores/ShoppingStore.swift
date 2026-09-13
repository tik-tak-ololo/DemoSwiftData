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
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .emptyListName:
            "Введите название списка."
        case .invalidQuantity:
            "Количество должно быть больше нуля."
        }
    }
}

@MainActor
final class ShoppingStore: ShoppingStoreProtocol, DemoDataApplying {
    /// ModelContext не владеет временем жизни контейнера, поэтому store удерживает оба объекта.
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
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

    func addItem(
        named name: String,
        unit: MeasurementUnit,
        quantity: Int,
        to shoppingList: ShoppingList
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProductStoreError.emptyProductName
        }
        guard quantity > 0 else {
            throw ShoppingStoreError.invalidQuantity
        }

        let product = try productStore.findOrCreateProduct(
            named: trimmedName,
            initialMeasurementUnits: [unit]
        )
        try productStore.validate(unit, for: product)

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
            throw ProductStoreError.emptyProductName
        }
        guard quantity > 0 else {
            throw ShoppingStoreError.invalidQuantity
        }

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

        let existingProducts = try productStore.fetchProducts()
        let productsByNormalizedName = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.normalizedName, $0) }
        )

        try performTransaction {
            try insert(data, productsByNormalizedName: productsByNormalizedName)
        }
    }

    func replaceAllData(with data: DemoData) throws {
        try performTransaction {
            try deleteAllData()
            try insert(data, productsByNormalizedName: [:])
        }
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

    private func deleteAllData() throws {
        try modelContext.fetch(Self.shoppingListItemsDescriptor)
            .forEach(modelContext.delete)
        try modelContext.fetch(Self.shoppingListsDescriptor)
            .forEach(modelContext.delete)
        try productStore.deleteAllProducts()
    }

    private func insert(
        _ data: DemoData,
        productsByNormalizedName initialProducts: [String: Product]
    ) throws {
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
                    product = try productStore.insertProduct(
                        named: itemData.name,
                        measurementUnits: itemData.productMeasurementUnits
                    )
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
