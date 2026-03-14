import SwiftUI
import UIKit
import WatchConnectivity

@main
struct FitnessAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var healthSyncController = HealthSyncController()
    @StateObject private var watchSyncController = WatchSyncController()
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
                    watchSyncController.start(using: store, healthSyncController: healthSyncController)
                    await healthSyncController.refreshOnLaunch(using: store)
                }
        }
    }
}

private enum WatchWorkoutPayload {
    static let key = "watchWorkout"
    static let id = "id"
    static let activityType = "activityType"
    static let completedAtTimestamp = "completedAtTimestamp"
    static let durationSeconds = "durationSeconds"
    static let exercises = "exercises"
}

private enum WatchWorkoutAck {
    static let key = "watchWorkoutAck"
}

private enum ProcessedWatchWorkoutIds {
    static let userDefaultsKey = "fitness.processedWatchWorkoutIds"
    static let maxStored = 500

    static func contains(_ id: String) -> Bool {
        load().contains(id)
    }

    static func add(_ id: String) {
        var ids = load()
        if !ids.contains(id) {
            ids.append(id)
            if ids.count > maxStored {
                ids = Array(ids.suffix(maxStored))
            }
            UserDefaults.standard.set(ids, forKey: userDefaultsKey)
        }
    }

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
}

@MainActor
final class WatchSyncController: NSObject, ObservableObject {
    private var store: AppStore?
    private weak var healthSyncController: HealthSyncController?

    func start(using store: AppStore, healthSyncController: HealthSyncController) {
        self.store = store
        self.healthSyncController = healthSyncController

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        sendSnapshot(store.snapshot)
    }

    func sendSnapshot(_ snapshot: AppSnapshot) {
        guard WCSession.isSupported() else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else { return }

        do {
            try WCSession.default.updateApplicationContext(["snapshot": data])
        } catch {
            // Best-effort sync; ignore failures for now.
        }
    }
}

extension WatchSyncController: WCSessionDelegate {
    nonisolated(unsafe) func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated(unsafe) func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated(unsafe) func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }

        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return }
            self.sendSnapshot(store.snapshot)
        }
    }

    nonisolated(unsafe) func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        // Phone is the source of truth; ignore incoming contexts.
    }

    nonisolated(unsafe) func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let workoutPayload = userInfo[WatchWorkoutPayload.key] as? [String: Any],
              let watchWorkoutId = workoutPayload[WatchWorkoutPayload.id] as? String,
              let activityType = workoutPayload[WatchWorkoutPayload.activityType] as? String,
              let completedAtTimestamp = workoutPayload[WatchWorkoutPayload.completedAtTimestamp] as? TimeInterval,
              let durationSeconds = workoutPayload[WatchWorkoutPayload.durationSeconds] as? TimeInterval
        else { return }

        if ProcessedWatchWorkoutIds.contains(watchWorkoutId) {
            Task { @MainActor in
                self.sendAckToWatch(watchWorkoutId: watchWorkoutId)
            }
            return
        }

        let completedAt = Date(timeIntervalSince1970: completedAtTimestamp)
        let durationMinutes = max(Int((durationSeconds / 60).rounded()), 1)
        let startedAt = completedAt.addingTimeInterval(-durationSeconds)

        let exerciseDetails: [CompletedExerciseDetail] = (workoutPayload[WatchWorkoutPayload.exercises] as? [[String: Any]])?
            .compactMap { dict -> CompletedExerciseDetail? in
                guard let title = dict["title"] as? String else { return nil }
                return CompletedExerciseDetail(
                    id: UUID(),
                    title: title,
                    bodyPart: nil,
                    sets: nil,
                    reps: nil,
                    notes: ""
                )
            } ?? []

        let pending = PendingTrackedWorkoutMerge(
            id: UUID(),
            startedAt: startedAt,
            completedAt: completedAt,
            durationMinutes: durationMinutes,
            locationName: "",
            activityType: activityType,
            summary: "",
            exerciseDetails: exerciseDetails
        )

        Task { @MainActor in
            guard let store = self.store, let healthSyncController = self.healthSyncController else { return }
            store.addPendingTrackedWorkout(pending)
            await healthSyncController.logWorkoutFromTrackSession(pending, using: store)
            store.persist()
            ProcessedWatchWorkoutIds.add(watchWorkoutId)
            self.sendAckToWatch(watchWorkoutId: watchWorkoutId)
        }
    }

    private func sendAckToWatch(watchWorkoutId: String) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo([WatchWorkoutAck.key: watchWorkoutId])
    }
}

