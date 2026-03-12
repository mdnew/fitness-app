# Fitness App Implementation Plan

## Purpose

This document turns the product definition into a practical build plan.

It covers:

- recommended technical architecture
- platform responsibilities across `iPhone` and `Apple Watch`
- storage and sync strategy
- core app modules
- implementation milestones

This is intentionally biased toward a simple MVP:

- single user
- no backend required for launch
- local-first data model
- `Apple Watch` as the primary workout interface
- `iPhone` as the primary planning and management interface

## Recommended MVP Architecture

Use a native Apple stack:

- `SwiftUI` for `iPhone` and `Apple Watch` UI
- `HealthKit` for workout history import and workout write-back
- `WatchConnectivity` for phone/watch data sync
- `SwiftData` for primary local persistence on `iPhone`

For MVP, avoid introducing a backend unless a later requirement truly needs it.

## Architecture Principles

### 1. Phone Owns Planning

The `iPhone` app should be the source of truth for:

- events
- recurring activities
- ordered goals
- weight-training routine
- workout locations
- equipment availability
- workout history detail
- recommendation generation

### 2. Watch Owns Live Workout Execution

The `Apple Watch` app should be the source of truth for the active workout while a session is in progress.

That means the watch must be able to:

- start a workout
- use default location and duration
- override those defaults
- display the current recommended exercise
- mark exercises complete
- override recommended exercises
- finish and save the workout

The watch should not require the phone to remain usable during the session.

### 3. Local-First Sync

For MVP:

- keep persistent planning data on `iPhone`
- sync the data the watch needs before or at workout start
- let the watch keep temporary local session state during the workout
- reconcile results back to the phone after the session

This is simpler and safer than trying to make both devices fully symmetric from day one.

### 4. Recommendation Logic Should Be Shared, Deterministic, And Explainable

The recommendation engine should be rules-based and deterministic.

Given the same inputs, it should produce the same:

- ordered goals
- workout recommendation
- exercise selection
- explanation strings

This will make debugging and product iteration much easier.

## Proposed App Structure

## iPhone App Responsibilities

The `iPhone` app should handle:

- onboarding and Health permissions
- app-launch Health refresh
- event management
- recurring activity review and ranking
- goal ordering
- weight-training routine setup
- location and equipment setup
- workout history browsing
- manual workout history correction
- recommendation generation

## Apple Watch App Responsibilities

The `Apple Watch` app should handle:

- start-workout flow
- location/duration defaults and edits
- current workout display
- next-exercise display
- timer and heart-rate display
- exercise completion
- override flow
- workout finish/save flow

## Shared Domain Layer

Create a shared domain layer used by both targets for:

- model types
- recommendation rules
- explanation generation
- mapping between stored data and UI state

Even if persistence differs by target, the core domain language should be shared.

## Suggested Modules

If you keep everything in one Xcode project, still organize the code conceptually into modules or folders:

- `App`
- `Features/Onboarding`
- `Features/Events`
- `Features/Goals`
- `Features/Routine`
- `Features/Locations`
- `Features/Workouts`
- `Features/History`
- `Domain/Models`
- `Domain/Recommendations`
- `Services/HealthKit`
- `Services/WatchSync`
- `Services/Persistence`

## Data Ownership Strategy

### iPhone Source Of Truth

The phone should store the full durable dataset:

- `Event`
- `RecurringActivity`
- `Goal`
- `Location`
- `RoutineDay`
- `WorkoutPlan`
- `PlannedExercise`
- `CompletedWorkout`
- `CompletedExercise`

### Watch Synced Runtime Dataset

The watch should receive just enough data to execute workouts:

- active goals snapshot
- selected or next workout plan
- planned exercises for the current session
- location list
- default location and duration for the day

The watch can also store temporary session state:

- started workout
- completed exercise IDs
- overrides
- finish time

After the workout, the watch should sync the finalized session back to the phone.

## Persistence Strategy

### iPhone Persistence

Use `SwiftData` on `iPhone` for MVP.

Reason:

- fast to set up
- good fit for a local-first single-user app
- enough structure for the current domain model

### Watch Persistence

Use lightweight local persistence on `Apple Watch` only for:

- cached workout snapshot
- active session progress
- unsynced completion state

The watch does not need to store the entire app data model for MVP.

## Sync Strategy

Use `WatchConnectivity` for:

- pushing updated goals/routine/location data to watch
- sending planned workout snapshots to watch
- returning completed workout results to phone

Recommended sync behavior:

