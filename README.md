# Fitness App

Personal fitness planning app concept focused on turning Apple Health workout history plus upcoming events into practical lifting guidance.

## What It Does

- imports past workout activity from Apple Health
- lets you define upcoming goals like a `5K`, `ski trip`, or `hike`
- recommends strength training that supports those events
- organizes recommendations into a simple weekly plan

## Product Direction

The current product definition lives in `docs/PRD.md`.

## Current Status

This repository now contains:

- product discovery and planning docs
- an XcodeGen-based iPhone app target
- a companion Apple Watch app plus watch extension
- early HealthKit import and local persistence wiring

## Build

Generate the Xcode project from `project.yml`:

```sh
".tools/XcodeGen/.build/arm64-apple-macosx/debug/xcodegen" generate
```

Open the project in Xcode:

```sh
open "FitnessApp.xcodeproj"
```

Build from the command line with schemes, not raw targets:

```sh
xcodebuild -project "FitnessApp.xcodeproj" -scheme "FitnessApp" -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO SYMROOT=".build/xcode-scheme-ios" OBJROOT=".build/xcode-scheme-ios/obj" build
```

```sh
xcodebuild -project "FitnessApp.xcodeproj" -scheme "FitnessWatchApp" -destination "generic/platform=watchOS" CODE_SIGNING_ALLOWED=NO SYMROOT=".build/xcode-scheme-watch" OBJROOT=".build/xcode-scheme-watch/obj" build
```

If you change `project.yml`, regenerate `FitnessApp.xcodeproj` before building again.
