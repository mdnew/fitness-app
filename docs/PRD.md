# Fitness App PRD

## Overview

This product is a personal fitness planning and workout guidance app that connects to Apple Health, reads historical workout activity plus a small set of useful recovery and readiness signals, captures future inputs such as dated events and recurring activities, turns those into current goals, and then uses that context to drive guided strength sessions across `iPhone` and `Apple Watch`, with `Apple Watch` as the primary in-workout interface.

The first version is designed for a single self-directed user. Its job is not to be a general wellness tracker or social fitness app. Its job is to help answer a practical training loop clearly and repeatedly: what should I do next, where should I do it, and how should that workout adapt to my real goals, weight-training routine, equipment, and completed sessions?

## Problem

Workout history, future goals, and in-gym execution usually live in separate mental buckets.

- Apple Health contains useful historical data, but it does not tell me what strength work to do next or how to execute it in the moment.
- Upcoming activities like races, hikes, and ski trips create real training needs, but translating those needs into gym exercises is manual and inconsistent.
- Generic training plans are disconnected from my actual workout history, my available equipment, and the event I care about right now.
- Even when I have a plan, it often breaks down during the workout when time is short, equipment differs by location, or I want to adjust on the fly.

The result is uncertainty before the workout, friction during the workout, and reduced confidence that my lifting supports the outcomes I actually want.

## Vision

Create a personal training assistant that turns past workout data and future activity goals into practical, explainable strength guidance that can also guide workout execution in real time.

## Product Goal

Help a self-directed athlete prepare for real upcoming activities by using Apple Health workout history, a small set of useful readiness signals, weight-training routine preferences, workout locations, and future inputs such as events and recurring activities to form current goals, then recommend, guide, and adapt relevant lifting work, with `iPhone` handling planning and setup and `Apple Watch` handling the primary in-workout experience.

## Target User

### Primary Persona

`Matt` is a self-directed athlete who already records activity through Apple devices and wants a more intelligent way to plan and execute strength work. He does not need social motivation or broad lifestyle tracking. He wants a focused tool that looks at what he has been doing, understands what event he is preparing for, and gives him clear lifting guidance he can trust during planning and during the workout itself.

### Persona Traits

- Already active and comfortable working out independently
- Has real-world upcoming goals such as `5K`, `ski trip`, `hike`, or recurring activities like `surfing` and `cycling`
- Wants recommendations grounded in actual history, not generic templates
- Prefers clarity and usefulness over complexity
- Values explainable recommendations more than novelty

## Jobs To Be Done

- Help me understand what my recent activity says about my current training base.
- Help me define what I am preparing for next, whether that is a specific event or an activity I want to improve at regularly, and see the goals that matter right now.
- Help me know which lifting exercises support that goal.
- Help me turn those recommendations into a practical weekly weight-training routine that fits my usual schedule.
- Help me execute the workout with the equipment and time I actually have available.
- Help me stay aligned as events change or as I complete workouts.

## User Pains

- My past workouts are recorded, but they are not helping me decide what to do next in the gym.
- I am not always sure how to train for very different goals like a `ski trip` versus a `5K`.
- Existing plans often ignore both my recent training and my calendar or recurring activities I care about.
- The equipment I have available changes by location, which makes static plans hard to follow.
- If I have more than one event coming up, it becomes harder to prioritize training.

## User Gains

- Confidence that each lifting session supports a real goal
- Less time spent figuring out what to do next before and during a workout
- A plan that reflects history, future intent, recurring activities, weight-training routine, and available equipment
- Clear rationale for why a recommendation exists
- A repeatable system for preparing for different types of events
- A usable workout log that stays aligned with Apple Health

## Core Use Case

1. The user connects Apple Health for workout history import and workout write-back.
2. The app reads recent workout history and summarizes training patterns.
3. The user adds or confirms future inputs, including dated events and recurring activities.
4. The app turns those inputs into current goals and shows what is being worked on right now.
5. The user defines workout locations, available equipment, and a typical weight-training routine by day.
6. The app maps goal demands plus history, weight-training routine, and location constraints into a weekly strength plan and next-workout recommendations.
7. The user starts a workout, ideally from `Apple Watch`, chooses a location, and specifies the intended workout duration.
8. The app guides the workout on `Apple Watch` by recommending the next exercise, showing workout context such as timer and heart rate, and allowing overrides without requiring access to the phone.
9. The user marks exercises complete, the workout is stored in app history and written to Apple Health, and the app updates future guidance.

## MVP Scope

### In Scope

