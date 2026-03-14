import Foundation
import HealthKit

@MainActor
final class HealthSyncController: ObservableObject {
    private let healthKitService = HealthKitService()

    var isHealthDataAvailable: Bool {
        healthKitService.isHealthDataAvailable
    }

    func authorizationStatus() -> HKAuthorizationStatus {
        healthKitService.authorizationStatus()
    }

    func refreshOnLaunch(using store: AppStore) async {
        guard healthKitService.isHealthDataAvailable else {
            store.setHealthSyncState(.failed("Health unavailable"))
            return
        }

        if healthKitService.authorizationStatus() == .notDetermined {
            store.setHealthSyncState(.notConnected)
            return
        }

        await refresh(using: store)
    }

    func connectAndRefresh(using store: AppStore) async {
        do {
            store.setHealthSyncState(.refreshing)
            try await healthKitService.requestAuthorization()
            await refresh(using: store)
        } catch {
            store.setHealthSyncState(.failed(error.localizedDescription))
            store.persist()
        }
    }

    func refresh(using store: AppStore) async {
        do {
            store.setHealthSyncState(.refreshing)
            let payload = try await healthKitService.refreshWorkoutHistory()
            store.applyHealthRefresh(
                completedWorkouts: payload.completedWorkouts,
                detectedActivityTypes: payload.detectedActivityTypes
            )
            store.setHealthSyncState(.refreshed(.now))
            store.persist()
        } catch {
            store.setHealthSyncState(.failed(error.localizedDescription))
            store.persist()
        }
    }

    func logWorkoutFromTrackSession(_ pendingWorkout: PendingTrackedWorkoutMerge, using store: AppStore) async {
        await logWorkoutFromTrackedSession(
            activityTypeName: pendingWorkout.activityType,
            startedAt: pendingWorkout.startedAt,
            completedAt: pendingWorkout.completedAt,
            using: store
        )
    }

    func logWorkoutFromTrackedSession(
        _ session: TrackedWorkoutSession,
        completedAt: Date = .now,
        using store: AppStore
    ) async {
        await logWorkoutFromTrackedSession(
            activityTypeName: session.activityType,
            startedAt: session.startedAt,
            completedAt: completedAt,
            using: store
        )
    }

    private func logWorkoutFromTrackedSession(
        activityTypeName: String,
        startedAt: Date,
        completedAt: Date,
        using store: AppStore
    ) async {
        guard healthKitService.isHealthDataAvailable else { return }

        do {
            try await healthKitService.saveWorkout(
                activityTypeName: activityTypeName,
                startDate: startedAt,
                endDate: completedAt,
                totalEnergyBurnedKilocalories: nil
            )
            await refresh(using: store)
        } catch {
            store.setHealthSyncState(.failed(error.localizedDescription))
            store.persist()
        }
    }
}
