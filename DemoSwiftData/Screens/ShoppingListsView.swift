//
//  ShoppingListsView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct ShoppingListsView: View {
    @State private var observed: ShoppingListsObserved

    init(store: any ShoppingStoreProtocol) {
        _observed = State(
            initialValue: ShoppingListsObserved(store: store)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    consoleButtons
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("SwiftData")
            .alert(
                "Не удалось прочитать данные",
                isPresented: isShowingError
            ) {
                Button("OK", role: .cancel) {
                    observed.dismissError()
                }
            } message: {
                Text(observed.errorMessage ?? "Неизвестная ошибка")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "cylinder.split.1x2.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Содержимое хранилища")
                .font(.title2.bold())

            Text("Нажмите кнопку, чтобы вывести выбранную таблицу в консоль Xcode.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var consoleButtons: some View {
        VStack(spacing: 12) {
            consoleButton(
                title: "ShoppingList",
                subtitle: "Списки покупок",
                systemImage: "list.bullet.rectangle.portrait.fill",
                action: observed.printShoppingLists
            )

            consoleButton(
                title: "Product",
                subtitle: "Каталог товаров",
                systemImage: "shippingbox.fill",
                action: observed.printProducts
            )

            consoleButton(
                title: "ProductMeasurementUnit",
                subtitle: "Допустимые единицы товаров",
                systemImage: "ruler.fill",
                action: observed.printProductMeasurementUnits
            )

            consoleButton(
                title: "ShoppingListItem",
                subtitle: "Позиции списков и их связи",
                systemImage: "cart.fill.badge.plus",
                action: observed.printShoppingListItems
            )
        }
    }

    private func consoleButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "terminal.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Вывести таблицу \(title) в консоль")
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { observed.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    observed.dismissError()
                }
            }
        )
    }
}

#Preview {
    ShoppingListsView(
        store: PersistenceFactory.makePreview().shoppingStore
    )
}