1. App launch on phone refreshes Health data
2. Phone recomputes derived goals and recommendations
3. Phone sends latest workout-relevant snapshot to watch
4. Watch starts workout using latest cached snapshot
5. Watch records session progress locally
6. Watch sends finalized session back to phone
7. Phone stores workout detail, writes workout record to Apple Health, and refreshes future recommendations

If watch sync is delayed:

- keep watch flow usable
- show the latest available cached plan
- reconcile later

## HealthKit Strategy

## Read From HealthKit

On `iPhone`, read:

- all available workout history
- detected activity types from workout history
- optional additional signals for future use

For MVP, extra readiness signals can be collected, but they should not affect recommendation logic.

## Write To HealthKit

Write back:

- workout-level `Traditional Strength Training` session
- start/end time
- duration
- workout-level metrics as available

Keep inside the app:

- exercise-level detail
- override choices
- exercise order
- recommendation explanations

## Recommendation Engine Shape

The recommendation engine should consume:

- ordered goals
- workout history
- recurring activity emphasis
- weight-training routine defaults
- location/equipment constraints
- current workout state

It should produce:

- weekly plan
- workout recommendation for today
- planned exercise list
- explanation strings

For MVP, the engine should optimize for:

- good exercise choice
- good sequencing
- clear explanations

It should not try to solve:

- advanced progression
- advanced readiness modeling
- rep estimation

## Launch Behavior

Every app launch on `iPhone` should:

1. refresh Apple Health workout history
2. refresh imported workout types in `History`
3. leave the goals list unchanged until the user explicitly adds something
4. rebuild recommendation outputs from the current explicit goals list
5. sync the latest workout snapshot to watch

This keeps the phone current without silently disturbing user priority order.

## Watch Start Flow Behavior

When a workout starts on `Apple Watch`:

1. show today’s default location and duration from the weight-training routine
2. let the user change either if needed
3. load the best workout for the current context
4. show the first recommended exercise immediately

This should be optimized for minimal taps.

## Minimum Watch Screens

The first watch build should likely include these screens:

- `StartWorkout`
- `EditDefaults`
- `CurrentExercise`
- `OverrideExercise`
- `WorkoutComplete`

Optional later watch screens:

- more detailed exercise context
- richer stats
- deep history

## Milestone Plan

### Milestone 1: Project Skeleton

Goal:

- create the Xcode targets and base architecture

Deliverables:

- `iPhone` app target
- `Apple Watch` app target
- shared domain layer
- placeholder navigation

### Milestone 2: Local Data Model

Goal:

- implement the core entities and persistence on phone

Deliverables:

- `Event`
- `RecurringActivity`
- `Goal`
- `Location`
- `RoutineDay`
- `WorkoutPlan`
- `CompletedWorkout`

### Milestone 3: HealthKit Import And Detection

Goal:

- import workout history and detect recurring activities

Deliverables:

- Health permissions flow
- import all available workout history
- retain workout activity types in saved history
- support adding a workout type from `History` into the ranked goals list

### Milestone 4: Planning Surfaces On iPhone

Goal:

- make the planning model usable

Deliverables:

- events management
- recurring activity review and deletion
- goals ordering UI
- weight-training routine editor
- location/equipment editor

### Milestone 5: Recommendation Engine v1

Goal:

- generate the first useful workout recommendations

Deliverables:

- weekly recommendation generation
- exercise selection using goals, routine, and equipment
- explanation strings

### Milestone 6: Watch Workout MVP

Goal:

- complete the core watch flow end to end

Deliverables:

- start workout on watch
- routine-based defaults
- current exercise display
- completion and override flow
- finish and save workout on watch

### Milestone 7: Sync And Workout Write-Back

Goal:

- connect workout execution back to phone and HealthKit

Deliverables:

- watch-to-phone workout result sync
- workout persistence on phone
- Apple Health workout write-back
- post-workout recommendation refresh

### Milestone 8: History And Polishing

Goal:

- make the app credible for repeat use

Deliverables:

- completed workout history
- exercise-level detail view
- manual correction flow
- stability and UX polish

## What To Build First

If you want the shortest path to a believable demo, prioritize:

1. HealthKit import on phone
2. recurring activity detection
3. ordered goals UI
4. weight-training routine + location defaults
5. simple recommendation engine
6. watch workout flow

This sequence gets to the core loop fast without prematurely overbuilding history or analytics.

## Main Technical Risks

- watch/phone sync edge cases during active workouts
- HealthKit write-back fidelity differences from the native `Workout` app
- recommendation quality feeling too generic in the first pass
- keeping the watch flow fast with minimal taps

## Recommended Next Doc

After this, the highest-value design artifact is probably:

- a screen-by-screen `iPhone` and `Apple Watch` UI flow doc

That would make the first implementation pass much easier.
