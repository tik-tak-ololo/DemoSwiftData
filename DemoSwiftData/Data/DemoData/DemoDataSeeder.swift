//
//  DemoDataSeeder.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation

@MainActor
protocol DemoDataSeeding: AnyObject {
    func seedIfNeeded() throws
}

struct DemoData {
    struct List {
        let name: String
        let iconColor: ShoppingListIconColor
        let iconDesign: ShoppingListIconDesign
        let items: [Item]
    }

    struct Item {
        let name: String
        let quantity: Int
    }

    let lists: [List]
}

@MainActor
protocol DemoDataApplying: AnyObject {
    func applyInitialDemoDataIfEmpty(_ data: DemoData) throws
}

/// Наполняет новое хранилище, не связывая демоданные с его SwiftData-реализацией.
@MainActor
final class DemoDataSeeder: DemoDataSeeding {
    private static let userDefaultsKey = "demoDataSeed"

    private let store: any DemoDataApplying
    private let userDefaults: UserDefaults?

    init(
        store: any DemoDataApplying,
        userDefaults: UserDefaults? = .standard
    ) {
        self.store = store
        self.userDefaults = userDefaults
    }

    func seedIfNeeded() throws {
        guard userDefaults?.bool(forKey: Self.userDefaultsKey) != true else { return }

        try store.applyInitialDemoDataIfEmpty(
            DemoData(
                lists: [
                    DemoData.List(
                        name: "На неделю",
                        iconColor: .blue,
                        iconDesign: .calendar,
                        items: [
                            DemoData.Item(name: "Молоко", quantity: 2),
                            DemoData.Item(name: "Хлеб", quantity: 1),
                            DemoData.Item(name: "Яблоки", quantity: 6)
                        ]
                    ),
                    DemoData.List(
                        name: "Для пикника",
                        iconColor: .mint,
                        iconDesign: .food,
                        items: [
                            DemoData.Item(name: "Вода", quantity: 3),
                            DemoData.Item(name: "Яблоки", quantity: 4)
                        ]
                    )
                ]
            )
        )
        userDefaults?.set(true, forKey: Self.userDefaultsKey)
    }
}
