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
    let demoDataSeeder: any DemoDataSeeding
}

@MainActor
enum PersistenceFactory {
    static func makeProduction() throws -> PersistenceDependencies {
        let configuration = ModelConfiguration(
            "ShoppingData",
            schema: schema
        )
        return try make(
            configuration: configuration,
            demoDataUserDefaults: .standard
        )
    }

    static func makePreview() -> PersistenceDependencies {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            return try make(
                configuration: configuration,
                demoDataUserDefaults: nil
            )
        } catch {
            fatalError("Не удалось создать preview-хранилище: \(error)")
        }
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
        let store = ShoppingStore(modelContainer: container)
        let demoDataSeeder = DemoDataSeeder(
            store: store,
            userDefaults: demoDataUserDefaults
        )
        try demoDataSeeder.seedIfNeeded()
        return PersistenceDependencies(
            shoppingStore: store,
            demoDataSeeder: demoDataSeeder
        )
    }
}
