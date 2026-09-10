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
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .emptyListName:
            "Введите название списка."
        case .emptyProductName:
            "Введите название товара."
        case .invalidQuantity:
            "Количество должно быть больше нуля."
        }
    }
}

@MainActor
final class ShoppingStore: ShoppingStoreProtocol, DemoDataApplying {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    private(set) var shoppingLists: [ShoppingList]

    init(modelContainer: ModelContainer) throws {
        let modelContext = modelContainer.mainContext
        self.modelContainer = modelContainer
        self.modelContext = modelContext
        shoppingLists = try modelContext.fetch(Self.shoppingListsDescriptor)
    }

    @discardableResult
    func createList(named name: String) throws -> ShoppingList {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShoppingStoreError.emptyListName
        }

        let shoppingList = ShoppingList(name: trimmedName)
        modelContext.insert(shoppingList)
        try saveChanges()
        shoppingLists.append(shoppingList)
        sortShoppingLists()
        return shoppingList
    }
    
    func deleteList(_ shoppingList: ShoppingList) throws {
        modelContext.delete(shoppingList)
        try saveChanges()
        shoppingLists.removeAll { $0.id == shoppingList.id }
    }

    func addItem(
        named name: String,
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

        let normalizedName = Product.normalize(trimmedName)
        if let existingItem = shoppingList.items.first(where: {
            $0.product?.normalizedName == normalizedName
        }) {
            existingItem.quantity += quantity
            try saveChanges()
            return
        }

        let product = try findOrCreateProduct(named: trimmedName)
        let item = ShoppingListItem(
            quantity: quantity,
            shoppingList: shoppingList,
            product: product
        )
        modelContext.insert(item)
        try saveChanges()
    }

    func updateItem(
        _ item: ShoppingListItem,
        name: String,
        quantity: Int
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShoppingStoreError.emptyProductName
        }
        guard quantity > 0 else {
            throw ShoppingStoreError.invalidQuantity
        }

        let normalizedName = Product.normalize(trimmedName)
        if let existingItem = item.shoppingList?.items.first(where: {
            $0 !== item && $0.product?.normalizedName == normalizedName
        }) {
            existingItem.quantity += quantity
            existingItem.isPurchased = existingItem.isPurchased && item.isPurchased
            existingItem.product?.rename(to: trimmedName)
            modelContext.delete(item)
            try saveChanges()
            return
        }

        if item.product?.normalizedName == normalizedName {
            item.product?.rename(to: trimmedName)
        } else {
            item.product = try findOrCreateProduct(named: trimmedName)
        }
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
        guard shoppingLists.isEmpty else { return }

        var insertedLists: [ShoppingList] = []

        try performTransaction {
            var productsByNormalizedName: [String: Product] = [:]

            for listData in data.lists {
                let shoppingList = ShoppingList(name: listData.name)
                modelContext.insert(shoppingList)
                insertedLists.append(shoppingList)

                for itemData in listData.items {
                    let normalizedName = Product.normalize(itemData.name)
                    let product: Product
                    if let existingProduct = productsByNormalizedName[normalizedName] {
                        product = existingProduct
                    } else {
                        product = try findOrCreateProduct(named: itemData.name)
                        productsByNormalizedName[normalizedName] = product
                    }

                    modelContext.insert(
                        ShoppingListItem(
                            quantity: itemData.quantity,
                            shoppingList: shoppingList,
                            product: product
                        )
                    )
                }
            }
        }

        shoppingLists.append(contentsOf: insertedLists)
        sortShoppingLists()
    }

    private static var shoppingListsDescriptor: FetchDescriptor<ShoppingList> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\ShoppingList.createdAt, order: .reverse)]
        )
    }

    private func sortShoppingLists() {
        shoppingLists.sort { $0.createdAt > $1.createdAt }
    }

    private func findOrCreateProduct(named name: String) throws -> Product {
        let normalizedName = Product.normalize(name)
        let predicate = #Predicate<Product> { product in
            product.normalizedName == normalizedName
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existingProduct = try modelContext.fetch(descriptor).first {
            return existingProduct
        }

        let product = Product(name: name)
        modelContext.insert(product)
        return product
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