- Apple Health connection and permission flow
- Import of historical workout data from Apple Health
- Import of selected Apple Health readiness signals: `sleep`, `resting heart rate`, `HRV`, `active energy`, `step count`, and optionally `body weight` when available
- Write completed workouts to Apple Health as `Traditional Strength Training`
- Goal creation for upcoming activities
- Event creation for dated upcoming activities
- Recurring activity creation for ongoing or seasonal activities
- Goal model supporting fixed-date events and recurring activities
- Goal derivation from events and recurring activities
- Goal fields including `type`, optional `notes`, a goal emphasis such as `improve` or `maintain`, a top-to-bottom order in the goals list, and either a target `date` or recurring activity details such as `season`, `frequency`, or schedule hints
- Current goals view
- Workout location management
- Equipment availability by location
- Routine/day template definition
- Baseline summary of recent training activity
- Goal-aware lifting recommendations
- Weekly plan presentation
- In-workout session start on `Apple Watch`, with `iPhone` support as a secondary surface
- Workout setup with selected location and intended duration
- Next-exercise recommendation during an active workout
- Manual exercise override during an active workout
- Workout completion tracking
- Past workout history view
- Manual add/correct flow for incomplete exercise history
- Adaptive recommendations when completed work differs from the plan
- Basic recommendation explanations
- Timer and heart-rate display during workouts when available

### Out of Scope

- Nutrition planning
- Coach or multi-user workflows
- Social features
- Full AI coaching
- Injury, medical, or recovery diagnostics
- Android support
- Advanced long-term progression engine
- Deep wearable analytics beyond workout history plus basic heart rate during workouts
- Broad health dashboarding across all Apple Health categories
- Rep estimation from movement
- Open-ended workout programming for users outside the supported goal model

## Supported Goal Types For Initial MVP

To keep the recommendation engine credible and manageable, the initial release should focus on a narrow set of supported goal categories:

- Fixed-date event goals:
  - `5K`
  - `ski trip`
  - `hike`
- Recurring activity goals:
  - `surfing`
  - `cycling`

Other goal types can be added later once the core recommendation loop is validated.

## Goals, Events, And Activities

In this product, `goals` are the active things the user is currently training toward.

- `events` are dated future activities such as a `5K`, `ski trip`, or `hike`
- `recurring activities` are ongoing or seasonal activities such as `surfing` or `cycling`
- the app uses events and recurring activities as inputs that shape one or more current goals
- the `Goals` screen presents those current goals as an ordered list from highest to lowest importance

This keeps the product focused on what the user is trying to improve right now, while still allowing the `Events` screen to be the place where those future inputs are managed.

The app can suggest changes to goal order when a dated event gets closer or when an activity becomes relevant again, but the user stays in control of the final ordering.

`Routine` in this product refers specifically to the user's recurring weight-training schedule, including usual training days and defaults like location and duration. It does not mean recurring sports or activities such as `cycling` or `surfing`.

## Additional Apple Health Signals For MVP

To improve recommendations without turning the app into a general health tracker, the MVP can use a narrow set of additional Apple Health categories when available:

- `sleep` to estimate recovery and decide whether to keep, shorten, or reduce workout intensity
- `resting heart rate` and `HRV` to detect changes in readiness
- `active energy` and `step count` to understand recent load outside formal workouts
- `body weight` as optional context for exercise selection and progression

These signals should only be used when they clearly help the app make a better decision. If they are missing, the app should still function well using workout history, weight-training routine, location, and upcoming events.

## User Stories

#### Apple Health
- As Matt, I want to connect Apple Health so the app can read my workout history without manual entry.
- As Matt, I want the app to refresh my Apple Health workout history when I open it so the recommendations reflect recent activity.
- As Matt, I want the app to use a few useful Apple Health signals like sleep and resting heart rate so recommendations can better reflect how recovered I am.
- As Matt, I want to write my workout data to Apple Health as Traditional Strength Training

#### Events
- As Matt, I want to add an upcoming event with a type and date so the app knows what I've got coming up and can use it to shape my current goals.
- As Matt, I want a way to add a recurring activity such as `surfing` even if there is no fixed event date so it can shape my current goals.
- As Matt, I want to set whether a recurring activity like `cycling` is something I am trying to improve at or just maintain.
- As Matt, I want the app to show the activity types it detects from my Apple Health history in a separate review list so I can add the ones that matter to my goals and delete the ones that do not.

#### Goals
- As Matt, I want a way to see the current goals I'm working on based on my events and recurring activities.
- As Matt, I want to order my current goals from top to bottom so the app knows what matters most right now.
- As Matt, I want the app to suggest reorderings when upcoming events or recurring activities change in importance.

#### Locations
- As Matt, I want a way to create different locations where I work out and specify the type of equipment available at each

