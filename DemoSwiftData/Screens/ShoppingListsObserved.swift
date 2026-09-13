//
//  ShoppingListsObserved.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation
import Observation

private enum CRUDDemoError: LocalizedError {
    case noRecords(entityName: String)
    case noProductForMeasurementUnit
    case noAvailableMeasurementUnit
    case noDeletableMeasurementUnit
    case itemWithoutProduct

    var errorDescription: String? {
        switch self {
        case let .noRecords(entityName):
            "В таблице \(entityName) нет записей для этой операции."
        case .noProductForMeasurementUnit:
            "Сначала создайте хотя бы один товар."
        case .noAvailableMeasurementUnit:
            "У всех подходящих товаров уже добавлены все единицы измерения."
        case .noDeletableMeasurementUnit:
            "Нет единицы, которую можно безопасно удалить: используемые и последние единицы защищены."
        case .itemWithoutProduct:
            "У выбранной позиции отсутствует связанный товар."
        }
    }
}

@MainActor
@Observable
final class ShoppingListsObserved {
    private(set) var errorMessage: String?
    private(set) var statusMessage: String?

    @ObservationIgnored private let shoppingStore: any ShoppingStoreProtocol
    @ObservationIgnored private let productStore: any ProductStoreProtocol
    @ObservationIgnored private let demoDataSeeder: any DemoDataSeeding
    @ObservationIgnored private let consoleOutput: (String) -> Void

    init(
        shoppingStore: any ShoppingStoreProtocol,
        productStore: any ProductStoreProtocol,
        demoDataSeeder: any DemoDataSeeding,
        consoleOutput: @escaping (String) -> Void = { print($0) }
    ) {
        self.shoppingStore = shoppingStore
        self.productStore = productStore
        self.demoDataSeeder = demoDataSeeder
        self.consoleOutput = consoleOutput
    }

