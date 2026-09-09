//
//  ShoppingList.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

@Model
final class ShoppingList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.shoppingList)
    var items: [ShoppingListItem]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        items = []
    }

    var sortedItems: [ShoppingListItem] {
        items.sorted {
            if $0.isPurchased != $1.isPurchased {
                return !$0.isPurchased
            }
            return $0.createdAt < $1.createdAt
        }
    }

    var purchasedItemsCount: Int {
        items.lazy.filter(\.isPurchased).count
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(purchasedItemsCount) / Double(items.count)
    }
}
