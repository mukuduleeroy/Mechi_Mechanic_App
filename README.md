# Mechi

Mechi is an offline Flutter customer prototype for roadside assistance and home vehicle service in Harare. Mechanics, jobs and payments are fictional. Example locations use familiar Harare place names.

## Run

Install Flutter stable 3.50.1 or a compatible Flutter release, then set up Xcode with an iOS simulator or Android Studio with an Android SDK and emulator.

```sh
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

Select a simulator or emulator ID from `flutter devices`. To launch an Android emulator first, use `flutter emulators` and `flutter emulators --launch <id>`. On macOS, start an iOS device in Simulator through Xcode. This project uses Flutter’s Swift Package Manager integration on iOS.

## Verify

```sh
dart format .
flutter analyze
flutter test
flutter test integration_test/customer_journey_test.dart -d <device-id>
flutter build ios --simulator
flutter build apk --debug
```

Goldens use a 390 × 844 logical viewport with the locally bundled fonts. Regenerate them with `flutter test --update-goldens` after reviewing intentional visual changes.

## Demo

Choose Request assistance, select a problem and an example Harare location, then open a mechanic’s profile and accept the itemized quote. Use the simulation controls to advance arrival and repair. Review and confirm completion, choose a payment method, and open the receipt. Submit a rating and revisit the job in Job history.

See the [demo guide](docs/PROTOTYPE_DEMO_GUIDE.md), [architecture](docs/architecture/ARCHITECTURE.md), [design tokens](docs/design-system/DESIGN_TOKENS.md), [reference mapping](docs/design-system/REFERENCE_MAPPING.md), and [implementation report](docs/IMPLEMENTATION_REPORT.md).

The map is schematic. Job tracking runs on explicit demo controls. Payments, identity verification, dispatch, and communications require production integrations. Demo records and preferences live on the device and are suitable only for fictional data.
