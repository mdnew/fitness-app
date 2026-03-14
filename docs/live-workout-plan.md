# Live Workout Session — Implementation Plan

## Goal

Replace the current post-workout HealthKit save with a live `HKWorkoutSession` +
`HKLiveWorkoutBuilder` approach on both iPhone and Apple Watch. This enables real-time
Activity ring updates, heart rate display, and calorie tracking during a workout.

---

## Context

- The project uses XcodeGen (`project.yml`) to generate `FitnessApp.xcodeproj`
- `HealthKitService.swift` lives in `FitnessApp/` and is the only HealthKit interface
- The Watch extension is `FitnessWatchAppExtension`, sources in `FitnessWatchApp/`
- Shared code lives in `Shared/`
- After making all changes, run XcodeGen to regenerate the project:
  ```sh
  ".tools/XcodeGen/.build/arm64-apple-macosx/debug/xcodegen" generate
  ```

---

## Change 1 — Create Watch entitlements file

**Create** `FitnessWatchApp/FitnessWatchApp.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
</dict>
</plist>
```

---

## Change 2 — Wire Watch entitlements in `project.yml`

In `project.yml`, update the `FitnessWatchAppExtension` target to add
`CODE_SIGN_ENTITLEMENTS`. The full updated target should look like this:

```yaml
FitnessWatchAppExtension:
  type: watchkit2-extension
  platform: watchOS
  deploymentTarget: "10.0"
  sources:
    - path: FitnessWatchApp
    - path: Shared
  settings:
    base:
      PRODUCT_BUNDLE_IDENTIFIER: com.mnew.FitnessApp.healthreset.watchkitapp.watchkitextension
      PRODUCT_NAME: FitnessWatchAppExtension
      GENERATE_INFOPLIST_FILE: NO
      INFOPLIST_FILE: FitnessWatchApp/FitnessWatchAppExtension-Info.plist
      CODE_SIGN_ENTITLEMENTS: FitnessWatchApp/FitnessWatchApp.entitlements
```

Also update the `INFOPLIST_KEY_NSHealthShareUsageDescription` and
`INFOPLIST_KEY_NSHealthUpdateUsageDescription` strings in the `FitnessApp` (iPhone)
target to reflect heart rate access:

```yaml
INFOPLIST_KEY_NSHealthShareUsageDescription: "Training Day reads your workout history and live heart rate to improve planning and display stats during workouts."
INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Training Day saves completed workouts to Apple Health to keep your history complete."
```

---

## Change 3 — Add HealthKit usage strings to Watch Info.plist

In `FitnessWatchApp/FitnessWatchAppExtension-Info.plist`, add these two keys inside
the root `<dict>`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Training Day reads your workout history and live heart rate to improve planning and display stats during workouts.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Training Day saves completed workouts to Apple Health to keep your history complete.</string>
```

---

## Change 4 — Update `HealthKitService.requestAuthorization()`

In `FitnessApp/HealthKitService.swift`, replace the existing `requestAuthorization()`
method with this expanded version that requests heart rate, active energy, and activity
summary access on both platforms:

```swift
func requestAuthorization() async throws {
    guard isHealthDataAvailable else {
        throw HealthKitServiceError.unavailable
    }

    let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType()
    ]

    let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKObjectType.activitySummaryType()
    ]

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
```

---

## Change 5 — Add `startLiveWorkout()` to `HealthKitService`

In `FitnessApp/HealthKitService.swift`, add this new method to the `HealthKitService`
class, below `requestAuthorization()`:

```swift
func startLiveWorkout(activityTypeName: String) throws -> (HKWorkoutSession, HKLiveWorkoutBuilder) {
    guard let activityType = WorkoutActivityCatalog.activityType(forTitle: activityTypeName) else {
        throw HealthKitServiceError.authorizationFailed
    }

    let config = HKWorkoutConfiguration()
    config.activityType = activityType
    config.locationType = .indoor

    let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
    let builder = session.associatedWorkoutBuilder()
    builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

    return (session, builder)
}
```

---

## Change 6 — Create `Shared/LiveWorkoutManager.swift`

**Create** a new file `Shared/LiveWorkoutManager.swift`. This is used by both the
Watch and iPhone to manage an active live session:

```swift
import Foundation
import HealthKit

@MainActor
final class LiveWorkoutManager: NSObject, ObservableObject {
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
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
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in
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
```

---

## Change 7 — Request authorization on Watch app launch

In `FitnessWatchApp/FitnessWatchAppApp.swift`, add a `.task` to the root scene to
request HealthKit authorization when the Watch app starts. Find the root `WindowGroup`
or `WKNotificationScene` and add:

```swift
.task {
    let service = HealthKitService()
    try? await service.requestAuthorization()
}
```

---

## Change 8 — Wire `LiveWorkoutManager` into the Watch workout view

In whatever Watch view currently starts and tracks a workout (likely the active
workout / current exercise screen), inject and use `LiveWorkoutManager`:

```swift
@StateObject private var liveWorkout = LiveWorkoutManager()
```

**On workout start** (`.onAppear` or a start button tap):

```swift
try? liveWorkout.start(activityTypeName: session.activityType)
```

**Display live metrics:**

```swift
Text("\(Int(liveWorkout.heartRate)) BPM")
Text("\(Int(liveWorkout.activeCalories)) kcal")
Text(Duration.seconds(liveWorkout.elapsedSeconds)
    .formatted(.time(pattern: .minuteSecond)))
```

**On workout finish**, call `stop()` and use the returned dates when sending the
workout back to the phone. Because `finishWorkout()` already wrote to HealthKit,
the phone-side `saveWorkout()` call is no longer needed for the HealthKit write —
but the `sendWorkout` call to sync exercise detail back to SwiftData should be kept:

```swift
let (start, end) = try await liveWorkout.stop()
sender.sendWorkout(
    activityType: session.activityType,
    completedAt: end,
    durationSeconds: end.timeIntervalSince(start),
    exercises: completedExercises
)
```

---

## After All Changes

Regenerate the Xcode project before building:

```sh
".tools/XcodeGen/.build/arm64-apple-macosx/debug/xcodegen" generate
```

Then build both schemes to verify:

```sh
xcodebuild -project "FitnessApp.xcodeproj" -scheme "FitnessApp" \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  SYMROOT=".build/xcode-scheme-ios" \
  OBJROOT=".build/xcode-scheme-ios/obj" build

xcodebuild -project "FitnessApp.xcodeproj" -scheme "FitnessWatchApp" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO \
  SYMROOT=".build/xcode-scheme-watch" \
  OBJROOT=".build/xcode-scheme-watch/obj" build
```
