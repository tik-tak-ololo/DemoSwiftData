//
//  ProductStoreProtocol.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 13.09.2026.
//

import Foundation
import SwiftData

/// Граница операций каталога товаров.
@MainActor
protocol ProductStoreProtocol: AnyObject {
    func fetchProducts() throws -> [Product]
    func fetchProductMeasurementUnits() throws -> [ProductMeasurementUnit]

    @discardableResult
    func createProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws -> Product
    func updateProduct(
        _ product: Product,
        name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws
    func deleteProduct(_ product: Product) throws

    @discardableResult
    func createMeasurementUnit(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws -> ProductMeasurementUnit
    func updateMeasurementUnit(
        _ measurementUnit: ProductMeasurementUnit,
        to unit: MeasurementUnit
    ) throws
    func deleteMeasurementUnit(_ measurementUnit: ProductMeasurementUnit) throws

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
    func replaceModelContext(_ modelContext: ModelContext)
    func findOrCreateProduct(
        named name: String,
        initialMeasurementUnits: Set<MeasurementUnit>
    ) throws -> Product
    func insertProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>
    ) throws -> Product
    func addMissingMeasurementUnits(
        _ units: Set<MeasurementUnit>,
        to product: Product
    ) throws
    func validate(
        _ unit: MeasurementUnit,
        for product: Product
    ) throws
}
