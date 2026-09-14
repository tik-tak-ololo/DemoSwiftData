//
//  ProductsView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 14.09.2026.
//

import SwiftUI

struct ProductsView: View {
    private struct EditorConfiguration: Identifiable {
        let id = UUID()
        let product: ProductListItem?
    }

    @State private var observed: ProductsObserved
    @State private var searchText = ""
    @State private var editorConfiguration: EditorConfiguration?
    @State private var productPendingDeletion: ProductListItem?

    init(productStore: any ProductStoreProtocol) {
        _observed = State(
            initialValue: ProductsObserved(productStore: productStore)
        )
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Список товаров")
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Найти товар"
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        addButton
                    }
                }
                .overlay(alignment: .top) {
                    if observed.isMutating {
                        ProgressView()
                            .padding(10)
                            .background(.regularMaterial, in: .capsule)
                            .padding(.top, 8)
                    }
                }
        }
        .task {
            await observed.loadProducts()
        }
        .sheet(item: $editorConfiguration) { configuration in
            ProductEditorView(
                product: configuration.product,
                observed: observed
            )
        }
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
            deletionTitle,
            isPresented: isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                deletePendingProduct()
            }
            Button("Отмена", role: .cancel) {
                productPendingDeletion = nil
            }
        } message: {
            Text(deletionMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        if observed.isLoading && !observed.hasLoaded {
            ProgressView("Загружаем товары…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !observed.hasLoaded {
            loadFailureView
        } else if observed.products.isEmpty {
            emptyProductsView
        } else if filteredProducts.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            productsList
        }
    }

    private var productsList: some View {
        List(filteredProducts) { product in
            Button {
                editorConfiguration = EditorConfiguration(product: product)
            } label: {
                ProductRowView(product: product)
            }
            .buttonStyle(.plain)
            .disabled(observed.isBusy)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    productPendingDeletion = product
                }
            }
            .accessibilityHint("Открывает редактирование товара")
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await observed.loadProducts()
        }
    }

    private var loadFailureView: some View {
        ContentUnavailableView {
            Label(
                "Не удалось загрузить товары",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(observed.errorMessage ?? "Неизвестная ошибка")
        } actions: {
            Button("Повторить") {
                Task {
                    await observed.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyProductsView: some View {
        ContentUnavailableView {
            Label("Товаров пока нет", systemImage: "shippingbox")
        } description: {
            Text("Добавьте первый товар и выберите доступные единицы измерения.")
        } actions: {
            Button("Добавить товар", systemImage: "plus") {
                editorConfiguration = EditorConfiguration(product: nil)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var addButton: some View {
        Button {
            editorConfiguration = EditorConfiguration(product: nil)
        } label: {
            Label("Добавить товар", systemImage: "plus")
        }
        .disabled(observed.isBusy)
    }

    private var filteredProducts: [ProductListItem] {
        guard !searchText.isEmpty else { return observed.products }
        return observed.products.filter { product in
            product.name.localizedStandardContains(searchText)
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: {
                editorConfiguration == nil &&
                    observed.hasLoaded &&
                    observed.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    observed.dismissError()
                }
            }
        )
    }

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { productPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    productPendingDeletion = nil
                }
            }
        )
    }

    private var deletionTitle: String {
        guard let productPendingDeletion else { return "Удалить товар?" }
        return "Удалить «\(productPendingDeletion.name)»?"
    }

    private var deletionMessage: String {
        guard let productPendingDeletion else { return "" }
        let count = productPendingDeletion.shoppingListItemsCount
        guard count > 0 else {
            return "Товар и его единицы измерения будут удалены."
        }
        return "Вместе с товаром будут удалены позиции в списках: \(count)."
    }

    private func deletePendingProduct() {
        guard let product = productPendingDeletion else { return }
        productPendingDeletion = nil

        Task {
            await observed.deleteProduct(product)
        }
    }
}

private struct ProductRowView: View {
    let product: ProductListItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.headline)

                Text(measurementUnitsDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if product.shoppingListItemsCount > 0 {
                    Label(
                        "Позиций в списках: \(product.shoppingListItemsCount)",
                        systemImage: "list.bullet"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private var measurementUnitsDescription: String {
        product.measurementUnits.map { unit in
            unit == product.defaultMeasurementUnit
                ? "\(unit.rawValue) · основная"
                : unit.rawValue
        }
        .joined(separator: ", ")
    }
}

#Preview {
    switch Result(catching: PersistenceFactory.makePreview) {
    case let .success(persistence):
        ProductsView(productStore: persistence.productStore)
    case let .failure(error):
        ContentUnavailableView(
            "Preview недоступен",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
    }
}
