//
//  RootView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct RootView: View {
    private let store: any ShoppingStoreProtocol
    private let demoDataSeeder: any DemoDataSeeding

    init(
        store: any ShoppingStoreProtocol,
        demoDataSeeder: any DemoDataSeeding
    ) {
        self.store = store
        self.demoDataSeeder = demoDataSeeder
    }

    var body: some View {
        ShoppingListsView(
            store: store,
            demoDataSeeder: demoDataSeeder
        )
    }
}
