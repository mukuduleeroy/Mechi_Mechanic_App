# Architecture

`main.dart` initializes SharedPreferences and injects it through Riverpod. `MechiApp` owns GoRouter, the route transitions, and the application theme. Garage and assistance code live under `lib/features` with reusable Flutter widgets under `lib/core/design_system`.

The assistance domain owns job transitions and integer-cent quotes. Its controller enforces the active-job rule, commits a quote before booking, and serializes persisted job snapshots. Subsequent screens read the same saved job and amount. A payment enters processing before the simulator runs, so a second request against that job is ignored. A saved processing job reopens as a retryable failure after an interruption. Cash stays pending until the user simulates mechanic confirmation.

Repository interfaces cover vehicles, jobs, locations, mechanics, quotes, payments, receipts, and reviews. Local repositories and deterministic simulators are used in Phase 01. Presentation screens consume those interfaces through providers. The garage controller persists the vehicle list, active vehicle, fictional customer label, and preferences. A vehicle snapshot on each request keeps history readable after vehicle edits.

The demonstration date and prices are fixed, and arrival and repair use explicit controls so the journey can be repeated on demand. The route renderer and marker animation use a schematic offline map. SharedPreferences is a single-device prototype store. A production rollout needs authenticated customer and mechanic services, durable request and job events, dispatch and routing, verification, payment reconciliation, receipts, and consent-aware location and contact handling.
