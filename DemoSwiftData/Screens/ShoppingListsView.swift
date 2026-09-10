//
//  ShoppingListsView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct ShoppingListsView: View {
    let observed: ShoppingListsObserved

    var body: some View {
        @Bindable var observed = observed

        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }


}
