//
//  DemoSwiftDataApp.swift
//  DemoSwiftData
//
//  Created by Сергей Хмелёв on 10.09.2026.
//

import SwiftUI

@MainActor
@Observable
private final class PersistenceBootstrap {
    private(set) var persistence: PersistenceDependencies?
    private(set) var errorMessage: String?

    init() {
        load()
    }

    func load() {
        do {
            persistence = try PersistenceFactory.makeProduction()
            errorMessage = nil
        } catch {
            persistence = nil
            errorMessage = error.localizedDescription
        }
    }

    func recreateStore() {
        do {
            persistence = try PersistenceFactory.recreateProductionStore()
            errorMessage = nil
        } catch {
            persistence = nil
            errorMessage = error.localizedDescription
        }
    }
}

@main
struct DemoSwiftDataApp: App {
    @State private var bootstrap = PersistenceBootstrap()

    var body: some Scene {
        WindowGroup {
            PersistenceRootView(bootstrap: bootstrap)
        }
    }
}

private struct PersistenceRootView: View {
    let bootstrap: PersistenceBootstrap
    @State private var isShowingRecreateConfirmation = false

    var body: some View {
        Group {
            if let persistence = bootstrap.persistence {
                RootView(
                    shoppingStore: persistence.shoppingStore,
                    productStore: persistence.productStore,
                    demoDataSeeder: persistence.demoDataSeeder
                )
            } else {
                recoveryView
            }
        }
        .confirmationDialog(
            "Пересоздать локальное хранилище?",
            isPresented: $isShowingRecreateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Пересоздать", role: .destructive) {
                bootstrap.recreateStore()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Текущая тестовая база будет удалена и заполнена начальными демо-данными.")
        }
    }

    private var recoveryView: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Хранилище недоступно", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(bootstrap.errorMessage ?? "Не удалось открыть локальную базу данных.")
            } actions: {
                VStack(spacing: 12) {
                    Button("Повторить") {
                        bootstrap.load()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Пересоздать базу", role: .destructive) {
                        isShowingRecreateConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
