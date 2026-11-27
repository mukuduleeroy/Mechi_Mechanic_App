# Phase 06 marketplace integration

The connected assistance form uses registered vehicles, service-category IDs and a driver-confirmed foreground GPS observation. Home service remains unavailable. The Driver can reopen requests from Job history, view available offers and their exact item amounts, confirm one version, cancel an open search, and view the confirmed assignment. The Mechanic workspace shows owned invitations, a quotation editor, withdrawal and replacement actions, and confirmed assignments in Jobs.

The connected route composes the existing Screen, Panel, SettingsRow, SelectionField, MechiFormField, ActionButton, ChipLabel and notice patterns. Demo mode remains separate. All marketplace data and idempotency keys stay in memory. Account changes replace the state subtree and cancel the authenticated repository's in-flight reads. Foreground REST refresh defaults to four seconds, allows a build-time interval, bounds failure backoff and stops when the app pauses, the screen disposes or a Driver request reaches a terminal state. There is no background notification delivery. Manual coordinates can be confirmed through the API. This mobile flow uses foreground GPS.

For the iOS simulator journey, start local infrastructure and apply the test migrations in the backend. Build the backend and run `bash scripts/test-marketplace-ios.sh <booted-simulator-uuid>` from its checkout. It starts an isolated Firebase emulator and API, enables the dispatch worker, uses synthetic fixtures and captures the connected screens. It runs one simulator sequentially with both roles and a separate authenticated Mechanic REST client for the competing quotation. Use only the local test configuration.

See the [Phase 06 captures](screenshots/phase06/README.md).
