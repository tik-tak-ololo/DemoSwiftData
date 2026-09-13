//
//  ProductStoreProtocol.swift
//  DemoSwiftData
//
//  Created by Codex on 13.09.2026.
//

import Foundation

/// Граница операций каталога товаров.
@MainActor
protocol ProductStoreProtocol: AnyObject {
    func fetchProducts() throws -> [Product]
    func fetchProductMeasurementUnits() throws -> [ProductMeasurementUnit]

    func renameProduct(_ product: Product, to name: String) throws
    func setMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        for product: Product
    ) throws
}

/// Операции, которые ShoppingStore использует как часть составного изменения.
/// Они работают с общим ModelContext, но не сохраняют его самостоятельно.
@MainActor
protocol ProductStoreCoordinating: ProductStoreProtocol {
    func findOrCreateProduct(
        named name: String,
        initialMeasurementUnits: Set<MeasurementUnit>
    ) throws -> Product
    func insertProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws -> Product
    func validate(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws
    func deleteAllProducts() throws
}
