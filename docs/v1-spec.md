# Fitness App v1 Spec

## Purpose

This document turns the PRD into a buildable v1 product spec.

It defines:

- the core product decisions for MVP
- the recommendation rules the app should follow
- the data model the app should store
- the primary user flows across `iPhone` and `Apple Watch`

## Product Boundaries

The app is a single-user fitness planning and workout guidance app.

It uses:

- Apple Health workout history
- a small set of Apple Health readiness signals
- dated events
- recurring activities
- workout locations and equipment
- a simple weekly weight-training routine

The main planning and setup surface is `iPhone`.
The primary in-workout surface is `Apple Watch`.

It does not try to be:

- a full coaching platform
- a general health dashboard
- a medical or injury product
- a long-horizon periodization engine

## Core Product Model

The app should use the following mental model:

- `events` are dated future activities such as a `5K`, `ski trip`, or `hike`
- `recurring activities` are ongoing or seasonal activities such as `surfing` or `cycling`
- `goals` are the active training targets created from those events and recurring activities
- `weight-training routine` is the user's recurring lifting schedule, including usual days, location defaults, and duration defaults
- `workouts` are the guided strength sessions recommended and tracked by the app

The `Events` screen can remain the place where the user manages both dated events and recurring activities.
The `Goals` screen should present the resulting active goals as an ordered list from highest to lowest importance.

## MVP Decisions

### Goal Inputs

The app supports two input types for MVP:

1. `event`
2. `recurringActivity`

Recurring activities can be suggested from Apple Health history, but they should not become active goals until the user confirms them.

Recurring activities must support a `goalEmphasis` field:

- `maintain`
- `improve`

Examples:

- `5K` in 8 weeks -> current goal: improve running-support strength
- `surfing` starting in spring, once per week, `improve` -> current goal: increase sport-support strength emphasis
- `cycling` weekly, `maintain` -> current goal: preserve support work without dominating the plan

### Weight-Training Routine Defaults

For MVP, the weight-training routine should support more than just workout focus.

Each routine day may include:

- default focus
- default location
- default duration

Example:

- `Monday` -> `20 minutes` at `Eos`
- `Wednesday` -> `20 minutes` at `Eos`
- `Friday` -> `20 minutes` at `Eos`

### Apple Health Inputs

The app should read the following Apple Health data for MVP:

- workout history
- sleep
- resting heart rate
- HRV
- active energy
- step count
- body weight if available

The app should refresh Apple Health workout history each time it launches.

The app should write completed workouts to Apple Health as `Traditional Strength Training`.

### Apple Health Inputs That Change Decisions

For MVP, additional Apple Health signals should not directly influence recommendations yet.

The recommendation engine should instead rely on:

- workout history
- goals
- goal order
- weight-training routine
- location and equipment
- a curated exercise library with movement and equipment metadata
- current workout state during live sessions

Additional signals such as `sleep`, `resting heart rate`, `HRV`, `active energy`, `step count`, and `body weight` may be collected for future use, but they should not change recommendations in v1.

### Recommendation Output

For MVP, the app should output:

- a weekly strength plan
- a recommended workout for today
- the next recommended exercise during an active workout
- a short explanation for each workout or exercise recommendation

For MVP, these outputs must be usable from `Apple Watch` during the workout without requiring access to the phone.

The app should not try to generate a fully personalized long-term progression system in v1.
The app should focus primarily on exercise recommendation rather than prescriptive sets, reps, and progression.

## Decision Rules

### Rule 1: Build Current Goals From Inputs

The app should convert user-managed inputs into active goals:

- each dated event becomes an active goal when it falls inside the planning window
- each recurring activity becomes an active goal when the user has marked it active, seasonal, or worth preparing for now
- Apple Health should surface detected activity types in a separate review list so the user can add them to goals, keep them for later, or delete them before they become active goals
- newly detected activity types should be appended to the bottom of the detected activities review list by default
- the app should present active goals as an ordered list that the user can adjust directly with drag-and-drop

### Rule 2: Planning Window

Use all available Apple Health workout history by default for baseline context.

Use a dynamic forward planning horizon based on the goal type and timing rather than one fixed planning window.

### Rule 3: Goal Ordering

