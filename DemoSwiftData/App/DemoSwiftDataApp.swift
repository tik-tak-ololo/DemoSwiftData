//
//  DemoSwiftDataApp.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import SwiftUI

@main
struct DemoSwiftDataApp: App {
    
    private let persistence: PersistenceDependencies

    init() {
        do {
            persistence = try PersistenceFactory.makeProduction()
        } catch {
            fatalError("Не удалось создать хранилище: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                store: persistence.shoppingStore
            )
        }
    }
}
