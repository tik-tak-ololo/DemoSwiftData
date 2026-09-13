//
//  RootView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct RootView: View {
    private let store: any ShoppingStoreProtocol

    init(store: any ShoppingStoreProtocol) {
        self.store = store
    }

    var body: some View {
        ShoppingListsView(store: store)
    }
}
