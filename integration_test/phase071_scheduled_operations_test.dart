import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechi/app/mechi_app.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/garage/garage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connected_driver_test.dart' as fixture;
import 'connected_marketplace_test.dart' show email;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'participants activate, record and dispute an unsuccessful home service',
    (tester) async {
      expect(fixture.project, 'demo-mechi-test');
      final api = (await BackendConfiguration.current.initialize())!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(api),
            preferencesProvider.overrideWithValue(preferences),
          ],
          child: const MechiApp(),
        ),
      );
      Future<void> signIn(String participant, String home) async {
        await api.auth.signOut();
        await tester.pumpAndSettle();
        await api.auth.signInWithEmailAndPassword(
          email: email(participant),
          password: fixture.fictionalPassword,
        );
        await fixture.wait(tester, find.text(home));
      }

      if (const bool.fromEnvironment('MECHI_VERIFY_ASSIGNED_CANCELLATION')) {
        var lost = false;
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              final request = response.requestOptions;
              if (!lost &&
                  request.method == 'POST' &&
                  request.uri.path.endsWith('/cancel')) {
                lost = true;
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.connectionError,
                  ),
                );
              } else {
                handler.next(response);
              }
            },
          ),
        );
        await signIn('driver', 'Quick actions');
        await tester.tap(find.byTooltip('Job history'));
        await fixture.wait(tester, find.text('Confirmed assignment'));
        await fixture.tap(tester, 'Confirmed assignment');
        await fixture.wait(tester, find.text('Cancel assigned job'));
        await fixture.tap(tester, 'Cancel assigned job');
        await fixture.enter(
          tester,
          'Reason',
          'Connection was interrupted after cancellation',
        );
        await fixture.tap(tester, 'Submit');
        await fixture.tap(tester, 'Confirm');
        await fixture.wait(tester, find.text('Cancelled'));
        final rows = (await api.request<List<dynamic>>(
          'GET',
          'jobs',
        )).cast<Json>();
        expect(rows.single['status'], 'CANCELLED');
        expect(lost, isTrue);
        final history = (await api.request<List<dynamic>>(
          'GET',
          "jobs/${rows.single['id']}/timeline",
        )).cast<Json>();
        expect(
          history.where((entry) => entry['status'] == 'CANCELLED'),
          hasLength(1),
        );
        await fixture.wait(tester, find.text('Recorded reason'));
        await tester.ensureVisible(find.text('Recorded reason'));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('job-071-assigned-cancellation');
        await api.auth.signOut();
        return;
      }
      await signIn('farther', 'Mechanic dashboard');
      await tester.tap(find.byTooltip('Jobs'));
      await fixture.wait(tester, find.text('Activate appointment'));
      await fixture.tap(tester, 'Activate appointment');
      await fixture.wait(tester, find.text('Start journey'));
      await fixture.tap(tester, 'Start journey');
      await fixture.wait(tester, find.text('Confirm arrival'));
      await fixture.tap(tester, 'Confirm arrival');
      await fixture.enter(
        tester,
        'Reason',
        'Arrived at the scheduled destination',
      );
      await fixture.tap(tester, 'Submit');
      await fixture.wait(tester, find.text('Report unsuccessful service'));
      await fixture.tap(tester, 'Report unsuccessful service');
      await fixture.tap(tester, 'Service outcome');
      await fixture.tap(tester, 'Replacement parts unavailable');
      await fixture.enter(
        tester,
        'Reason',
        'The requested replacement was unavailable',
      );
      await fixture.tap(tester, 'Submit');
      final failure = find.text('Service unsuccessful');
      await fixture.wait(tester, failure);
      await tester.ensureVisible(failure.first);
      await fixture.wait(tester, failure);
      await binding.takeScreenshot('job-071-unsuccessful-service');

      await signIn('driver', 'Quick actions');
      await tester.tap(find.byTooltip('Notifications'));
      await fixture.wait(tester, find.text('Job updated'));
      await binding.takeScreenshot('job-071-notifications');
      final notices = (await api.request<List<dynamic>>(
        'GET',
        'notifications',
      )).cast<Json>();
      final latest = notices.first;
      expect(latest['readAt'], isNull);
      await tester.tap(find.text('Job updated').first);
      await fixture.wait(tester, failure);
      final after = (await api.request<List<dynamic>>(
        'GET',
        'notifications',
      )).cast<Json>();
      expect(
        after.firstWhere((item) => item['id'] == latest['id'])['readAt'],
        isNotNull,
      );
      await fixture.tap(tester, 'Raise a dispute');
      await fixture.enter(
        tester,
        'Reason',
        'Please review the reported outcome',
      );
      await fixture.tap(tester, 'Submit');
      final review = find.text('Awaiting operational review');
      await fixture.wait(tester, review);
      await tester.ensureVisible(review);
      await fixture.wait(tester, review);
      await binding.takeScreenshot('job-071-dispute');
      await api.auth.signOut();
    },
  );
}