#### Workouts
- As Matt, I want a way to start my workout and specify a location to use on my Apple Watch or iPhone
- As Matt, I want a way to specify the length of time I plan to work out on my Apple Watch or iPhone
- As Matt, I want my usual location and duration to be prefilled on the workout start screen so I only change them when something is different.
- As Matt, I want the app to recommend the next exercise to do on my Apple Watch or iPhone based on my weight-training routine, history, and upcoming events.
- As Matt, I want the full workout flow to work from my Apple Watch because my phone is usually in my locker.
- As Matt, I want a way to override the exercise if I change my mind 
- As Matt, I want a way to see workout data like a timer and heart rate while I am doing the exercise.
- As Matt, I want a way to automatically calculate the reps based on movement from my Apple Watch.
- As Matt, I want a way to mark an exercise as complete on my Apple Watch or iPhone so that the app knows what I've already done.
- As Matt, I want the app to adjust recommendations when my completed workouts differ from the plan.

#### Routine
- As Matt, I want a way to define my typical weight-training routine for each day so that the app knows generally what I work on each day.
- As Matt, I want my weight-training routine to include defaults like location and duration so the workout start flow is faster.

#### History
- As Matt, I want to see past workouts in the app and see what exercises I did for each session. 
- As Matt, I want to manually add/correct exercise data if it is missing or incomplete.  


## Functional Requirements

### Health Data

- The system must request Apple Health permissions before accessing workout history.
- The system must import all available workout records from Apple Health by default.
- The system must refresh Apple Health workout history each time the app starts.
- The system should support importing a narrow set of additional Apple Health signals, including `sleep`, `resting heart rate`, `HRV`, `active energy`, `step count`, and optional `body weight`, when permission is granted and data exists.
- The system must summarize imported data into useful patterns, such as workout frequency and activity mix.
- The system may summarize additional Apple Health signals into simple readiness context, but those signals should not change recommendations in the MVP.
- The system must allow completed workouts to be written back to Apple Health as `Traditional Strength Training`.
- The system should preserve useful workout context in app history even when Apple Health write-back is unavailable or denied.

### Goals And Events

- The system must allow the user to create, edit, and remove goals.
- The system must allow the user to create, edit, and remove dated events and recurring activities as the main inputs that drive goals.
- The system must support both fixed-date events and recurring activities as goal types.
- The system must derive or represent current goals from those events and recurring activities.
- The system must store goal type, notes, goal emphasis, goal order, and either a target date or recurring activity details.
- The system must support at least the initial goal types listed in this document.
- The system must provide a way to view the current active goals the user is preparing for.
- The system should surface detected recurring activity types from Apple Health history in a separate review list so the user can add them to goals or delete them from consideration.
- The system should append newly detected recurring activity types to the bottom of the detected activities review list by default.
- The system must allow the user to reorder active goals from top to bottom.
- The system must support direct drag-and-drop reordering of active goals on the `Goals` screen.
- The system should suggest goal reorderings when dated events become more urgent or recurring activities become more relevant.

### Locations

- The system must allow the user to create, edit, and remove workout locations.
- The system must store equipment availability for each location.
- The system must use location equipment constraints when generating workout recommendations.

### Routines

- The system must allow the user to define a typical weight-training routine or workout focus by day.
- The system should allow each routine day to include default workout metadata such as location and duration.
- The system should use weight-training routine information as an input when selecting recommended workouts and exercises.

### Recommendations

- The system must generate lifting recommendations based on goal type, recent workout history, weight-training routine information, and location equipment constraints.
- The system must treat the ordered goals list as the primary priority signal for recommendations.
- The system must maintain a curated exercise library that the recommendation engine can choose from when building workouts.
- The system should store exercise metadata such as movement pattern, required equipment, primary muscle groups, and goal-support tags so recommendations can stay explainable and location-aware.
- The system should not use additional Apple Health readiness signals to change recommendations in the MVP.
- The system should account for recurring activity frequency, seasonal timing, and whether the user wants to improve or maintain that activity when deciding how much strength work should support it.
- The system should treat `maintain` as light background support and `improve` as a stronger driver of exercise selection and weekly emphasis.
- The system must organize recommendations into a weekly plan format.
- The system must recommend the next exercise during an active workout based on the plan, completed work, and current workout context.
- The system should provide a brief explanation for why each exercise is recommended.
- The system should remain rules-based and explainable in the initial version, with recommendations focused primarily on exercise selection rather than prescriptive sets, reps, or progression.
- The system should adjust future recommendations when completed workouts differ from the original plan.

### Workout Execution

- The system must allow the user to start and complete a workout entirely from `Apple Watch`.
- The system must allow the user to start a workout on `iPhone` as a secondary option.
- The system must prefill workout location and intended duration from the user's weight-training routine when a suitable default exists.
- The system must allow the user to change the prefilled location and intended duration at workout start.
- The system must show the current recommended exercise on `Apple Watch` during the workout.
- The system must display basic in-workout context, including a timer and heart rate when available from the device.
- The system must allow the user to override the recommended next exercise during a workout.
- The system must let the user mark exercises as complete on `Apple Watch` without requiring the `iPhone` during the workout.
- The system should support the same completion flow on `iPhone` as a secondary option.
- The system must allow the user to end the workout and save the session from `Apple Watch`.
- The system should use manual completion in the MVP rather than rep estimation.

