//
//  RootView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct RootView: View {
    private let shoppingStore: any ShoppingStoreProtocol
    private let productStore: any ProductStoreProtocol
    private let demoDataSeeder: any DemoDataSeeding

    init(
        shoppingStore: any ShoppingStoreProtocol,
        productStore: any ProductStoreProtocol,
        demoDataSeeder: any DemoDataSeeding
    ) {
        self.shoppingStore = shoppingStore
        self.productStore = productStore
        self.demoDataSeeder = demoDataSeeder
    }

    var body: some View {
        TabView {
            CRUDDemoView(
                shoppingStore: shoppingStore,
                productStore: productStore,
                demoDataSeeder: demoDataSeeder
            )
            .tabItem {
                Label("CRUD", systemImage: "cylinder.split.1x2")
            }

            ProductsView(productStore: productStore)
                .tabItem {
                    Label("Товары", systemImage: "shippingbox")
                }
        }
    }
}
