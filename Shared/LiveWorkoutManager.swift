#if os(watchOS)
import Foundation
import HealthKit

@MainActor
final class LiveWorkoutManager: NSObject, ObservableObject {
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var basalCalories: Double = 0
    var totalCalories: Double { activeCalories + basalCalories }
    @Published var elapsedSeconds: Int = 0
    @Published var isRunning: Bool = false

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var timer: Timer?

    private let healthKitService = HealthKitService()

    func start(activityTypeName: String) throws {
        let (session, builder) = try healthKitService.startLiveWorkout(activityTypeName: activityTypeName)
        self.session = session
        self.builder = builder

        session.delegate = self
        builder.delegate = self

        let now = Date()
        self.startDate = now
        self.isRunning = true

        session.startActivity(with: now)
        Task { try await builder.beginCollection(at: now) }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.startDate else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    /// Ends the session and returns the start and end dates.
    /// `HKLiveWorkoutBuilder.finishWorkout()` saves the workout to HealthKit automatically —
    /// no manual `saveWorkout()` call is needed after this.
    func stop() async throws -> (startDate: Date, endDate: Date) {
        timer?.invalidate()
        timer = nil
        isRunning = false

        let end = Date()
        session?.end()
        try await builder?.endCollection(at: end)
        try await builder?.finishWorkout()

        return (startDate ?? end, end)
    }

    /// Ends the session without saving to HealthKit. Use when the user cancels or completes no exercises.
    func endWithoutSaving() async throws {
        timer?.invalidate()
        timer = nil
        isRunning = false

        let end = Date()
        session?.end()
        try await builder?.endCollection(at: end)
        // Do not call finishWorkout() — workout is not written to HealthKit
    }
}

extension LiveWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)

            Task { @MainActor in
                switch quantityType {
                case HKQuantityType(.heartRate):
                    self.heartRate = stats?.mostRecentQuantity()?
                        .doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                case HKQuantityType(.activeEnergyBurned):
                    self.activeCalories = stats?.sumQuantity()?
                        .doubleValue(for: .kilocalorie()) ?? 0
                case HKQuantityType(.basalEnergyBurned):
                    self.basalCalories = stats?.sumQuantity()?
                        .doubleValue(for: .kilocalorie()) ?? 0
                default:
                    break
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension LiveWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ session: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ session: HKWorkoutSession,
        didFailWithError error: Error
    ) {}
}
#endif
