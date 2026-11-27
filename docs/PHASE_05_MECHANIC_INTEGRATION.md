# Phase 05 Mechanic integration

The existing Flutter app routes to the Mechanic workspace only after Firebase identity, account bootstrap and server-authorised role selection. A single authorised role restores directly. Dual-role users can choose Driver or Mechanic without replacing either profile. Mechanic screens use the existing Mechi form, cards, rows, feedback, icons and floating navigation. Driver routes and goldens retain their original configuration.

Draft onboarding saves professional identity, biography, experience, qualifications, linked private evidence, service categories and operating areas on the backend. The review screen requests acknowledgement before submission. Submitted records display their backend status. Corrections unlock permitted draft fields. APPROVED unlocks the mechanic dashboard and operational controls. Rejected and suspended records remain restricted. The app displays unavailable states for requests, jobs and earnings.

Files use file_picker 13.4.1. Upload retries reuse a UUID and the same bytes while the form remains open. No private file bytes are kept in SharedPreferences or queued for later submission. Mechanic data and unsubmitted document bytes are scoped to the active session in memory. Local file-signature validation and authorization run on the backend.

Location uses geolocator 14.1.2. An explicit Go available action requests foreground permission and obtains a current location. While availability is confirmed and the workspace remains foregrounded, the client refreshes the point at one third of the backend freshness window. It stops on sign-out, role exit, backgrounding or permission and connection failure. The client tries to go offline on exit and warns when the backend has not confirmed it. Server-side age and coverage checks still determine effective availability. Android declares coarse and fine permissions. Apple uses When In Use usage text and the SwiftPM BYPASS_PERMISSION_LOCATION_ALWAYS=1 build setting.

## Development

Follow the [Phase 04 Flutter environment setup](PHASE_04_DRIVER_INTEGRATION.md). Enable MECHANIC_LOCAL_STORAGE=enabled in the local backend environment to attach synthetic documents. Only explicitly provisioned local operators may enable MECHANIC_LOCAL_REVIEW and review via the backend CLI. Real coverage remains inactive until approved.

Run dart format, flutter analyze and flutter test for host checks. From the backend checkout, after applying test migrations and building the server, run bash scripts/test-mechanic-ios.sh with a booted simulator UUID. This starts the isolated Firebase emulator on 9199 and the API on 3006, creates temporary synthetic coverage and an explicitly granted local operator, sets the simulator location and runs the connected test. The approved Driver fixture and connected tests retain their Phase 04 setup. The mechanic test injects a synthetic file through the picker boundary and sends the actual upload to the backend. Physical file-provider behaviour remains a manual check.

See the [simulator captures](screenshots/phase05/README.md).
