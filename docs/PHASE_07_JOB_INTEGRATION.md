# Phase 07 job integration

Connected Driver and Mechanic job details compose approved Mechi cards, timeline rows, notices, forms, selectors and actions. REST owns versioned commands and reads. Authenticated Socket.IO signals job, location, invitation and quotation changes. The app resynchronises over REST and keeps foreground polling as a fallback. Job subscriptions resume from the last observed event version.

## Tracking and service contact

The existing local map projects the authorised job destination and Mechanic observations, fits the displayed points, rotates the approved vehicle marker by heading and supports pan, zoom and recentering. Tracking shows the last observation, marks it stale after 20 seconds and stops when travelling ends. The local backdrop is schematic. Fixture polylines are identified as synthetic and their sample travel times and distances are hidden. Live basemap rendering and live Google Routes verification still require separate work.

The Mechanic can open navigation to the assigned destination. iOS attempts Apple Maps and falls back to a browser directions URL. Android targets Google Maps and falls back to a system handler. The native iOS bridge returned success on the simulator for a synthetic destination. The test did not distinguish which handler accepted the URL. Dialling requires a user tap and an active job with a verified contact number. The simulator exercised the no-contact state. Host tests covered dialler method dispatch with a synthetic number. Physical call verification remains outstanding.

## Scheduling and exceptions

Home service uses the approved themed Flutter date picker and the existing selection sheet for backend-derived appointment windows. Mechanics can choose working-window dates and times with the approved themed Flutter pickers in the device timezone. They can also enter an explicit timestamp with an offset. The server interprets the date in the service region's timezone. The selected interval is shown in UTC. Submitting a request or choosing a quotation does not reserve the slot until the backend accepts the quote. Mechanics manage dated working windows and use the Jobs workspace to activate an eligible booking. Appointment cards display the associated job's status once activated.

Assigned cancellation requires a reason and confirmation. It uses a repeatable request key and refreshes authoritative state after an interrupted response. A Mechanic can record an unsuccessful service with a structured outcome and notes. A Driver can raise an eligible dispute, including a no-show report, and view its review status. A restricted local operator can record the resolution. Notifications are available in both workspaces and opening a notice marks it read and opens the appropriate job.

## Local verification

Use the backend's simulator runner with `MECHI_VERIFY_JOB_EXECUTION=true MECHI_VERIFY_PHASE_071=true` for the extended journey. For the focused concurrent tracking test, set `MECHI_VERIFY_JOB_EXECUTION=true MECHI_VERIFY_TRACKING_PAIR=true` and set `MECHI_OBSERVER_SIMULATOR` to the UUID of a second booted iPhone. It sets up the synthetic assignment over authenticated REST, then runs independent Driver and Mechanic app containers. The iPhone 17e Driver matched two displayed positions against authoritative observations from the iPhone 18 Pro Mechanic. The Driver saw the stale indicator after the Mechanic went to the background, then confirmed recovery in the job conversation after the Mechanic returned and shared another fix. The local fixture uses an isolated synthetic service region. Set `MECHI_VERIFY_JOB_EXECUTION=true MECHI_VERIFY_SCHEDULED_OPERATIONS=true` for the focused single-iPhone journey through activation, unsuccessful service, notification navigation and dispute submission. It advances only the synthetic booking into its execution window. Set `MECHI_VERIFY_JOB_EXECUTION=true MECHI_VERIFY_ASSIGNED_CANCELLATION=true` for the connected cancellation recovery case. The test discards the committed response and verifies a single authoritative cancellation. The ordinary app was reinstalled on both simulators from `lib/main.dart` with the local development API and Auth Emulator configuration.

Mobile push is opt-in through `MECHI_ENABLE_PUSH=true`. Live FCM/APNs provisioning and delivery, background tracking, Android and physical-device checks remain outstanding.

[Phase 07.1 simulator captures](screenshots/phase071/README.md)
