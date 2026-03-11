import Foundation
import HealthKit

struct HealthRefreshPayload {
    let completedWorkouts: [CompletedWorkoutSummary]
    let detectedActivityTypes: [String]
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device."
        case .authorizationFailed:
            "Apple Health authorization did not complete."
        }
    }
}

@MainActor
final class HealthKitService {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationStatus() -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: HKObjectType.workoutType())
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        let workoutType = HKObjectType.workoutType()
        let readTypes: Set<HKObjectType> = [workoutType]
        let writeTypes: Set<HKSampleType> = [workoutType]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.authorizationFailed)
                }
            }
        }
    }

    func refreshWorkoutHistory() async throws -> HealthRefreshPayload {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        let workouts = try await fetchWorkouts()
        let summaries = workouts.map(Self.makeSummary(from:))
        let detectedActivityTypes = Self.detectedActivities(from: workouts)

        return HealthRefreshPayload(
            completedWorkouts: summaries,
            detectedActivityTypes: detectedActivityTypes
        )
    }

    private func fetchWorkouts() async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptors = [
                NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            ]

            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    private static func makeSummary(from workout: HKWorkout) -> CompletedWorkoutSummary {
        CompletedWorkoutSummary(
            id: UUID(),
            date: workout.startDate,
            durationMinutes: max(Int(workout.duration.rounded() / 60), 1),
            locationName: "Apple Health",
            summary: displayName(for: workout.workoutActivityType)
        )
    }

    private static func detectedActivities(from workouts: [HKWorkout]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        for workout in workouts {
            let activityType = workout.workoutActivityType

            guard !ignoredDetectedActivityTypes.contains(activityType) else {
                continue
            }

            let displayName = displayName(for: activityType)
            let key = displayName.lowercased()

            if seen.insert(key).inserted {
                results.append(displayName)
            }
        }

        return results
    }

    private static let ignoredDetectedActivityTypes: Set<HKWorkoutActivityType> = [
        .traditionalStrengthTraining,
        .functionalStrengthTraining
    ]

    private static func displayName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:
            "Running"
        case .cycling:
            "Cycling"
        case .hiking:
            "Hiking"
        case .walking:
            "Walking"
        case .swimming:
            "Swimming"
        case .rowing:
            "Rowing"
        case .yoga:
            "Yoga"
        case .mixedCardio:
            "Mixed Cardio"
        case .elliptical:
            "Elliptical"
        case .stairClimbing:
            "Stair Climbing"
        case .downhillSkiing:
            "Skiing"
        case .snowboarding:
            "Snowboarding"
        case .surfingSports:
            "Surfing"
        case .paddleSports:
            "Paddling"
        case .traditionalStrengthTraining:
            "Traditional Strength Training"
        case .functionalStrengthTraining:
            "Functional Strength Training"
        default:
            "Other Activity"
        }
    }
}

@MainActor
final class HealthSyncController: ObservableObject {
    private let healthKitService = HealthKitService()

    func refreshOnLaunch(using store: AppStore) async {
        guard healthKitService.isHealthDataAvailable else {
            store.setHealthSyncState(.failed("Health unavailable"))
            return
        }

        switch healthKitService.authorizationStatus() {
        case .notDetermined:
            store.setHealthSyncState(.notConnected)
        case .sharingDenied:
            store.setHealthSyncState(.failed("Health access denied"))
        case .sharingAuthorized:
            await refresh(using: store)
        @unknown default:
            store.setHealthSyncState(.failed("Unknown Health status"))
        }
    }

    func connectAndRefresh(using store: AppStore) async {
        do {
            store.setHealthSyncState(.refreshing)
            try await healthKitService.requestAuthorization()
            store.setHealthSyncState(.connected)
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
}
