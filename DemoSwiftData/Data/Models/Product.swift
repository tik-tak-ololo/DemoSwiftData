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
    private(set) var name: String
    @Attribute(.unique) private(set) var normalizedName: String
    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.product)
    var listItems: [ShoppingListItem]

    init(name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedName = Self.normalize(name)
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
