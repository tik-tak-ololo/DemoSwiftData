//
//  RootView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct RootView: View {
    @State private var observed: ShoppingListsObserved

    init(store: any ShoppingStoreProtocol) {
        _observed = State(
            initialValue: ShoppingListsObserved(
                store: store
            )
        )
    }

    var body: some View {
        ShoppingListsView(observed: observed)
    }
}

#Preview {
    let persistence = PersistenceFactory.makePreview()
    RootView(store: persistence.shoppingStore)
}
