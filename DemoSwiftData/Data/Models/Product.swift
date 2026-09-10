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
    @Attribute(.unique) private(set) var normalizedName: String
    private(set) var name: String
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
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    func rename(to name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedName = Self.normalize(name)
    }
}
