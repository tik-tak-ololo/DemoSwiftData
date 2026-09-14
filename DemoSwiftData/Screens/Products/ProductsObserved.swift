//
//  ProductsObserved.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 14.09.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProductsObserved {
    private(set) var products: [ProductListItem] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let productStore: any ProductCatalogStoreProtocol

    var isBusy: Bool {
        isLoading || isMutating
    }

    init(productStore: any ProductCatalogStoreProtocol) {
        self.productStore = productStore
    }

    func loadProducts() async {
        guard !isLoading, !isMutating else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            await Task.yield()
            try Task.checkCancellation()
            try reloadProductsFromStore()
            hasLoaded = true
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createProduct(
        named name: String,
        measurementUnits: Set<MeasurementUnit>,
        defaultMeasurementUnit: MeasurementUnit
    ) async -> Bool {
        await performMutation {
            try productStore.createProduct(
                ProductInput(
                    name: name,
                    measurementUnits: measurementUnits,
                    defaultMeasurementUnit: defaultMeasurementUnit
                )
            )
        }
    }

    @discardableResult
    func updateProduct(
        _ item: ProductListItem,
        name: String,
        measurementUnits: Set<MeasurementUnit>,
        defaultMeasurementUnit: MeasurementUnit
    ) async -> Bool {
        return await performMutation {
            try productStore.updateProduct(
                id: item.id,
                with: ProductInput(
                    name: name,
                    measurementUnits: measurementUnits,
                    defaultMeasurementUnit: defaultMeasurementUnit
                )
            )
        }
    }

    func deleteProduct(_ item: ProductListItem) async {
        _ = await performMutation {
            try productStore.deleteProduct(id: item.id)
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func performMutation(
        _ mutation: () throws -> Void
    ) async -> Bool {
        guard !isMutating else { return false }

        isMutating = true
        defer { isMutating = false }

        do {
            await Task.yield()
            try Task.checkCancellation()
            try mutation()
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        do {
            try reloadProductsFromStore()
            errorMessage = nil
        } catch {
            errorMessage = "Изменение сохранено, но список не удалось обновить. \(error.localizedDescription)"
        }
        hasLoaded = true
        return true
    }

    private func reloadProductsFromStore() throws {
        products = try productStore.fetchProductCatalog()
            .map(ProductListItem.init)
    }
}
