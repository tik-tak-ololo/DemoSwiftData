//
//  ShoppingList.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import Foundation
import SwiftData

enum ShoppingListIconColor: String, CaseIterable, Codable {
    case blue = "#89CBE3"
    case mint = "#A8D5C7"
    case lavender = "#B6B2D8"
    case coral = "#E9A19C"
    case yellow = "#FFE29A"
}

enum ShoppingListIconDesign: String, CaseIterable, Codable {
    case snowflake
    case airplane
    case important = "exclamationmark"
    case balloon
    case bandage
    case dumbbell
    case bed = "bed.double"
    case briefcase
    case wrench = "wrench.adjustable"
    case building = "building.2"
    case calendar
    case gift
    case palette = "paintpalette"
    case cart
    case car
    case food = "takeoutbag.and.cup.and.straw"
    case paw = "pawprint"
    case game = "gamecontroller"
}

@Model
final class ShoppingList {
    /// Название списка покупок.
    private(set) var name: String
    /// Цвет значка списка.
    @Attribute(originalName: "icon_color")
    private(set) var iconColor: ShoppingListIconColor
    /// Системное имя изображения для значка списка.
    @Attribute(originalName: "icon_design")
    private(set) var iconDesign: ShoppingListIconDesign

    /// Позиции, добавленные в этот список.
    @Relationship(deleteRule: .cascade, inverse: \ShoppingListItem.shoppingList)
    private(set) var items: [ShoppingListItem]

    init(
        name: String,
        iconColor: ShoppingListIconColor,
        iconDesign: ShoppingListIconDesign
    ) throws {
        self.name = try ShoppingDomainValidation.listName(name)
        self.iconColor = iconColor
        self.iconDesign = iconDesign
        items = []
    }

    func update(
        name: String,
        iconColor: ShoppingListIconColor,
        iconDesign: ShoppingListIconDesign
    ) throws {
        self.name = try ShoppingDomainValidation.listName(name)
        self.iconColor = iconColor
        self.iconDesign = iconDesign
    }

    var sortedItems: [ShoppingListItem] {
        items.filter { !$0.isPurchased } + items.filter(\.isPurchased)
    }

    var purchasedItemsCount: Int {
        items.lazy.filter(\.isPurchased).count
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(purchasedItemsCount) / Double(items.count)
    }
}
