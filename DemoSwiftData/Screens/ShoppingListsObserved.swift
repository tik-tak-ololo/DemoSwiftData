//
//  ShoppingListsObserved.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShoppingListsObserved {
    private(set) var shoppingLists: [ShoppingList]
    var isPresentingNewList = false
    var newListName = ""
    var errorMessage: String?

    @ObservationIgnored private let store: any ShoppingStoreProtocol

    init(store: any ShoppingStoreProtocol) {
        self.store = store
        shoppingLists = store.shoppingLists
    }

    func dismissError() {
        errorMessage = nil
    }


}
