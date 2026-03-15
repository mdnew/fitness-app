# Fix Active vs Total Calories — Implementation Plan

## Problem

Active Calories and Total Calories are showing the same value. This is because
`LiveWorkoutManager` only collects `activeEnergyBurned`. Total calories should be
active calories plus basal calories (resting metabolic burn during the workout period).

---

## Change 1 — Add `basalEnergyBurned` to authorization in `HealthKitService.swift`

In `FitnessApp/HealthKitService.swift`, update the `readTypes` set inside
`requestAuthorization()` to include `basalEnergyBurned`:

```swift
let readTypes: Set<HKObjectType> = [
    HKObjectType.workoutType(),
    HKQuantityType(.heartRate),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.basalEnergyBurned),  // add this
    HKObjectType.activitySummaryType()
]
```

---

## Change 2 — Track basal calories in `LiveWorkoutManager.swift`

In `Shared/LiveWorkoutManager.swift`, add a `basalCalories` published property and a
computed `totalCalories` next to the existing `activeCalories`:

```swift
@Published var activeCalories: Double = 0
@Published var basalCalories: Double = 0
var totalCalories: Double { activeCalories + basalCalories }
```

Then in the `workoutBuilder(_:didCollectDataOf:)` delegate method, add a case for
`basalEnergyBurned` alongside the existing `activeEnergyBurned` case:

```swift
case HKQuantityType(.activeEnergyBurned):
    self.activeCalories = stats?.sumQuantity()?
        .doubleValue(for: .kilocalorie()) ?? 0
case HKQuantityType(.basalEnergyBurned):
    self.basalCalories = stats?.sumQuantity()?
        .doubleValue(for: .kilocalorie()) ?? 0
```

---

## Change 3 — Update calorie display in the workout UI

Wherever calories are displayed during a live workout (on both Watch and iPhone),
use the appropriate property:

- For **active calories**: `liveWorkout.activeCalories`
- For **total calories**: `liveWorkout.totalCalories`

If only one calorie figure is shown, it should be `totalCalories` to match what
the native Workout app displays.

---

## Notes

- `HKLiveWorkoutDataSource` will automatically begin collecting basal energy once
  authorization is granted — no additional data source configuration is needed.
- Users who have already granted permissions will be prompted again on next launch
  since `basalEnergyBurned` is a new read type.
