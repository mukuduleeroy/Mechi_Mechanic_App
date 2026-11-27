# Phase 04 Flutter driver integration

The existing Flutter, Riverpod and GoRouter app uses Firebase Core 5.2.0, Firebase Auth 7.1.0 and Dio 5.11.1. The packages resolved under Flutter 3.50.1 and Dart 3.14.0. The app keeps its approved layouts, logo, vehicle renderer and components. The existing form field supports obscured password input through a behavioural option.

## Run locally

Start the backend native services, apply the development migrations and run db:seed:dev in the backend checkout for the small Toyota and Honda catalogue. Run npm run firebase:emulator and npm run start:dev in separate backend terminals. In this checkout, run flutter pub get and launch the iOS simulator build:

```sh
flutter run -d <simulator-id> \
  --dart-define=MECHI_ENV=development \
  --dart-define=MECHI_API_URL=http://127.0.0.1:3000/api/v1 \
  --dart-define=MECHI_FIREBASE_PROJECT=demo-mechi-dev \
  --dart-define=MECHI_AUTH_EMULATOR_HOST=127.0.0.1
```

For Android Emulator use 10.0.2.2 for both hosts. A physical Android device can use an authorised adb reverse tunnel for ports 3000 and 9099 with loopback addresses. A physical iOS device can use an approved HTTPS API and dedicated real development Firebase project. Android Debug permits cleartext only to the listed local domains. iOS Debug permits HTTP to loopback via its own Info plist. Release builds require HTTPS and a live Firebase project. [Firebase emulator networking](https://firebase.google.com/docs/emulator-suite/connect_auth) · [Apple ATS exception domains](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAppTransportSecurity/NSExceptionDomains)

| Define | Purpose |
| --- | --- |
| MECHI_ENV | development, test, staging or production. Release accepts staging and production. |
| MECHI_API_URL | Base URL ending in /api/v1. |
| MECHI_FIREBASE_PROJECT | demo-mechi-dev locally, demo-mechi-test in isolated tests, otherwise the real project assigned to the environment. |
| MECHI_AUTH_EMULATOR_HOST and MECHI_AUTH_EMULATOR_PORT | Local emulator address and port. Development defaults to 9099. Tests use 9199. |
| MECHI_FIREBASE_APP_ID, MECHI_FIREBASE_API_KEY, MECHI_FIREBASE_SENDER | Required for a registered live Firebase client. Keep service-account credentials on the backend. |
| MECHI_FIXTURES | Explicitly runs the disconnected design prototype in a local debug build for the existing visual test suite. |

The Firebase client SDK restores sign-in state and manages Firebase credentials. Riverpod resolves the server account, profile, grants and role selection before GoRouter enables the driver routes. The Driver profile and garage use Dio and the driver API. Catalogue entries preserve generation and use approved bundled vehicle images or their existing fallback. Displayed contact identity comes from the account API. Link additional methods to the same Firebase UID using the client SDK before syncing verified contacts. Contact conflicts are routed to support.

Driver data and previously loaded catalogue entries are held in session-scoped memory. Offline fallback is shown as previously loaded data. Private requests are cancelled or discarded if the Firebase UID changes, and old repositories cannot write under a new UID. The client retries expired-token reads and idempotent bootstrap once after coordinating refresh. Profile, contact and vehicle writes require server confirmation. The app keeps no offline write queue. Local garage selection is independent of the server default. A restored session uses the current default when present. The existing profile offers sign-out and verified identity sync. The underlying Phase 03 client includes all-session revocation for a future approved UI affordance.

Authenticated mode displays service choices from the backend and a dashboard map preview with no live mechanic or route. Service submission, job history and mechanic operations show unavailable states. Separate development fixtures retain the approved offline demo.

## Tests

Run dart format, flutter analyze and flutter test. Existing disconnected integration journeys require MECHI_ENV=development and MECHI_FIXTURES=true. The connected journey in integration_test/connected_driver_test.dart uses the real client SDK and requires the isolated Auth emulator on port 9199 and a backend configured for the mechi_test database and Redis, for example on port 3006. Seed the test catalogue with npm run db:seed:test. Run flutter drive with test_driver/capture.dart, that integration target, MECHI_ENV=test, the test project and emulator defines, and set MECHI_SCREENSHOT_DIR to a dedicated capture folder. The journey uses fictional identities verified through the emulator. The same settings with integration_test/emulator_identity_test.dart exercise the registration form, email verification, password-reset request and phone verification. Native build results and any unfinished device testing are recorded in the backend Phase 04 results.

See the [connected iOS simulator captures](screenshots/phase04/README.md).
