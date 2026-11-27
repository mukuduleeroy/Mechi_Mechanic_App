import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechi/app/mechi_app.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/garage/garage_state.dart';
import 'package:mechi/features/mechanic/mechanic_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connected_driver_test.dart' as fixture;

const run = String.fromEnvironment('MECHI_MECHANIC_FIXTURE_ID');

class FixtureDocumentDevice extends NativeMechanicDevice {
  @override
  Future<PrivateUpload?> pickDocument(int maxBytes) async => PrivateUpload(
    'synthetic-qualification.pdf',
    'application/pdf',
    Uint8List.fromList(
      utf8.encode('%PDF-1.4\n% Synthetic simulator qualification\n%%EOF\n'),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'connected mechanic onboarding, review, availability and role switching',
    (tester) async {
      expect(fixture.project, 'demo-mechi-test');
      expect(run, matches(RegExp(r'^[a-f0-9]{16}$')));
      final email = 'p05-mechanic-$run@example.invalid';
      await fixture.provisionVerified(email);
      final api = (await BackendConfiguration.current.initialize())!;
      await api.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(api),
            preferencesProvider.overrideWithValue(prefs),
            mechanicDeviceProvider.overrideWithValue(FixtureDocumentDevice()),
          ],
          child: const MechiApp(),
        ),
      );
      await fixture.signIn(tester, email);
      await fixture.wait(tester, find.text('Enrol as Mechanic'));
      await fixture.tap(tester, 'Enrol as Mechanic');
      await fixture.enter(tester, 'Display name', 'Synthetic Workshop');
      await fixture.tap(tester, 'Save Mechanic role');
      await fixture.wait(
        tester,
        find.textContaining('Mechanic verification: draft'),
      );
      await binding.takeScreenshot('01-mechanic-onboarding');
      expect(find.text('Go available'), findsNothing);

      Future<void> go(String name, String title) async {
        await fixture.tap(tester, name);
        await fixture.wait(tester, find.text(title));
      }

      Future<void> back() async {
        await tester.tap(find.byTooltip('Back').last);
        await tester.pumpAndSettle();
      }

      Future<void> status(String value) async {
        for (var attempt = 0; attempt < 28; attempt++) {
          if (find.textContaining(value).evaluate().isNotEmpty) return;
          final refresh = find.text('Refresh status').hitTestable();
          if (refresh.evaluate().isNotEmpty) await tester.tap(refresh.first);
          await tester.pumpAndSettle();
          await Future<void>.delayed(const Duration(milliseconds: 850));
        }
        expect(find.textContaining(value), findsWidgets);
      }

      await go('Personal information', 'Personal information');
      await binding.takeScreenshot('02-personal-information');
      await back();
      await go('Professional information', 'Professional information');
      await fixture.enter(
        tester,
        'Professional biography',
        'Fictional automotive technician for local tests.',
      );
      await fixture.enter(tester, 'Years of experience', '6');
      await binding.takeScreenshot('03-professional-information');
      await fixture.tap(tester, 'Save details');
      await fixture.wait(tester, find.text('Save details'));
      await back();

      await go('Qualifications', 'Qualifications');
      await fixture.tap(tester, 'Add qualification');
      await fixture.enter(
        tester,
        'Qualification title',
        'Synthetic certificate',
      );
      await fixture.enter(tester, 'Institution', 'Fixture Technical Institute');
      await fixture.tap(tester, 'Save qualification');
      await fixture.wait(tester, find.text('Synthetic certificate'));
      await binding.takeScreenshot('04-qualifications');
      await back();

      await go('Verification documents', 'Verification documents');
      await fixture.tap(tester, 'Linked qualification');
      await fixture.tap(tester, 'Synthetic certificate');
      await fixture.tap(tester, 'Choose private file');
      await fixture.wait(tester, find.text('synthetic-qualification.pdf'));
      await binding.takeScreenshot('05-private-document');
      final transport = api.dio.httpClientAdapter;
      api.dio.httpClientAdapter = fixture.OfflineAdapter();
      try {
        await fixture.tap(tester, 'Upload document');
        await fixture.wait(
          tester,
          find.text('Cannot reach Mechi. Check your connection and retry.'),
        );
        expect(find.text('synthetic-qualification.pdf'), findsOneWidget);
      } finally {
        api.dio.httpClientAdapter = transport;
      }
      await fixture.tap(tester, 'Upload document');
      await fixture.wait(tester, find.text('PENDING · application/pdf'));
      final uploaded = (await api.request<List<dynamic>>(
        'GET',
        'mechanics/me/documents',
      )).cast<Json>();
      expect(uploaded, hasLength(1));
      expect(uploaded.single['qualificationId'], isNotNull);
      await back();

