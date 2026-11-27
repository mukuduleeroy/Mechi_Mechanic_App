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

  testWidgets('independent Driver sees the live Mechanic and replies', (
    tester,
  ) async {
    expect(fixture.project, 'demo-mechi-test');
    final api = (await BackendConfiguration.current.initialize())!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await api.auth.signOut();
    await api.auth.signInWithEmailAndPassword(
      email: email('driver'),
      password: fixture.fictionalPassword,
    );
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
    await fixture.wait(tester, find.text('Quick actions'));
    await tester.tap(find.byTooltip('Job history'));
    final enRoute = find.text('En route');
    for (
      var attempt = 0;
      attempt < 150 && enRoute.evaluate().isEmpty;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await fixture.tap(tester, 'En route');
    final job =
        (await api.request<List<dynamic>>('GET', 'jobs')).single as Json;
    expect(find.text(job['id'] as String), findsOneWidget);
    await fixture.wait(tester, find.text('Current observation'));
    await tester.ensureVisible(find.text('Local schematic'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('job-071-concurrent-driver-map');
    final coordinates = <String>{};
    for (var attempt = 0; attempt < 32 && coordinates.length < 2; attempt++) {
      final tracking = await api.request<Json>(
        'GET',
        "jobs/${job['id']}/tracking",
      );
      if (tracking['position'] case final Json fix) {
        final coordinate = "${fix['latitude']}, ${fix['longitude']}";
        if (find.text(coordinate).evaluate().isNotEmpty) {
          coordinates.add(coordinate);
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(coordinates, hasLength(2));

    Future<void> reply(String message) async {
      await fixture.tap(tester, 'Send message');
      await fixture.enter(tester, 'Message', message);
      await fixture.tap(tester, 'Submit');
      await fixture.wait(tester, find.text(message));
    }

    await reply('Concurrent Driver received the tracked position');
    final stale = find.text('Location unavailable or stale');
    for (var attempt = 0; attempt < 26 && stale.evaluate().isEmpty; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(stale, findsOneWidget);
    await tester.ensureVisible(find.text('Local schematic'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('job-071-tracking-stale');
    await fixture.wait(tester, find.text('Current observation'));
    await reply('Driver tracking recovered');
    await api.auth.signOut();
  });
}
