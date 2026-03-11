# Fitness App UI Flows

## Purpose

This document defines the MVP screen flows for:

- `iPhone` planning and management
- `Apple Watch` workout execution

It is intentionally focused on the first usable product, not the fully expanded future UI.

## Design Priorities

The UI should optimize for:

- low friction setup on `iPhone`
- minimal taps on `Apple Watch`
- user control over goals ordering
- clear defaults from the weight-training routine
- no requirement to use the phone during the workout

## Platform Roles

### iPhone

The `iPhone` app is the main surface for:

- onboarding
- Health permissions
- goals/events/activity management
- weight-training routine setup
- location and equipment setup
- history review and correction

### Apple Watch

The `Apple Watch` app is the main surface for:

- starting a workout
- confirming or changing defaults
- seeing the current exercise
- marking progress
- overriding exercises
- finishing and saving the workout

## iPhone Navigation Model

Recommended MVP tab structure:

1. `Goals`
2. `Routine`
3. `History`
4. `Settings`

Notes:

- `Goals` can include both the ordered goals list and access to dated events / detected activities
- `Routine` can include locations, since those two concepts are tightly connected for MVP

## Apple Watch Navigation Model

Recommended MVP watch structure:

1. `Start Workout`
2. `Current Exercise`
3. `Override`
4. `Workout Complete`

The watch app should feel more like a focused workflow than a full app with deep navigation.

## iPhone Flows

### Flow 1: First Launch And Onboarding

#### Screen 1: Welcome

Purpose:

- explain the product simply
- set expectations about `Apple Health` and `Apple Watch`

Primary actions:

- `Continue`
- `Why Apple Health?`

#### Screen 2: Health Permissions

Purpose:

- request Health permissions
- explain what is read and written

Primary actions:

- `Connect Apple Health`
- `Not Now`

Key content:

- reads workout history
- writes completed strength workouts
- may detect recurring activities from history

#### Screen 3: Detected Activities Review

Purpose:

- show activity types detected from Apple Health
- let the user decide what matters

Primary actions:

- reorder activities
- delete irrelevant activities
- set `maintain` or `improve`
- `Continue`

Notes:

- new detected activities should appear at the bottom
- nothing should silently outrank existing user priorities

#### Screen 4: Add First Event

Purpose:

- optionally add a dated event such as `5K` or `ski trip`

Primary actions:

- `Add Event`
- `Skip`

Fields:

- event type
- date
- notes

#### Screen 5: Weight-Training Routine Setup

Purpose:

- define the typical lifting schedule

Primary actions:

- add routine day
- edit routine day
- `Continue`

Per-day fields:

- weekday
- focus
- default location
- default duration

Example:

- `Monday` / `20 min` / `Eos`

#### Screen 6: Locations Setup

Purpose:

- define workout locations and available equipment

Primary actions:

- `Add Location`
- `Continue`

Fields:

- location name
- equipment tags
- notes

#### Screen 7: First Plan Summary

Purpose:

- show that the setup created a real plan

Primary actions:

- `View Goals`
- `Start Workout On Watch`

Content:

- ordered goals list
- upcoming event if any
- suggested workout for today

### Flow 2: Goals Screen

#### Screen: Goals

Purpose:

- act as the main planning home
- show current ordered priorities

Sections:

- ordered goals list
- detected activity types
- upcoming events
- today recommendation summary

Primary actions:

- drag to reorder goals
- tap goal to edit
- add event
- convert detected activity into active focus
- delete irrelevant activity

Goal row content:

- title
- source type: event or recurring activity
- emphasis: `maintain` or `improve`
- optional urgency hint

Behavior:

- top-to-bottom order is the main priority system
- app may suggest reorderings, but the user decides

### Flow 3: Event Editor

#### Screen: Add / Edit Event

Purpose:

- manage dated future activities

Fields:

- event type
- title
- date
- notes

Primary actions:

- `Save`
- `Delete`

### Flow 4: Activity Editor

#### Screen: Add / Edit Recurring Activity

Purpose:

- manage non-dated activities such as `cycling` or `surfing`

Fields:

- activity type
- emphasis: `maintain` or `improve`
- optional schedule hint
- optional seasonality
- notes

Primary actions:

- `Save`
- `Delete`

