//
//  ShoppingListsObserved.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShoppingListsObserved {
    private(set) var errorMessage: String?

    @ObservationIgnored private let store: any ShoppingStoreProtocol
    @ObservationIgnored private let consoleOutput: (String) -> Void

    init(
        store: any ShoppingStoreProtocol,
        consoleOutput: @escaping (String) -> Void = { print($0) }
    ) {
        self.store = store
        self.consoleOutput = consoleOutput
    }

    func printShoppingLists() {
        performConsoleOutput {
            let rows = try store.fetchShoppingLists().map { shoppingList in
                [
                    "name: \(shoppingList.name)",
                    "iconColor: \(shoppingList.iconColor.rawValue)",
                    "iconDesign: \(shoppingList.iconDesign.rawValue)",
                    "itemsCount: \(shoppingList.items.count)"
                ]
            }
            return Self.makeTableDump(tableName: "ShoppingList", rows: rows)
        }
    }

    func printProducts() {
        performConsoleOutput {
            let rows = try store.fetchProducts().map { product in
                [
                    "id: \(product.id)",
                    "name: \(product.name)",
                    "normalizedName: \(product.normalizedName)",
                    "symbolName: \(product.symbolName)",
                    "listItemsCount: \(product.listItems.count)"
                ]
            }
            return Self.makeTableDump(tableName: "Product", rows: rows)
        }
    }

    func printShoppingListItems() {
        performConsoleOutput {
            let rows = try store.fetchShoppingListItems().map { item in
                [
                    "id: \(item.id)",
                    "quantity: \(item.quantity)",
                    "isPurchased: \(item.isPurchased)",
                    "createdAt: \(Self.format(item.createdAt))",
                    "shoppingList: \(item.shoppingList?.name ?? "nil")",
                    "product: \(Self.relationshipDescription(id: item.product?.id, name: item.product?.name))"
                ]
            }
            return Self.makeTableDump(tableName: "ShoppingListItem", rows: rows)
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func performConsoleOutput(_ makeOutput: () throws -> String) {
        do {
            consoleOutput(try makeOutput())
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeTableDump(
        tableName: String,
        rows: [[String]]
    ) -> String {
        let header = "===== \(tableName) (\(rows.count)) ====="
        let body = rows.enumerated().map { index, fields in
            "[\(index + 1)]\n" + fields.joined(separator: "\n")
        }
        .joined(separator: "\n\n")

        return body.isEmpty
            ? "\(header)\nТаблица пуста.\n===================="
            : "\(header)\n\(body)\n===================="
    }

    private static func relationshipDescription(
        id: UUID?,
        name: String?
    ) -> String {
        guard let id, let name else { return "nil" }
        return "\(name) [\(id)]"
    }

    private static func format(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

}