    func resetDemoData() {
        do {
            try demoDataSeeder.resetToInitialState()
            errorMessage = nil
            statusMessage = "Начальные демо-данные восстановлены."
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func printShoppingLists() {
        performConsoleOutput {
            let rows = try shoppingStore.fetchShoppingLists().map { shoppingList in
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
            let rows = try productStore.fetchProducts().map { product in
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
            let rows = try productStore.fetchProductMeasurementUnits().map { measurementUnit in
                [
                    "unit: \(measurementUnit.unit.rawValue)",
                    "product: \(measurementUnit.product?.name ?? "nil")"
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
            let rows = try shoppingStore.fetchShoppingListItems().map { item in
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

    // MARK: - ShoppingList CRUD

    func createShoppingList() {
        performMutation {
            let lists = try shoppingStore.fetchShoppingLists()
            let name = Self.uniqueName(
                prefix: "CRUD список",
                existingNames: lists.map(\.name)
            )
            try shoppingStore.createList(
                named: name,
                iconColor: .lavender,
                iconDesign: .cart
            )
            return "CREATE ShoppingList: «\(name)»"
        }
    }

    func updateShoppingList() {
        performMutation {
            guard let shoppingList = try shoppingStore.fetchShoppingLists().last else {
                throw CRUDDemoError.noRecords(entityName: "ShoppingList")
            }

            let color = Self.next(shoppingList.iconColor)
            let design = Self.next(shoppingList.iconDesign)
            try shoppingStore.updateList(
                shoppingList,
                name: shoppingList.name,
                iconColor: color,
                iconDesign: design
            )
            return "UPDATE ShoppingList: «\(shoppingList.name)», цвет и иконка изменены"
        }
    }

    func deleteShoppingList() {
        performMutation {
            guard let shoppingList = try shoppingStore.fetchShoppingLists().last else {
                throw CRUDDemoError.noRecords(entityName: "ShoppingList")
            }

            let name = shoppingList.name
            try shoppingStore.deleteList(shoppingList)
            return "DELETE ShoppingList: «\(name)»"
        }
    }

    // MARK: - Product CRUD

    func createProduct() {
        performMutation {
            let products = try productStore.fetchProducts()
            let name = Self.uniqueName(
                prefix: "CRUD товар",
                existingNames: products.map(\.name)
            )
            try productStore.createProduct(
                named: name,
                measurementUnits: [.piece]
            )
            return "CREATE Product: «\(name)»"
        }
    }

    func updateProduct() {
        performMutation {
            let products = try productStore.fetchProducts()
            guard let product = products.last else {
                throw CRUDDemoError.noRecords(entityName: "Product")
            }

            let name = Self.uniqueName(
                prefix: "\(product.name) · обновлено",
                existingNames: products
                    .filter { $0 !== product }
                    .map(\.name)
            )
            var units = Set(product.measurementUnits.map(\.unit))
            if let additionalUnit = MeasurementUnit.allCases.first(where: { !units.contains($0) }) {
                units.insert(additionalUnit)
            }

            try productStore.updateProduct(
                product,
                name: name,
                measurementUnits: units
            )
            return "UPDATE Product: новое имя «\(name)»"
        }
    }

    func deleteProduct() {
        performMutation {
            guard let product = try productStore.fetchProducts().last else {
                throw CRUDDemoError.noRecords(entityName: "Product")
            }

            let name = product.name
            try productStore.deleteProduct(product)
            return "DELETE Product: «\(name)»"
        }
    }

    // MARK: - ProductMeasurementUnit CRUD

    func createProductMeasurementUnit() {
        performMutation {
            let products = try productStore.fetchProducts()
            guard !products.isEmpty else {
                throw CRUDDemoError.noProductForMeasurementUnit
            }
            guard let selection = Self.productAndMissingUnit(from: products) else {
                throw CRUDDemoError.noAvailableMeasurementUnit
            }

            try productStore.createMeasurementUnit(
                selection.unit,
                for: selection.product
            )
            return "CREATE ProductMeasurementUnit: \(selection.product.name) — \(selection.unit.rawValue)"
        }
    }

    func updateProductMeasurementUnit() {
        performMutation {
            let measurementUnits = try productStore.fetchProductMeasurementUnits()
            guard !measurementUnits.isEmpty else {
                throw CRUDDemoError.noRecords(entityName: "ProductMeasurementUnit")
            }
            guard let selection = measurementUnits.lazy.compactMap({ measurementUnit -> (ProductMeasurementUnit, MeasurementUnit)? in
                guard let product = measurementUnit.product else { return nil }
                return MeasurementUnit.allCases
                    .first(where: { !product.supports($0) })
                    .map { (measurementUnit, $0) }
            }).first else {
                throw CRUDDemoError.noAvailableMeasurementUnit
            }

            let previousUnit = selection.0.unit
            try productStore.updateMeasurementUnit(selection.0, to: selection.1)
            let productName = selection.0.product?.name ?? "без товара"
            return "UPDATE ProductMeasurementUnit: \(productName), \(previousUnit.rawValue) → \(selection.1.rawValue)"
        }
    }

    func deleteProductMeasurementUnit() {
        performMutation {
            let measurementUnits = try productStore.fetchProductMeasurementUnits()
            guard let measurementUnit = measurementUnits.first(where: { measurementUnit in
                guard let product = measurementUnit.product else { return false }
                return product.measurementUnits.count > 1 &&
                    !product.listItems.contains(where: { item in
                        item.unit == measurementUnit.unit
                    })
            }) else {
                throw CRUDDemoError.noDeletableMeasurementUnit
            }

            let productName = measurementUnit.product?.name ?? "без товара"
            let unit = measurementUnit.unit
            try productStore.deleteMeasurementUnit(measurementUnit)
            return "DELETE ProductMeasurementUnit: \(productName) — \(unit.rawValue)"
        }
    }

    // MARK: - ShoppingListItem CRUD

    func createShoppingListItem() {
        performMutation {
            guard let shoppingList = try shoppingStore.fetchShoppingLists().last else {
                throw CRUDDemoError.noRecords(entityName: "ShoppingList")
            }

            let products = try productStore.fetchProducts()
            let name = Self.uniqueName(
                prefix: "CRUD позиция",
                existingNames: products.map(\.name)
            )
            try shoppingStore.addItem(
                named: name,
                unit: .piece,
                quantity: 1,
                to: shoppingList
            )
            return "CREATE ShoppingListItem: «\(name)» в списке «\(shoppingList.name)»"
        }
    }

    func updateShoppingListItem() {
        performMutation {
            guard let item = try shoppingStore.fetchShoppingListItems().last else {
                throw CRUDDemoError.noRecords(entityName: "ShoppingListItem")
            }
            guard let product = item.product else {
                throw CRUDDemoError.itemWithoutProduct
            }

            let quantity = item.quantity + 1
            try shoppingStore.updateItem(
                item,
                name: product.name,
                unit: item.unit,
                quantity: quantity
            )
            return "UPDATE ShoppingListItem: «\(product.name)», количество \(quantity)"
        }
    }

    func deleteShoppingListItem() {
        performMutation {
            guard let item = try shoppingStore.fetchShoppingListItems().last else {
                throw CRUDDemoError.noRecords(entityName: "ShoppingListItem")
            }

            let productName = item.product?.name ?? "без товара"
            try shoppingStore.deleteItem(item)
            return "DELETE ShoppingListItem: «\(productName)»"
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func performConsoleOutput(_ makeOutput: () throws -> String) {
        do {
            consoleOutput(try makeOutput())
            errorMessage = nil
            statusMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func performMutation(_ operation: () throws -> String) {
        do {
            let message = try operation()
            consoleOutput(message)
            errorMessage = nil
            statusMessage = message
        } catch {
            statusMessage = nil
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

    private static func uniqueName(
        prefix: String,
        existingNames: [String]
    ) -> String {
        let normalizedNames = Set(existingNames.map(Product.normalize))
        var index = 1
        var candidate = "\(prefix) \(index)"

        while normalizedNames.contains(Product.normalize(candidate)) {
            index += 1
            candidate = "\(prefix) \(index)"
        }
        return candidate
    }

    private static func next<Value: CaseIterable & Equatable>(_ value: Value) -> Value {
        let values = Array(Value.allCases)
        guard let currentIndex = values.firstIndex(of: value) else { return value }
        return values[(currentIndex + 1) % values.count]
    }

    private static func productAndMissingUnit(
        from products: [Product]
    ) -> (product: Product, unit: MeasurementUnit)? {
        for product in products {
            if let unit = MeasurementUnit.allCases.first(where: { !product.supports($0) }) {
                return (product, unit)
            }
        }
        return nil
    }
}
