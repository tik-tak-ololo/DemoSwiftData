//
//  ProductMeasurementUnit.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 13.09.2026.
//

import Foundation
import SwiftData

/// Основные единицы измерения, используемые для покупок в России.
enum MeasurementUnit: String, CaseIterable, Codable {
    case piece = "штуки"
    case kilogram = "килограммы"
    case gram = "граммы"
    case liter = "литры"
    case milliliter = "миллилитры"
    case meter = "метры"
    case centimeter = "сантиметры"
    case squareMeter = "квадратные метры"
    case cubicMeter = "кубические метры"
    case package = "упаковки"
}

/// Допустимая единица измерения конкретного товара.
///
/// Один товар может иметь несколько таких записей, например молоко — литры
/// и миллилитры. При удалении товара его единицы удаляются каскадно.
@Model
final class ProductMeasurementUnit {
    /// Единица измерения, поддерживаемая товаром.
    private(set) var unit: MeasurementUnit
    /// Используется ли единица по умолчанию для связанного товара.
    private(set) var isDefault: Bool
    /// Товар, которому доступна эта единица измерения.
    private(set) var product: Product?

    init(unit: MeasurementUnit, product: Product) {
        self.unit = unit
        isDefault = false
        self.product = product
    }

    func changeUnit(to unit: MeasurementUnit) {
        self.unit = unit
    }

    /// Назначает текущую единицу основной и одновременно снимает признак
    /// со всех остальных единиц того же товара.
    func makeDefault() {
        guard let product else { return }

        for measurementUnit in product.measurementUnits {
            measurementUnit.isDefault = measurementUnit === self
        }
    }
}