The ordered `Goals` list should be the main priority system for MVP.

Use these default rules:

- the user controls priority by ordering goals from top to bottom
- the top goal should influence recommendations more than the goals below it
- dated events will often rise in importance as they get closer, but the app should suggest reordering rather than silently changing the list
- recurring activities with `improve` should usually deserve a higher position than similar recurring activities with `maintain`
- recurring activities with `maintain` should usually stay below near-term dated events unless the user intentionally places them higher

The app may generate reorder suggestions based on:

1. time sensitivity for dated events
2. seasonal return of a recurring activity
3. repeated recent activity detected in Apple Health
4. goal emphasis such as `maintain` versus `improve`

### Rule 4: Maintain Vs Improve

For recurring activities:

- `maintain` means keep enough support work in the plan to preserve readiness and reduce neglect
- `improve` means increase sport-support emphasis and allocate more accessory work toward that activity

Default effect on recommendations:

- `maintain`
  - lower exercise volume devoted to that activity
  - lower chance that the activity drives the top recommendation unless it is placed high in the goals list
  - more general support work, less sport-specific bias
- `improve`
  - higher exercise volume devoted to that activity
  - higher chance that the activity influences the workout of the day, especially when it is placed high in the goals list
  - more sport-specific accessory selection

For MVP, this should be interpreted as:

- `maintain` keeps light background support in the plan
- `improve` gives the activity a stronger influence on exercise selection and weekly emphasis

### Rule 5: Recommendation Readiness Adjustments

Do not use additional Apple Health readiness signals to change recommendation logic in MVP.

Those signals can still be collected for future versions, but they should not alter the v1 recommendation engine.

### Rule 6: Location Constraints

Location and equipment constraints must be applied before the workout is built.

The app should avoid generating unsupported exercises for the selected location in the first place.

If an ideal exercise is unavailable during planning:

1. choose the closest available substitute at that location
2. preserve the movement pattern or training intent
3. explain the substitution briefly

### Rule 7: Weight-Training Routine Constraints

The weight-training routine should guide the weekly structure but should not rigidly block recommendations.

Example:

- if Monday is usually lower body, prefer a lower-body-support session
- if a top-ranked goal needs a different emphasis, allow the plan to override the weight-training routine with an explanation

The weight-training routine should also provide start-workout defaults when available:

- prefill location from the routine day
- prefill intended duration from the routine day
- allow the user to change either value before starting

### Rule 8: Live Workout Adaptation

During an active workout, the app should recommend the next exercise based on:

- current plan
- completed exercises
- remaining workout time
- current location/equipment
- live heart rate when useful

The active workout flow should work end to end on `Apple Watch`.

If the user overrides an exercise:

- accept the override
- record it
- adapt remaining recommendations without treating the session as failed

### Rule 9: Recurring Activity Suggestions

The app should surface all detected recurring activity types from Apple Health history for user review rather than trying to hide them behind a threshold.

Detected activities should be shown as reviewable inputs, not auto-activated goals.

The user should be able to:

- add the activities that matter right now into the active goals list
- set whether each one is `maintain` or `improve`
- delete activities that are no longer relevant
- optionally add schedule hints or seasonality

Newly detected activities should be inserted at the bottom of the detected activities review list so they never silently outrank the user's existing priorities.

### Rule 10: Goal Reordering Suggestions

The app may suggest moving a goal higher or lower in the ordered list when:

- a dated event is approaching quickly
- a seasonal recurring activity becomes active again
- Apple Health shows a recurring activity is happening regularly again
- a currently high-ranked goal appears inactive or less urgent

The app should:

- explain why a reorder is being suggested
- allow the user to accept or ignore it
- avoid frequent low-confidence suggestions

## Recommendation Logic

### Inputs

The recommendation engine uses:

- active goals
- goal order
- recent workout history
- readiness snapshot
- location and equipment
- weight-training routine by day
- exercise library metadata
- current workout state during live sessions

### Outputs

For each planning cycle, the engine should produce:

- weekly plan structure
- today recommendation
- exercise list for the selected workout
- explanation strings

### Explanation Template

Each recommendation explanation should be short and structured around:

