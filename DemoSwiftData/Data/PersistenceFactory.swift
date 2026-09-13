//
//  PersistenceFactory.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation
import SwiftData

struct PersistenceDependencies {
    let shoppingStore: any ShoppingStoreProtocol
    let productStore: any ProductStoreProtocol
    let demoDataSeeder: any DemoDataSeeding
}

@MainActor
enum PersistenceFactory {
    static func makeProduction() throws -> PersistenceDependencies {
        return try make(
            configuration: productionConfiguration,
            demoDataUserDefaults: .standard
        )
    }

    static func recreateProductionStore() throws -> PersistenceDependencies {
        let configuration = productionConfiguration
        try removeStoreFiles(for: configuration)
        DemoDataSeeder.resetSeedingState(in: .standard)
        return try make(
            configuration: configuration,
            demoDataUserDefaults: .standard
        )
    }

    static func makePreview() throws -> PersistenceDependencies {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try make(
            configuration: configuration,
            demoDataUserDefaults: nil
        )
    }

    private static var productionConfiguration: ModelConfiguration {
        ModelConfiguration(
            "ShoppingData",
            schema: schema
        )
    }

    private static var schema: Schema {
        Schema([
            ShoppingList.self,
            Product.self,
            ProductMeasurementUnit.self,
            ShoppingListItem.self
        ])
    }

    private static func make(
        configuration: ModelConfiguration,
        demoDataUserDefaults: UserDefaults?
    ) throws -> PersistenceDependencies {
        let container = try ModelContainer(
            for: schema,
            configurations: configuration
        )
        // Stores use a replaceable shared context. This lets a full reset
        // discard every registered (and now invalidated) model instance.
        let modelContext = ModelContext(container)
        let productStore = ProductStore(
            modelContainer: container,
            modelContext: modelContext
        )
        let shoppingStore = ShoppingStore(
            modelContainer: container,
            modelContext: modelContext,
            productStore: productStore
        )
        let demoDataSeeder = DemoDataSeeder(
            store: shoppingStore,
            userDefaults: demoDataUserDefaults
        )
        try demoDataSeeder.seedIfNeeded()
        return PersistenceDependencies(
            shoppingStore: shoppingStore,
            productStore: productStore,
            demoDataSeeder: demoDataSeeder
        )
    }

    private static func removeStoreFiles(
        for configuration: ModelConfiguration
    ) throws {
        let storeURL = configuration.url
        let sidecarURLs = ["-wal", "-shm", "-journal"].map { suffix in
            URL(fileURLWithPath: storeURL.path + suffix)
        }

        let existingURLs = (sidecarURLs + [storeURL]).filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
        for url in existingURLs {
            try FileManager.default.removeItem(at: url)
        }
    }
}
