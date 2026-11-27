import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechi/app/mechi_app.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/account/session.dart';
import 'package:mechi/main.dart' as app;

import 'connected_driver_test.dart' as fixture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native Firebase enrolment, email verification, password reset and phone OTP',
    (tester) async {
      expect(fixture.project, 'demo-mechi-test');
      expect(fixture.emulatorPort, 9199);
      final run = DateTime.now().microsecondsSinceEpoch;
      final email = 'register-$run@example.invalid';
      final project = fixture.project;
      await app.main();
      await tester.pump();
      // The simulator keychain can outlive an earlier ephemeral emulator.
      final initialContainer = ProviderScope.containerOf(
        tester.element(find.byType(MechiApp)),
      );
      await initialContainer.read(apiProvider)!.auth.signOut();
      await fixture.wait(tester, find.text('Sign in'));
      await fixture.tap(tester, 'Create an account');
      await fixture.enter(tester, 'Email', email);
      await fixture.enter(tester, 'Password', fixture.fictionalPassword);
      await fixture.tap(tester, 'Create account');
      await fixture.wait(tester, find.text('I verified my email'));

      Future<Map<String, dynamic>> emailCode(String type) async {
        for (var attempt = 0; attempt < 25; attempt++) {
          final result =
              await fixture.emulator(
                    'GET',
                    'emulator/v1/projects/$project/oobCodes',
                  )
                  as Map<String, dynamic>;
          final matches = (result['oobCodes'] as List)
              .cast<Map<String, dynamic>>()
              .where(
                (entry) =>
                    entry['email'] == email && entry['requestType'] == type,
              );
          if (matches.isNotEmpty) return matches.last;
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        throw StateError('No matching emulator email action');
      }

      final verify = await emailCode('VERIFY_EMAIL');
      await fixture.emulator(
        'POST',
        'identitytoolkit.googleapis.com/v1/accounts:update?key=fixture',
        {'oobCode': verify['oobCode']},
      );
      await fixture.tap(tester, 'I verified my email');
      await fixture.wait(tester, find.text('Enrol as Driver'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MechiApp)),
      );
      final api = container.read(apiProvider)!;
      expect((await api.request<Json>('GET', 'auth/me'))['email'], email);
      await container.read(sessionProvider.notifier).signOut();
      await fixture.wait(tester, find.text('Sign in'));

      await fixture.enter(tester, 'Email', email);
      await fixture.tap(tester, 'Reset password');
      await fixture.wait(
        tester,
        find.textContaining('check your email for reset'),
      );
      expect((await emailCode('PASSWORD_RESET'))['oobCode'], isNotEmpty);

      final phoneSuffix = (run % 1000000).toString().padLeft(6, '0');
      final phone = '+263770$phoneSuffix';
      await fixture.tap(tester, 'Use phone');
      await fixture.enter(tester, 'Phone number', phone);
      await fixture.tap(tester, 'Send verification code');
      await fixture.wait(tester, find.text('Verify phone'));
      final sms =
          await fixture.emulator(
                'GET',
                'emulator/v1/projects/$project/verificationCodes',
              )
              as Map<String, dynamic>;
      final match = (sms['verificationCodes'] as List)
          .cast<Map<String, dynamic>>()
          .lastWhere((entry) => entry['phoneNumber'] == phone);
      await fixture.enter(tester, 'Verification code', match['code'] as String);
      await fixture.tap(tester, 'Verify phone');
      await fixture.wait(tester, find.text('Enrol as Driver'));
      expect((await api.request<Json>('GET', 'auth/me'))['phone'], phone);
      await container.read(sessionProvider.notifier).signOut();
    },
  );
}