1. what it supports
2. why now
3. any adaptation applied

Example:

`Single-leg work is recommended today because it supports skiing balance demands, fits your usual lower-body day, and uses the equipment available at Home Gym.`

## Data Model

### Event

Represents a dated future activity.

Suggested fields:

- `id`
- `type`
- `title`
- `targetDate`
- `notes`
- `status`
- `createdAt`
- `updatedAt`

### RecurringActivity

Represents an ongoing or seasonal activity.

Suggested fields:

- `id`
- `type`
- `title`
- `goalEmphasis`
- `frequencyPerWeek`
- `seasonStartMonth`
- `seasonEndMonth`
- `scheduleHint`
- `notes`
- `source`
- `status`
- `createdAt`
- `updatedAt`

Notes:

- `source` should distinguish `manual` from `appleHealthSuggested`
- `status` can represent whether the activity is active, paused, or archived

### Goal

Represents an active training target derived from an event or recurring activity.

Suggested fields:

- `id`
- `sourceType`
- `sourceId`
- `type`
- `goalEmphasis`
- `orderIndex`
- `status`
- `explanation`
- `createdAt`
- `updatedAt`

Notes:

- `sourceType` should be `event` or `recurringActivity`
- `orderIndex` represents the top-to-bottom user-controlled order on the `Goals` screen

### Location

Represents a place where workouts happen.

Suggested fields:

- `id`
- `name`
- `equipmentTags`
- `notes`
- `createdAt`
- `updatedAt`

### RoutineDay

Represents the user's usual weight-training pattern.

Suggested fields:

- `id`
- `weekday`
- `focus`
- `defaultLocationId`
- `defaultDurationMinutes`
- `notes`
- `createdAt`
- `updatedAt`

Example `focus` values:

- `lower`
- `upper`
- `fullBody`
- `mobility`
- `conditioning`

### WorkoutPlan

Represents a planned workout.

Suggested fields:

- `id`
- `goalIds`
- `plannedDate`
- `locationId`
- `plannedDurationMinutes`
- `status`
- `recommendationSummary`
- `createdAt`
- `updatedAt`

### ExerciseLibraryItem

Represents a curated exercise the app is allowed to recommend.

Suggested fields:

- `id`
- `name`
- `movementPattern`
- `requiredEquipment`
- `primaryMuscles`
- `goalSupportTags`
- `skillLevel`
- `isUnilateral`
- `notes`

Notes:

- this should be a curated catalog, not an exhaustive list of every possible gym variation
- the initial catalog should cover common squat, hinge, push, pull, carry, single-leg, and core patterns
- recommendation logic should choose from this library first, then apply location and equipment filtering before building a workout
- substitutions can be modeled later as explicit relationships between library items

### PlannedExercise

Represents an exercise inside a planned workout.

Suggested fields:

- `id`
- `workoutPlanId`
- `exerciseType`
- `displayName`
- `movementPattern`
- `recommendationReason`
- `orderIndex`
- `isOptional`

### CompletedWorkout

Represents a finished workout session.

Suggested fields:

- `id`
- `workoutPlanId`
- `startedAt`
- `completedAt`
- `deviceSource`
- `locationId`
- `durationMinutes`
- `writtenToAppleHealth`
- `createdAt`
- `updatedAt`

### CompletedExercise

Represents a completed or skipped exercise during a workout.

Suggested fields:

- `id`
- `completedWorkoutId`
- `plannedExerciseId`
- `exerciseType`
- `displayName`
- `status`
- `repCount`
- `setCount`
- `overrideReason`
- `orderIndex`

Note:

- exercise-level detail should remain inside the app and should not be treated as Apple Health write-back data

### ReadinessSnapshot

Represents a simplified readiness summary for decision-making.

Suggested fields:

- `id`
- `snapshotDate`
- `sleepStatus`
- `restingHeartRateStatus`
- `hrvStatus`
- `recentLoadStatus`
- `overallReadiness`
- `explanation`

Important:

- store simplified statuses rather than relying on raw Health values everywhere
- examples of status values: `low`, `normal`, `high`

## Primary User Flows

### Flow 1: Onboarding