### Flow 5: Routine Screen

#### Screen: Weight-Training Routine

Purpose:

- define recurring lifting schedule and defaults

Sections:

- routine days list
- default location and duration by day

Primary actions:

- add routine day
- edit routine day

Routine day row content:

- day name
- focus
- default location
- default duration

### Flow 6: Locations Screen

#### Screen: Locations

Purpose:

- manage available training environments

Primary actions:

- add location
- edit location

Location row content:

- location name
- equipment summary

#### Screen: Edit Location

Fields:

- name
- equipment tags
- notes

Primary actions:

- `Save`
- `Delete`

### Flow 7: History Screen

#### Screen: History

Purpose:

- review completed workouts

Primary actions:

- open workout
- correct workout data

Workout row content:

- date
- duration
- location
- summary label

#### Screen: Workout Detail

Purpose:

- show the full app-specific record of a completed session

Sections:

- workout summary
- exercise list
- overrides
- recommendation context

Primary actions:

- `Edit`

## Apple Watch Flows

### Flow 1: Start Workout

#### Screen 1: Start Workout

Purpose:

- provide the fastest possible entry into the session

Default content:

- default location from today's weight-training routine
- default duration from today's weight-training routine
- quick summary of the selected workout

Primary actions:

- `Start`
- `Edit`

Behavior:

- if defaults exist, show them directly
- if a default is missing, prompt only for the missing field
- if no defaults exist, require location and duration before starting

#### Screen 2: Edit Defaults

Purpose:

- let the user change location and/or duration

Fields:

- location picker
- duration picker

Primary actions:

- `Save`
- `Back`

### Flow 2: Current Exercise

#### Screen: Current Exercise

Purpose:

- act as the main watch workout screen

Required content:

- current exercise name
- brief reason or context
- timer
- heart rate when available
- progress indicator

Primary actions:

- `Complete`
- `Override`
- `End Workout`

Nice-to-have but not required:

- a small hint about what is next

### Flow 3: Override Exercise

#### Screen: Override

Purpose:

- allow the user to reject the current recommendation without breaking the workout

Content:

- list of substitute exercises appropriate for the current location

Primary actions:

- choose replacement
- `Back`

Behavior:

- replacing the exercise should update the rest of the session logic
- the session should continue without treating the workout as failed

### Flow 4: Complete Exercise

This is not a separate screen if it can be avoided.

Preferred interaction:

- tap `Complete`
- app advances immediately to the next exercise

Optional transient state:

- short confirmation banner or haptic feedback

### Flow 5: Finish Workout

#### Screen: End Workout Confirmation

Purpose:

- prevent accidental workout termination

Primary actions:

- `Finish Workout`
- `Cancel`

#### Screen: Workout Complete

Purpose:

- confirm that the session has been saved

Content:

- duration
- location
- simple completion summary

Primary actions:

- `Done`

Behavior:

- if phone sync is delayed, the watch should still show the workout as saved locally

## Watch Start-Screen Rules

These rules are important enough to state explicitly:

1. If both default location and duration exist, show them and let the user start immediately.
2. If only one default exists, ask only for the missing value.
3. If neither exists, require both before workout start.
4. If new activity detection changed the goals list earlier on phone, the watch should simply use the latest synced order and not interrupt the start flow.

## Suggested Information Hierarchy

### Highest Priority On Watch

- start quickly
- current exercise
- complete or override
- finish workout

### Highest Priority On iPhone

- manage goals order
- review detected activities
- set up routine defaults
- manage locations
- review history

## MVP Screen Checklist

### iPhone

- `Welcome`
- `Health Permissions`
- `Detected Activities Review`
- `Goals`
- `Add/Edit Event`
- `Add/Edit Recurring Activity`
- `Weight-Training Routine`
- `Locations`
- `History`
- `Workout Detail`

### Apple Watch

- `Start Workout`
- `Edit Defaults`
- `Current Exercise`
- `Override`
- `End Workout Confirmation`
- `Workout Complete`

## Suggested Next Step

The next most useful artifact is probably a light wireframe doc or a set of low-fidelity mockups for:

- `Goals` on `iPhone`
- `Weight-Training Routine` on `iPhone`
- `Start Workout` on `Apple Watch`
- `Current Exercise` on `Apple Watch`
