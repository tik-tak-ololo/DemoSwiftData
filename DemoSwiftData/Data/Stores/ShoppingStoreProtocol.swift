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
    var shoppingLists: [ShoppingList] { get }

    @discardableResult
    func createList(named name: String) throws -> ShoppingList
    func deleteList(_ shoppingList: ShoppingList) throws

    func addItem(
        named name: String,
        quantity: Int,
        to shoppingList: ShoppingList
    ) throws
    func updateItem(
        _ item: ShoppingListItem,
        name: String,
        quantity: Int
    ) throws
    func deleteItem(_ item: ShoppingListItem) throws
    
    func togglePurchased(_ item: ShoppingListItem) throws
    func deletePurchasedItems(from shoppingList: ShoppingList) throws
}
