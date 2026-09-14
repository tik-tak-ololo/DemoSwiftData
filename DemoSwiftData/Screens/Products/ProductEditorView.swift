//
//  ProductEditorView.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 14.09.2026.
//

import SwiftUI

struct ProductEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let product: ProductListItem?
    private let observed: ProductsObserved

    @State private var name: String
    @State private var selectedUnits: Set<MeasurementUnit>
    @State private var defaultMeasurementUnit: MeasurementUnit
    @State private var isSubmitting = false
    @State private var submissionError: String?
    @FocusState private var isNameFocused: Bool

    init(
        product: ProductListItem?,
        observed: ProductsObserved
    ) {
        self.product = product
        self.observed = observed
        let initialUnits = Set(product?.measurementUnits ?? [.piece])
        let firstUnit = MeasurementUnit.allCases.first(where: initialUnits.contains) ?? .piece
        _name = State(initialValue: product?.name ?? "")
        _selectedUnits = State(initialValue: initialUnits)
        _defaultMeasurementUnit = State(
            initialValue: product?.defaultMeasurementUnit ?? firstUnit
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, молоко", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                }

                Section {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        measurementUnitButton(unit)
                    }
                } header: {
                    Text("Единицы измерения")
                } footer: {
                    Text("Выберите хотя бы одну единицу, доступную для товара.")
                }

                Section {
                    if selectedUnits.isEmpty {
                        Label(
                            "Сначала выберите единицу измерения",
                            systemImage: "info.circle"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Picker(
                            "Основная единица",
                            selection: $defaultMeasurementUnit
                        ) {
                            ForEach(selectedUnitsInDisplayOrder, id: \.self) { unit in
                                Text(unit.rawValue.capitalized)
                                    .tag(unit)
                            }
                        }
                    }
                } header: {
                    Text("Основная единица")
                } footer: {
                    Text("Она используется для товара по умолчанию.")
                }
            }
            .navigationTitle(product == nil ? "Новый товар" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        submit()
                    }
                    .disabled(!canSubmit)
                }
            }
            .alert(
                "Не удалось сохранить товар",
                isPresented: isShowingSubmissionError
            ) {
                Button("OK", role: .cancel) {
                    submissionError = nil
                }
            } message: {
                Text(submissionError ?? "Неизвестная ошибка")
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
        .task {
            guard product == nil else { return }
            isNameFocused = true
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !selectedUnits.isEmpty &&
            selectedUnits.contains(defaultMeasurementUnit) &&
            !isSubmitting
    }

    private var selectedUnitsInDisplayOrder: [MeasurementUnit] {
        MeasurementUnit.allCases.filter(selectedUnits.contains)
    }

    private var isShowingSubmissionError: Binding<Bool> {
        Binding(
            get: { submissionError != nil },
            set: { isPresented in
                if !isPresented {
                    submissionError = nil
                }
            }
        )
    }

    private func measurementUnitButton(_ unit: MeasurementUnit) -> some View {
        Button {
            toggle(unit)
        } label: {
            HStack {
                Text(unit.rawValue.capitalized)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedUnits.contains(unit) {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedUnits.contains(unit) ? "Выбрано" : "Не выбрано")
    }

    private func toggle(_ unit: MeasurementUnit) {
        if selectedUnits.contains(unit) {
            selectedUnits.remove(unit)
            if unit == defaultMeasurementUnit,
               let replacement = selectedUnitsInDisplayOrder.first {
                defaultMeasurementUnit = replacement
            }
        } else {
            let wasEmpty = selectedUnits.isEmpty
            selectedUnits.insert(unit)
            if wasEmpty {
                defaultMeasurementUnit = unit
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }

        isSubmitting = true
        Task {
            let succeeded: Bool
            if let product {
                succeeded = await observed.updateProduct(
                    product,
                    name: name,
                    measurementUnits: selectedUnits,
                    defaultMeasurementUnit: defaultMeasurementUnit
                )
            } else {
                succeeded = await observed.createProduct(
                    named: name,
                    measurementUnits: selectedUnits,
                    defaultMeasurementUnit: defaultMeasurementUnit
                )
            }

            isSubmitting = false
            if succeeded {
                dismiss()
            } else {
                submissionError = observed.errorMessage ?? "Неизвестная ошибка"
                observed.dismissError()
            }
        }
    }
}
