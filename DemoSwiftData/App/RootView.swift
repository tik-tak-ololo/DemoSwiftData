//
//  RootView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct RootView: View {

    init(store: any ShoppingStoreProtocol) {

    }

    var body: some View {
        ShoppingListsView()
    }
}