1. User installs app on `iPhone`
2. User grants Apple Health permissions
3. App imports workout history and available readiness signals
4. App surfaces detected recurring activity types from Apple Health
5. User adds relevant activities into goals, deletes irrelevant ones, and sets initial goal emphasis
6. User drag-reorders the starting goals list from top to bottom
7. User adds one location and one weight-training routine pattern
8. App generates the first weekly recommendation

### Flow 1b: App Launch Refresh

1. User opens the app
2. App refreshes Apple Health workout history
3. App detects any newly seen activity types
4. App appends new detected activity types to the bottom of the detected activities review list
5. App refreshes goals, plan, and explanations

### Flow 2: Manage Events And Activities

1. User opens the `Events` screen
2. User adds or edits a dated event or recurring activity
3. User sets `maintain` or `improve` for recurring activities
4. App updates active goals
5. User reorders the `Goals` screen if needed
6. App refreshes the weekly plan and explanation

### Flow 3: Start A Workout

1. User starts workout on `Apple Watch` in the normal case, with `iPhone` support as a secondary option
2. App prefills location and duration from the weight-training routine when available
3. User accepts or changes those defaults
4. App loads the best workout for the moment
5. App recommends the first exercise

### Flow 4: Complete A Workout

1. User completes or overrides exercises from `Apple Watch`
2. App updates the remaining exercise list in real time
3. App saves the completed workout and exercise history
4. App writes the session to Apple Health
5. App updates future recommendations

## Minimum Apple Watch MVP Flow

For MVP, the watch app must support this complete path without requiring the phone during the session:

1. Open the workout flow on `Apple Watch`
2. Start a workout
3. See default location and duration when available
4. Change location or duration only if needed
5. See the current recommended exercise
6. See timer and heart rate during the workout
7. Mark the exercise complete
8. Override the next exercise when needed
9. Continue through the remaining workout
10. Finish and save the workout

### Required Watch Capabilities

These are the non-negotiable `Apple Watch` capabilities for MVP:

- start workout
- show default location and duration on the start screen
- change location when needed
- change intended duration when needed
- show next recommended exercise
- show timer
- show heart rate when available
- mark exercise complete
- override exercise
- finish workout
- save workout locally and sync afterward if needed

### Watch MVP Non-Goals

These are useful, but not required to call MVP successful:

- advanced charts or detailed analytics on watch
- deep history browsing on watch
- complex goal management on watch
- editing events or recurring activities on watch
- full manual workout construction on watch
- rep estimation

## Cross-Device MVP Rules

For MVP:

- `iPhone` is the main planning and management surface
- `Apple Watch` is the primary workout execution surface
- the full in-workout flow must work on `Apple Watch` without relying on the phone during the session
- `iPhone` may support workout start and completion as a secondary option
- workout state must stay in sync during an active session

If sync is temporarily delayed:

- the active session should continue locally
- the app should reconcile the session afterward

If `Apple Watch` execution is weak, slow, or incomplete, MVP should be considered unsuccessful even if the `iPhone` planning experience is strong.

## MVP Fallback Behavior

If Apple Health workout history is sparse:

- still allow manual events, recurring activities, weight-training routine, and location setup
- generate simpler rules-based plans with lower confidence

If readiness signals are missing:

- continue planning from workout history and goals alone

If Apple Health write-back fails:

- preserve the workout inside app history
- mark Apple Health sync as incomplete

Apple Health write-back should aim to match native workout-level fidelity as closely as possible, while keeping exercise-level details inside the app.

If the phone is not immediately available during a workout:

- `Apple Watch` should still allow the user to progress through the workout
- sync and reconciliation can happen afterward

If rep estimation is unavailable:

- allow manual completion without rep-derived automation

## Suggested Implementation Order

1. Build data models and local persistence
2. Build Apple Health read and write integration
3. Build events and recurring activities management
4. Build goal derivation and goal ordering logic
5. Build weekly planning and recommendation rules
6. Build Apple Watch workout execution flow
7. Build secondary `iPhone` workout support and cross-device sync
8. Build history and manual correction flows

## Open Items To Confirm Before Coding

- exact heuristics for goal reorder suggestions
- whether the `Events` screen should be renamed in the UI or simply handle both events and activities under the existing name
