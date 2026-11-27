import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/app/mechi_app.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/account/session.dart';
import 'package:mechi/main.dart' as app;

const emulatorHost = String.fromEnvironment('MECHI_AUTH_EMULATOR_HOST');
const emulatorPort = int.fromEnvironment(
  'MECHI_AUTH_EMULATOR_PORT',
  defaultValue: 9199,
);
const project = String.fromEnvironment('MECHI_FIREBASE_PROJECT');
const fictionalPassword = 'MechiLocalFixture-2026!';

Future<dynamic> emulator(
  String method,
  String path, [
  Map<String, Object?>? body,
]) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://$emulatorHost:$emulatorPort/$path'),
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    expect(
      response.statusCode,
      200,
      reason: 'Auth emulator fixture action was rejected',
    );
    return jsonDecode(await utf8.decoder.bind(response).join());
  } finally {
    client.close();
  }
}

Future<void> wait(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 90 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  final matches = find.text(label);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(matches, 120, maxScrolls: 15);
    await tester.pumpAndSettle();
  }
  final finder = matches.last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final finder = find
      .byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      )
      .last;
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 100, maxScrolls: 10);
  }
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String email) async {
  await wait(tester, find.text('Sign in'));
  await enter(tester, 'Email', email);
  await enter(tester, 'Password', fictionalPassword);
  await tap(tester, 'Sign in');
}