      await go('Supported services', 'Supported services');
      await fixture.tap(tester, 'Tyres and punctures');
      await fixture.tap(tester, 'Save selection');
      await binding.takeScreenshot('06-service-selection');
      await back();
      await go('Operating areas', 'Operating areas');
      await fixture.tap(tester, 'Synthetic simulator coverage');
      await fixture.tap(tester, 'Save selection');
      await binding.takeScreenshot('07-operating-areas');
      await back();

      await go('Review and submit', 'Review application');
      await binding.takeScreenshot('08-verification-submission');
      await fixture.tap(tester, 'Confirm and submit');
      await fixture.wait(
        tester,
        find.textContaining('Mechanic verification: submitted'),
      );
      await binding.takeScreenshot('09-pending-verification');
      await status('Mechanic verification: changes required');
      await binding.takeScreenshot('10-changes-required');
      await go('Professional information', 'Professional information');
      await fixture.enter(
        tester,
        'Professional biography',
        'Corrected fictional biography for the manual review test.',
      );
      await fixture.tap(tester, 'Save details');
      await back();
      await go('Review and submit', 'Review application');
      await fixture.tap(tester, 'Confirm and submit');
      await status('Mechanic dashboard');
      await binding.takeScreenshot('11-approved-dashboard');
      await fixture.tap(tester, 'Go available');
      await fixture.wait(tester, find.text('Go offline'));
      expect(
        (await api.request<Json>('GET', 'mechanics/me/availability'))['status'],
        'AVAILABLE',
      );
      await fixture.tap(tester, 'Go offline');
      await fixture.wait(tester, find.text('Go available'));

      await go('Professional profile', 'Professional profile');
      await binding.takeScreenshot('12-professional-profile');
      await fixture.tap(tester, 'Choose role');
      await fixture.wait(tester, find.text('Enrol as Driver'));
      await binding.takeScreenshot('13-role-switching');
      await fixture.tap(tester, 'Enrol as Driver');
      await fixture.enter(tester, 'First name', 'Fictional');
      await fixture.enter(tester, 'Last name', 'Mechanic');
      await fixture.tap(tester, 'Save Driver role');
      await fixture.wait(tester, find.text('Edit personal details'));
      await fixture.tap(tester, 'Edit personal details');
      await fixture.tap(tester, 'Save profile');
      await fixture.wait(tester, find.text('Hello, Fictional Mechanic'));
      await api.request<Json>(
        'POST',
        'vehicles',
        body: {
          'id': vehicleRequestId(),
          'make': 'Fixture',
          'model': 'Utility',
          'year': 2015,
          'plate': 'P05 TEST',
          'colour': 'Blue',
        },
      );
      await tester.tap(find.byTooltip('Profile'));
      await fixture.wait(tester, find.text('Choose role'));
      await fixture.tap(tester, 'Choose role');
      await fixture.wait(tester, find.text('Mechanic'));
      await fixture.tap(tester, 'Mechanic');
      await fixture.wait(tester, find.text('Mechanic dashboard'));
      expect(
        (await api.request<Json>('GET', 'mechanics/me'))['displayName'],
        'Synthetic Workshop',
      );
      await tester.tap(find.byTooltip('Earnings'));
      await fixture.wait(
        tester,
        find.text('Earnings and payouts are unavailable.'),
      );
      await binding.takeScreenshot('14-unavailable-earnings');
      expect(
        (await api.request<List<dynamic>>('GET', 'vehicles')).single['plate'],
        'P05 TEST',
      );
      Future<void> expectDenied(Future<Object?> request, int status) async {
        try {
          await request;
          fail('Request unexpectedly succeeded');
        } catch (error) {
          expect(ApiFailure.of(error).status, status);
        }
      }

      final restricted = 'p05-restricted-$run@example.invalid';
      await fixture.provisionVerified(restricted);
      await api.auth.signOut();
      await fixture.signIn(tester, restricted);
      await fixture.wait(tester, find.text('Enrol as Mechanic'));
      await fixture.tap(tester, 'Enrol as Mechanic');
      await fixture.enter(tester, 'Display name', 'Restricted Fixture');
      await fixture.tap(tester, 'Save Mechanic role');
      await fixture.wait(tester, find.text('Mechanic onboarding'));
      await expectDenied(
        api.request<Json>(
          'GET',
          "mechanics/me/documents/${uploaded.single['id']}",
        ),
        404,
      );
      await expectDenied(
        api.request<Json>(
          'PATCH',
          'mechanics/me/availability',
          body: {'status': 'AVAILABLE'},
        ),
        403,
      );
      await api.auth.signOut();
      await fixture.signIn(tester, email);
      await fixture.wait(tester, find.text('Mechanic'));
      await fixture.tap(tester, 'Mechanic');
      await status('Mechanic verification: suspended');
      expect(find.text('Go available'), findsNothing);
      await expectDenied(
        api.request<Json>(
          'PATCH',
          'mechanics/me/availability',
          body: {'status': 'AVAILABLE'},
        ),
        403,
      );
      await api.auth.signOut();
    },
  );
}
