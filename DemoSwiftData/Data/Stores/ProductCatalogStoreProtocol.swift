//
//  ProductCatalogStoreProtocol.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 14.09.2026.
//

import Foundation

/// Данные товара, которые persistence-слой передаёт фиче каталога.
///
/// Это value type без зависимости от SwiftData: экран не получает `@Model`
/// и не использует внутренний идентификатор persistence-фреймворка.
struct ProductDetails: Identifiable {
    let id: UUID
    let name: String
    let measurementUnits: [MeasurementUnit]
    let defaultMeasurementUnit: MeasurementUnit?
    let shoppingListItemsCount: Int
}

/// Значения, необходимые store для создания или изменения товара.
struct ProductInput {
    let name: String
    let measurementUnits: Set<MeasurementUnit>
    let defaultMeasurementUnit: MeasurementUnit
}

/// UI-независимая от SwiftData граница фичи каталога товаров.
@MainActor
protocol ProductCatalogStoreProtocol: AnyObject {
    func fetchProductCatalog() throws -> [ProductDetails]
    func createProduct(_ input: ProductInput) throws
    func updateProduct(id: ProductDetails.ID, with input: ProductInput) throws
    func deleteProduct(id: ProductDetails.ID) throws
}
