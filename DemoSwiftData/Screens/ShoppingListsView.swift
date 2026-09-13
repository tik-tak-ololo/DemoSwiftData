//
//  ShoppingListsView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 11.09.2026.
//

import SwiftUI

struct ShoppingListsView: View {
    private enum Entity: String {
        case shoppingList = "ShoppingList"
        case product = "Product"
        case productMeasurementUnit = "ProductMeasurementUnit"
        case shoppingListItem = "ShoppingListItem"
    }

    @State private var observed: ShoppingListsObserved
    @State private var isShowingResetConfirmation = false
    @State private var pendingDeletion: Entity?

    init(
        shoppingStore: any ShoppingStoreProtocol,
        productStore: any ProductStoreProtocol,
        demoDataSeeder: any DemoDataSeeding
    ) {
        _observed = State(
            initialValue: ShoppingListsObserved(
                shoppingStore: shoppingStore,
                productStore: productStore,
                demoDataSeeder: demoDataSeeder
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    crudSections
                    resetDemoDataButton

                    if let statusMessage = observed.statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("SwiftData")
            .alert(
                "Не удалось выполнить операцию",
                isPresented: isShowingError
            ) {
                Button("OK", role: .cancel) {
                    observed.dismissError()
                }
            } message: {
                Text(observed.errorMessage ?? "Неизвестная ошибка")
            }
            .confirmationDialog(
                "Сбросить хранилище?",
                isPresented: $isShowingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Сбросить", role: .destructive) {
                    observed.resetDemoData()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все текущие записи будут удалены и заменены начальными демо-данными.")
            }
            .confirmationDialog(
                "Удалить запись \(pendingDeletion?.rawValue ?? "")?",
                isPresented: isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    performPendingDeletion()
                }
                Button("Отмена", role: .cancel) {
                    pendingDeletion = nil
                }
            } message: {
                Text("Будет удалена подходящая запись выбранной таблицы. Связанные данные обрабатываются по правилам SwiftData.")
            }
        }
    }

    private var resetDemoDataButton: some View {
        VStack(spacing: 10) {
            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                Label("Восстановить демо-данные", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Удаляет текущие записи и возвращает начальные демо-данные")
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

            Text("Выполняйте CRUD-операции с таблицами SwiftData. Результат каждой операции выводится в консоль Xcode.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var crudSections: some View {
        VStack(spacing: 16) {
            crudSection(
                title: "ShoppingList",
                subtitle: "Списки покупок",
                systemImage: "list.bullet.rectangle.portrait.fill",
                read: observed.printShoppingLists,
                create: observed.createShoppingList,
                update: observed.updateShoppingList,
                delete: { pendingDeletion = .shoppingList }
            )

            crudSection(
                title: "Product",
                subtitle: "Каталог товаров",
                systemImage: "shippingbox.fill",
                read: observed.printProducts,
                create: observed.createProduct,
                update: observed.updateProduct,
                delete: { pendingDeletion = .product }
            )

            crudSection(
                title: "ProductMeasurementUnit",
                subtitle: "Допустимые единицы товаров",
                systemImage: "ruler.fill",
                read: observed.printProductMeasurementUnits,
                create: observed.createProductMeasurementUnit,
                update: observed.updateProductMeasurementUnit,
                delete: { pendingDeletion = .productMeasurementUnit }
            )

            crudSection(
                title: "ShoppingListItem",
                subtitle: "Позиции списков и их связи",
                systemImage: "cart.fill.badge.plus",
                read: observed.printShoppingListItems,
                create: observed.createShoppingListItem,
                update: observed.updateShoppingListItem,
                delete: { pendingDeletion = .shoppingListItem }
            )
        }
    }

    private func crudSection(
        title: String,
        subtitle: String,
        systemImage: String,
        read: @escaping () -> Void,
        create: @escaping () -> Void,
        update: @escaping () -> Void,
        delete: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
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
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                crudButton(
                    title: "Получить",
                    systemImage: "terminal.fill",
                    action: read
                )
                crudButton(
                    title: "Создать",
                    systemImage: "plus.circle.fill",
                    action: create
                )
                crudButton(
                    title: "Обновить",
                    systemImage: "pencil.circle.fill",
                    action: update
                )
                crudButton(
                    title: "Удалить",
                    systemImage: "trash.fill",
                    role: .destructive,
                    action: delete
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private func crudButton(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletion = nil
                }
            }
        )
    }

    private func performPendingDeletion() {
        defer { pendingDeletion = nil }

        switch pendingDeletion {
        case .shoppingList:
            observed.deleteShoppingList()
        case .product:
            observed.deleteProduct()
        case .productMeasurementUnit:
            observed.deleteProductMeasurementUnit()
        case .shoppingListItem:
            observed.deleteShoppingListItem()
        case nil:
            break
        }
    }
}

#Preview {
    let persistence = PersistenceFactory.makePreview()
    ShoppingListsView(
        shoppingStore: persistence.shoppingStore,
        productStore: persistence.productStore,
        demoDataSeeder: persistence.demoDataSeeder
    )
}
