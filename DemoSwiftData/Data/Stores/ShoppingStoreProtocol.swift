//
//  ShoppingStoreProtocol.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation

/// Единая граница между фичами приложения и persistence-реализацией.
@MainActor
protocol ShoppingStoreProtocol: AnyObject {
    func fetchShoppingLists() throws -> [ShoppingList]
    func fetchProducts() throws -> [Product]
    func fetchShoppingListItems() throws -> [ShoppingListItem]

    @discardableResult
    func createList(
        named name: String,
        iconColor: ShoppingListIconColor,
        iconDesign: ShoppingListIconDesign
    ) throws -> ShoppingList
    func deleteList(_ shoppingList: ShoppingList) throws

    func renameProduct(_ product: Product, to name: String) throws

    func addItem(
        named name: String,
        unit: MeasurementUnit,
        quantity: Int,
        to shoppingList: ShoppingList
    ) throws
    func updateItem(
        _ item: ShoppingListItem,
        name: String,
        unit: MeasurementUnit,
        quantity: Int
    ) throws
    func deleteItem(_ item: ShoppingListItem) throws
    
    func togglePurchased(_ item: ShoppingListItem) throws
    func deletePurchasedItems(from shoppingList: ShoppingList) throws
}
