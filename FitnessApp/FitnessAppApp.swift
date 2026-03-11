import SwiftUI
import UIKit

@main
struct FitnessAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var healthSyncController = HealthSyncController()
    private let persistenceController = PersistenceController.shared

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().isTranslucent = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .environmentObject(store)
                .environmentObject(healthSyncController)
                .task {
                    _ = persistenceController
                    store.bootstrapFromPersistence()
                    await healthSyncController.refreshOnLaunch(using: store)
                }
        }
    }
}
