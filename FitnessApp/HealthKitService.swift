import Foundation
import HealthKit

struct WorkoutActivityCatalog {
    struct ActivityOption: Identifiable, Hashable {
        let healthKitType: HKWorkoutActivityType
        let title: String

        var id: Int { Int(healthKitType.rawValue) }
    }

    static let all: [ActivityOption] = [
        option(.americanFootball, "American Football"),
        option(.archery, "Archery"),
        option(.australianFootball, "Australian Football"),
        option(.badminton, "Badminton"),
        option(.baseball, "Baseball"),
        option(.basketball, "Basketball"),
        option(.bowling, "Bowling"),
        option(.boxing, "Boxing"),
        option(.climbing, "Climbing"),
        option(.cricket, "Cricket"),
        option(.crossTraining, "Cross Training"),
        option(.curling, "Curling"),
        option(.cycling, "Cycling"),
        option(.elliptical, "Elliptical"),
        option(.equestrianSports, "Equestrian Sports"),
        option(.fencing, "Fencing"),
        option(.fishing, "Fishing"),
        option(.functionalStrengthTraining, "Functional Strength Training"),
        option(.golf, "Golf"),
        option(.gymnastics, "Gymnastics"),
        option(.handball, "Handball"),
        option(.hiking, "Hiking"),
        option(.hockey, "Hockey"),
        option(.hunting, "Hunting"),
        option(.lacrosse, "Lacrosse"),
        option(.martialArts, "Martial Arts"),
        option(.mindAndBody, "Mind and Body"),
        option(.paddleSports, "Paddle Sports"),
        option(.play, "Play"),
        option(.preparationAndRecovery, "Preparation and Recovery"),
        option(.racquetball, "Racquetball"),
        option(.rowing, "Rowing"),
        option(.rugby, "Rugby"),
        option(.running, "Running"),
        option(.sailing, "Sailing"),
        option(.skatingSports, "Skating Sports"),
        option(.snowSports, "Snow Sports"),
        option(.soccer, "Soccer"),
        option(.softball, "Softball"),
        option(.squash, "Squash"),
        option(.stairClimbing, "Stair Climbing"),
        option(.surfingSports, "Surfing Sports"),
        option(.swimming, "Swimming"),
        option(.tableTennis, "Table Tennis"),
        option(.tennis, "Tennis"),
        option(.trackAndField, "Track and Field"),
        option(.traditionalStrengthTraining, "Traditional Strength Training"),
        option(.volleyball, "Volleyball"),
        option(.walking, "Walking"),
        option(.waterFitness, "Water Fitness"),
        option(.waterPolo, "Water Polo"),
        option(.waterSports, "Water Sports"),
        option(.wrestling, "Wrestling"),
        option(.yoga, "Yoga"),
        option(.barre, "Barre"),
        option(.coreTraining, "Core Training"),
        option(.crossCountrySkiing, "Cross Country Skiing"),
        option(.downhillSkiing, "Downhill Skiing"),
        option(.flexibility, "Flexibility"),
        option(.highIntensityIntervalTraining, "High Intensity Interval Training"),
        option(.jumpRope, "Jump Rope"),
        option(.kickboxing, "Kickboxing"),
        option(.pilates, "Pilates"),
        option(.snowboarding, "Snowboarding"),
        option(.stairs, "Stairs"),
        option(.stepTraining, "Step Training"),
        option(.wheelchairWalkPace, "Wheelchair Walk Pace"),
        option(.wheelchairRunPace, "Wheelchair Run Pace"),
        option(.taiChi, "Tai Chi"),
        option(.mixedCardio, "Mixed Cardio"),
        option(.handCycling, "Hand Cycling"),
        option(.discSports, "Disc Sports"),
        option(.fitnessGaming, "Fitness Gaming"),
        option(.cardioDance, "Cardio Dance"),
        option(.socialDance, "Social Dance"),
        option(.pickleball, "Pickleball"),
        option(.cooldown, "Cooldown"),
        option(.swimBikeRun, "Swim Bike Run"),
        option(.transition, "Transition"),
        option(.underwaterDiving, "Underwater Diving"),
        option(.other, "Other")
    ]

    static let titles: [String] = all.map(\.title)

    static func activityType(forTitle title: String) -> HKWorkoutActivityType? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return all.first(where: {
            $0.title.caseInsensitiveCompare(trimmed) == .orderedSame
        })?.healthKitType
    }

    static func displayName(for activityType: HKWorkoutActivityType) -> String {
        all.first(where: { $0.healthKitType == activityType })?.title ?? "Other"
    }

    private static func option(_ type: HKWorkoutActivityType, _ title: String) -> ActivityOption {
        ActivityOption(healthKitType: type, title: title)
    }
}

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

    func saveWorkout(
        activityTypeName: String,
        startDate: Date,
        endDate: Date,
        totalEnergyBurnedKilocalories: Double? = nil
    ) async throws {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        guard let activityType = WorkoutActivityCatalog.activityType(forTitle: activityTypeName) else {
            return
        }

        let energyQuantity: HKQuantity?
        if let totalEnergyBurnedKilocalories {
            energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: totalEnergyBurnedKilocalories)
        } else {
            energyQuantity = nil
        }

        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            workoutEvents: nil,
            totalEnergyBurned: energyQuantity,
            totalDistance: nil,
            metadata: nil
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(workout) { success, error in
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

    private static func makeSummary(from workout: HKWorkout) -> CompletedWorkoutSummary {
        let activityType = displayName(for: workout.workoutActivityType)
        return CompletedWorkoutSummary(
            id: workout.uuid,
            date: workout.startDate,
            durationMinutes: max(Int(workout.duration.rounded() / 60), 1),
            locationName: "",
            activityType: activityType,
            summary: activityType
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
        WorkoutActivityCatalog.displayName(for: activityType)
    }
}

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
