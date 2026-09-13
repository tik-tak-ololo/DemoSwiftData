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
    private(set) var resetStatusMessage: String?

    @ObservationIgnored private let store: any ShoppingStoreProtocol
    @ObservationIgnored private let demoDataSeeder: any DemoDataSeeding
    @ObservationIgnored private let consoleOutput: (String) -> Void

    init(
        store: any ShoppingStoreProtocol,
        demoDataSeeder: any DemoDataSeeding,
        consoleOutput: @escaping (String) -> Void = { print($0) }
    ) {
        self.store = store
        self.demoDataSeeder = demoDataSeeder
        self.consoleOutput = consoleOutput
    }

    func resetDemoData() {
        do {
            try demoDataSeeder.resetToInitialState()
            errorMessage = nil
            resetStatusMessage = "Начальные демо-данные восстановлены."
        } catch {
            resetStatusMessage = nil
            errorMessage = error.localizedDescription
        }
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
                    "name: \(product.name)",
                    "normalizedName: \(product.normalizedName)",
                    "measurementUnits: \(Self.measurementUnitsDescription(product))",
                    "listItemsCount: \(product.listItems.count)"
                ]
            }
            return Self.makeTableDump(tableName: "Product", rows: rows)
        }
    }

    func printProductMeasurementUnits() {
        performConsoleOutput {
            let rows = try store.fetchProductMeasurementUnits().map { measurementUnit in
                [
                    "unit: \(measurementUnit.unit.rawValue)",
                    "product: \(measurementUnit.product.name)"
                ]
            }
            return Self.makeTableDump(
                tableName: "ProductMeasurementUnit",
                rows: rows
            )
        }
    }

    func printShoppingListItems() {
        performConsoleOutput {
            let rows = try store.fetchShoppingListItems().map { item in
                [
                    "id: \(item.id)",
                    "quantity: \(item.quantity)",
                    "unit: \(item.unit.rawValue)",
                    "isPurchased: \(item.isPurchased)",
                    "createdAt: \(Self.format(item.createdAt))",
                    "shoppingList: \(item.shoppingList?.name ?? "nil")",
                    "product: \(Self.productDescription(item.product))"
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
            resetStatusMessage = nil
        } catch {
            resetStatusMessage = nil
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

    private static func productDescription(_ product: Product?) -> String {
        guard let product else { return "nil" }
        return product.name
    }

    private static func measurementUnitsDescription(_ product: Product) -> String {
        product.measurementUnits
            .map(\.unit.rawValue)
            .sorted()
            .joined(separator: ", ")
    }

    private static func format(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

}
