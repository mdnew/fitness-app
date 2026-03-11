# Fitness App PRD

## Overview

This product is a personal fitness planning app that connects to Apple Health, reads historical workout activity, captures upcoming goal events such as a `ski trip` or `5K`, and recommends the weight-lifting work that best supports those events.

The first version is designed for a single self-directed user. Its job is not to be a general wellness tracker or social fitness app. Its job is to help answer one practical question clearly and repeatedly: given what I have done recently and what I am preparing for next, what should I lift?

## Problem

Workout history and future goals usually live in separate mental buckets.

- Apple Health contains useful historical data, but it does not tell me what strength work to do next.
- Upcoming activities like races, hikes, and ski trips create real training needs, but translating those needs into gym exercises is manual and inconsistent.
- Generic training plans are disconnected from my actual workout history and from the event I care about right now.

The result is uncertainty, wasted effort, and reduced confidence that my lifting supports the outcomes I actually want.

## Vision

Create a personal training assistant that turns past workout data and future activity goals into practical, explainable strength guidance.

## Product Goal

Help a self-directed athlete prepare for real upcoming activities by using Apple Health workout history plus upcoming events to recommend relevant lifting exercises and a simple weekly plan.

## Target User

### Primary Persona

`Matt` is a self-directed athlete who already records activity through Apple devices and wants a more intelligent way to plan strength work. He does not need social motivation or broad lifestyle tracking. He wants a focused tool that looks at what he has been doing, understands what event he is preparing for, and gives him clear lifting guidance he can trust.

### Persona Traits

- Already active and comfortable working out independently
- Has real-world upcoming goals such as `5K`, `ski trip`, or `hike`
- Wants recommendations grounded in actual history, not generic templates
- Prefers clarity and usefulness over complexity
- Values explainable recommendations more than novelty

## Jobs To Be Done

- Help me understand what my recent activity says about my current training base.
- Help me define what I am preparing for next.
- Help me know which lifting exercises support that goal.
- Help me turn those recommendations into a practical weekly routine.
- Help me stay aligned as events change or as I complete workouts.

## User Pains

- My past workouts are recorded, but they are not helping me decide what to do next in the gym.
- I am not always sure how to train for very different goals like a `ski trip` versus a `5K`.
- Existing plans often ignore both my recent training and my calendar.
- If I have more than one event coming up, it becomes harder to prioritize training.

## User Gains

- Confidence that each lifting session supports a real goal
- Less time spent figuring out what to do next
- A plan that reflects both history and future intent
- Clear rationale for why a recommendation exists
- A repeatable system for preparing for different types of events

## Core Use Case

1. The user connects Apple Health.
2. The app reads recent workout history and summarizes training patterns.
3. The user adds an upcoming event with a type and date.
4. The app maps event demands plus training history into lifting recommendations.
5. The app presents a simple weekly strength plan.
6. The user marks workouts complete, and the app updates future guidance.

## MVP Scope

### In Scope

- Apple Health connection and permission flow
- Import of historical workout data from Apple Health
- Event creation for upcoming activities
- Event model with `type`, `date`, `priority`, and optional `notes`
- Baseline summary of recent training activity
- Goal-aware lifting recommendations
- Weekly plan presentation
- Workout completion tracking
- Basic recommendation explanations

### Out of Scope

- Nutrition planning
- Coach or multi-user workflows
- Social features
- Full AI coaching
- Injury, medical, or recovery diagnostics
- Advanced long-term progression engine
- Deep wearable analytics beyond workout history

## Supported Event Types For Initial MVP

To keep the recommendation engine credible and manageable, the initial release should focus on a narrow set of supported event categories:

- `5K`
- `ski trip`
- `hike`

Other event types can be added later once the core recommendation loop is validated.

## User Stories

### Must Have

1. As a user, I want to connect Apple Health so the app can read my workout history without manual entry.
2. As a user, I want to import my recent workouts so the app can establish a baseline of my current activity.
3. As a user, I want to add an upcoming event with a type and date so the app knows what I am training for.
4. As a user, I want the app to recommend lifting exercises based on my event and history so I know what strength work to prioritize.
5. As a user, I want to view those recommendations as a simple weekly plan so I can act on them immediately.
6. As a user, I want to mark recommended workouts complete so the app can keep future guidance relevant.

### Should Have

1. As a user, I want a short explanation for each recommendation so I understand why it supports my goal.
2. As a user, I want to set event priority so the app can focus on the most important upcoming goal.
3. As a user, I want the app to adjust recommendations when my completed workouts differ from the plan.

### Could Have

1. As a user, I want support for multiple overlapping events.
2. As a user, I want deeper progression guidance for load, volume, and deloads.
3. As a user, I want the app to identify potential training gaps automatically.

## Functional Requirements

### Health Data

- The system must request Apple Health permissions before accessing workout history.
- The system must import workout records from Apple Health for a configurable recent time window.
- The system must summarize imported data into useful patterns, such as workout frequency and activity mix.

### Events

- The system must allow the user to create, edit, and remove upcoming events.
- The system must store event type, target date, priority, and notes.
- The system must support at least the initial event types listed in this document.

### Recommendations

- The system must generate lifting recommendations based on event type plus recent workout history.
- The system must organize recommendations into a weekly plan format.
- The system should provide a brief explanation for why each exercise is recommended.
- The system should remain rules-based and explainable in the initial version.

### Progress Tracking

- The system must let the user mark recommended workouts complete.
- The system should use completion history to keep future recommendations relevant.

## Non-Functional Requirements

- The first version should be optimized for iPhone because Apple Health access is central to the product.
- The app should feel fast and lightweight, with minimal setup friction.
- Recommendations should be understandable and transparent rather than black-box.
- The app should degrade gracefully if Apple Health data is sparse or incomplete.

## Assumptions

- Apple Health workout history provides enough signal to generate useful baseline recommendations.
- A simple rules-based recommendation engine is sufficient for the MVP.
- A narrow set of supported event types is enough to validate the concept.
- Users care more about actionable guidance than about broad dashboards or analytics.

## Risks

- Historical lifting data may be incomplete if gym workouts were not consistently recorded in Apple Health.
- Recommendation quality may feel generic if event-to-exercise mappings are too shallow.
- Multiple simultaneous events could introduce prioritization complexity quickly.
- Apple Health permission and platform constraints may narrow the initial platform strategy.

## Success Criteria

The MVP is successful if it enables the user to:

- connect Apple Health successfully
- add an upcoming event in under a minute
- receive a credible weekly lifting plan tied to that event
- understand why the recommendations were made
- continue using the app as a planning tool for multiple upcoming activities

## Open Questions

- How far back should workout history be considered by default: 4 weeks, 8 weeks, or 12 weeks?
- How should the app resolve conflicting priorities across multiple upcoming events?
- How opinionated should recommendations be about sets, reps, and progression in the first version?
- Should manual workout entry exist in MVP as a fallback for missing Health data?

## Initial Build Recommendation

Start with the smallest credible loop:

1. Connect Apple Health.
2. Import recent workouts.
3. Add one supported upcoming event.
4. Produce a weekly lifting recommendation with explanations.
5. Track completion.

If that loop feels useful, the next step is expanding event support, improving recommendation quality, and introducing more adaptive planning.