Future<void> provisionVerified(String email) async {
  final signUp =
      await emulator(
            'POST',
            'identitytoolkit.googleapis.com/v1/accounts:signUp?key=fixture',
            {
              'email': email,
              'password': fictionalPassword,
              'returnSecureToken': true,
            },
          )
          as Map<String, dynamic>;
  await emulator(
    'POST',
    'identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=fixture',
    {'requestType': 'VERIFY_EMAIL', 'idToken': signUp['idToken']},
  );
  final codes =
      await emulator('GET', 'emulator/v1/projects/$project/oobCodes')
          as Map<String, dynamic>;
  final match = (codes['oobCodes'] as List)
      .cast<Map<String, dynamic>>()
      .lastWhere(
        (value) =>
            value['email'] == email && value['requestType'] == 'VERIFY_EMAIL',
      );
  await emulator(
    'POST',
    'identitytoolkit.googleapis.com/v1/accounts:update?key=fixture',
    {'oobCode': match['oobCode']},
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'connected driver, returning session, second account and dual roles',
    (tester) async {
      expect(project, 'demo-mechi-test');
      expect(emulatorPort, 9199);
      final unique = DateTime.now().microsecondsSinceEpoch;
      final first = 'driver-$unique@example.invalid';
      final second = 'other-$unique@example.invalid';
      await provisionVerified(first);
      await provisionVerified(second);
      await app.main();
      await tester.pump();
      // The simulator keychain can outlive an earlier ephemeral emulator.
      final initialContainer = ProviderScope.containerOf(
        tester.element(find.byType(MechiApp)),
      );
      await initialContainer.read(apiProvider)!.auth.signOut();
      await wait(tester, find.text('Sign in'));
      await binding.takeScreenshot('01-authentication');
      await signIn(tester, first);
      await wait(tester, find.text('Enrol as Driver'));
      await binding.takeScreenshot('02-role-selection');
      await tap(tester, 'Enrol as Driver');
      await enter(tester, 'First name', 'Mira');
      await enter(tester, 'Last name', 'Fixture');
      await tap(tester, 'Save Driver role');

      await wait(tester, find.text('Edit personal details'));
      await binding.takeScreenshot('03-driver-onboarding');
      await tap(tester, 'Edit personal details');
      await tap(tester, 'Save profile');
      await wait(tester, find.text('Hello, Mira Fixture'));
      await wait(tester, find.text('No vehicle added'));
      await tester.tap(find.byTooltip('Vehicles'));
      await tester.pumpAndSettle();
      await tap(tester, 'Browse catalog');
      await wait(tester, find.text('Honda'));
      await binding.takeScreenshot('04-catalogue');
      await tap(tester, 'Honda');
      await wait(tester, find.text('Fit'));
      await tap(tester, 'Fit');
      await wait(tester, find.text('GK'));
      await tap(tester, 'GK');
      await wait(tester, find.text('Save vehicle'));
      await binding.takeScreenshot('05-add-vehicle');
      await enter(tester, 'Registration', 'MECHI 040');
      await enter(tester, 'Colour', 'White');
      await tap(tester, 'Save vehicle');
      await wait(tester, find.text('Honda Fit'));
      await binding.takeScreenshot('06-your-vehicles');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MechiApp)),
      );
      final api = container.read(apiProvider)!;
      await tester.tap(find.byTooltip('Edit Honda Fit'));
      await wait(tester, find.text('Edit vehicle'));
      await binding.takeScreenshot('07-edit-vehicle');
      await tap(tester, 'Set as default');
      await wait(tester, find.text('Your vehicles'));
      final vehicles = (await api.request<List<dynamic>>(
        'GET',
        'vehicles',
      )).cast<Json>();
      expect(vehicles.single['plate'], 'MECHI 040');
      expect(vehicles.single['isDefault'], true);
      await tester.tap(find.byTooltip('Back'));
      await wait(tester, find.text('Honda Fit · 2015'));
      await binding.takeScreenshot('07-dashboard');

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await wait(tester, find.text('Edit personal details'));
      await binding.takeScreenshot('08-profile');
      await tap(tester, 'Edit personal details');
      await enter(tester, 'First name', 'Mira Updated');
      await tap(tester, 'Save profile');
      await wait(tester, find.text('Mira Updated Fixture'));
      await tap(tester, 'Add emergency contact');
      await wait(tester, find.text('Save contact'));
      await binding.takeScreenshot('09-emergency-contact');
      await enter(tester, 'Name', 'Fictional Contact');
      await enter(tester, 'Phone', '0771000006');
      await enter(tester, 'Relationship', 'Friend');
      await tap(tester, 'Save contact');
      await wait(tester, find.text('Fictional Contact'));

      await tap(tester, 'Choose role');
      await wait(tester, find.text('Enrol as Mechanic'));
      await tap(tester, 'Enrol as Mechanic');
      await enter(tester, 'Display name', 'Fixture Workshop');
      await tap(tester, 'Save Mechanic role');
      await wait(tester, find.textContaining('Mechanic verification: draft'));
      await tap(tester, 'Choose role');
      await wait(tester, find.text('Driver'));
      await tap(tester, 'Driver');
      await wait(tester, find.text('Hello, Mira Updated Fixture'));

      await tap(tester, 'Request assistance');
      await tap(tester, 'Problem category');
      await wait(tester, find.text('Tyres and punctures'));
      await binding.takeScreenshot('10-service-categories');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await container.read(sessionProvider.notifier).signOut();
      await wait(tester, find.text('Sign in'));
      await signIn(tester, second);
      await wait(tester, find.text('Enrol as Driver'));
      expect(find.textContaining('Mira'), findsNothing);
      await tap(tester, 'Enrol as Driver');
      await enter(tester, 'First name', 'Tari');
      await enter(tester, 'Last name', 'Fixture');
      await tap(tester, 'Save Driver role');
      await wait(tester, find.text('Edit personal details'));
      await tap(tester, 'Edit personal details');
      await tap(tester, 'Save profile');
      await wait(tester, find.text('Hello, Tari Fixture'));
      expect(find.text('MECHI 040'), findsNothing);
      await tester.tap(find.byTooltip('Vehicles'));
      await wait(tester, find.text('Add vehicle'));
      await tap(tester, 'Add vehicle');
      await enter(tester, 'Make', 'Sample');
      await enter(tester, 'Model', 'Utility');
      await enter(tester, 'Year', '2003');
      await enter(tester, 'Registration', 'MECHI 041');
      await enter(tester, 'Colour', 'Blue');
      await tap(tester, 'Save vehicle');
      await wait(tester, find.text('Sample Utility'));
      expect(find.textContaining('MECHI 040'), findsNothing);
      final otherVehicles = (await api.request<List<dynamic>>(
        'GET',
        'vehicles',
      )).cast<Json>();
      expect(otherVehicles.single['plate'], 'MECHI 041');
      await container.read(sessionProvider.notifier).signOut();
      await wait(tester, find.text('Sign in'));
      await signIn(tester, first);
      await wait(tester, find.text('Driver'));
      await tap(tester, 'Driver');
      await wait(tester, find.text('Honda Fit · 2015'));
      expect(find.text('Hello, Mira Updated Fixture'), findsOneWidget);
      final restored = (await api.request<List<dynamic>>(
        'GET',
        'vehicles',
      )).cast<Json>().single;
      expect(restored['isDefault'], true);
      await container.read(sessionProvider.notifier).signOut();
    },
  );
}

class OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated loss of connection',
    );
  }

  @override
  void close({bool force = false}) {}
}
