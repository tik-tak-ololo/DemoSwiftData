//
//  Product.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

@Model
final class Product {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedName: String
    var name: String
    var symbolName: String

    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.product)
    var listItems: [ShoppingListItem]

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "cart.fill"
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedName = Self.normalize(name)
        self.symbolName = symbolName
        listItems = []
    }

    static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