### History

- The system must store completed workout sessions and completed exercises in app history.
- The system must allow the user to view past workouts and the exercises completed in each session.
- The system should allow the user to manually add or correct exercise history when data is missing or incomplete.
- The system should keep exercise-level details, exercise order, overrides, and recommendation-specific context inside the app rather than writing them back to Apple Health.

## Non-Functional Requirements

- The first version should treat `Apple Watch` as the primary workout surface and `iPhone` as the primary planning and management surface.
- The workout flow should remain fully usable on `Apple Watch` even when the phone is not immediately accessible during the session.
- The app should feel fast and lightweight, with minimal setup friction.
- Recommendations should be understandable and transparent rather than black-box.
- The app should degrade gracefully if Apple Health data is sparse or incomplete.
- The app should request only the Apple Health categories that clearly improve recommendations for this single-user product.
- The workout experience should remain usable when some live metrics or sensors are unavailable.

## Assumptions

- Apple Health workout history provides enough signal to generate useful baseline recommendations.
- A simple rules-based recommendation engine is sufficient for the MVP.
- A narrow set of supported goal types is enough to validate the concept.
- Users care more about actionable guidance than about broad dashboards or analytics.
- Users are willing to define a small amount of setup data, such as locations and weight-training routine patterns, if it improves recommendation quality.
- Manual workout completion is sufficient for the MVP without rep estimation.
- A small set of readiness signals from Apple Health can improve recommendations without making the product feel intrusive or overly complex.
- Users can reliably choose whether a recurring activity should be treated as a maintenance goal or an improvement goal.
- Users can maintain a simple top-to-bottom goal order more easily than managing abstract priority scores.
- The user expects to complete most in-workout interactions from `Apple Watch`, not from `iPhone`.

## Risks

- Historical lifting data may be incomplete if gym workouts were not consistently recorded in Apple Health.
- Recommendation quality may feel generic if goal-to-exercise mappings or weight-training routine/location logic are too shallow.
- Multiple simultaneous events could introduce prioritization complexity quickly.
- Recurring activities inferred from Apple Health history may be stale, seasonal, or misclassified, which could create irrelevant recommendations.
- The app may overemphasize activities like `cycling` if it infers frequency from Apple Health but does not correctly understand whether the user wants maintenance or improvement.
- Suggested goal reorderings could feel noisy if they happen too often or for weak reasons.
- Cross-device workout state and sync between `iPhone` and `Apple Watch` could add significant implementation complexity.
- If the `Apple Watch` workout flow is slow, incomplete, or unreliable, the MVP will fail even if the planning experience on `iPhone` is strong.
- Apple Health permission and write-back constraints may reduce the completeness of the logged workout record.
- Additional Apple Health permissions could add setup friction if the app requests more data than is clearly useful.
- Additional Apple Health signals may add permission friction before they provide meaningful MVP value.

## Success Criteria

The MVP is successful if it enables the user to:

- connect Apple Health successfully
- add an upcoming event or recurring activity in under a minute
- order the goals list without confusion
- define at least one workout location and one weight-training routine pattern without confusion
- receive a credible weekly lifting plan tied to that goal
- start a workout from `Apple Watch` with sensible default location and duration, and change them easily when needed
- complete a guided workout entirely from `Apple Watch` with at least one accepted or overridden recommendation
- see the current exercise, timer, and heart rate on `Apple Watch` during the session
- finish and save the workout from `Apple Watch` without needing the phone
- understand why the recommendations were made
- review the completed session in workout history
- continue using the app as a planning and workout guidance tool for multiple upcoming activities

## Open Questions


## Initial Build Recommendation

Start with the smallest credible loop:

1. Connect Apple Health for workout history, a small set of readiness signals, and workout write-back.
2. Import all available workouts.
3. Treat additional Apple Health readiness signals as optional future-facing context rather than MVP recommendation drivers.
4. Add one supported goal, either an upcoming event or a recurring activity.
5. Define one workout location with equipment and one simple weight-training routine pattern.
6. Produce a weekly lifting recommendation with explanations.
7. Start a workout on `Apple Watch` with weight-training-routine-based default location and duration, change them if needed, and guide the next exercise selection without needing the phone during the session.
8. Track completion, finish the workout from `Apple Watch`, store the workout in history, and adapt the next recommendation.

If that loop feels useful, the next step is expanding goal support, improving recommendation quality, adding more health-signal awareness, and introducing more adaptive planning.
