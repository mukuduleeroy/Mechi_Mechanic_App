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
    'assigned Mechanic publishes a fix and receives the Driver reply',
    (tester) async {
      expect(fixture.project, 'demo-mechi-test');
      final api = (await BackendConfiguration.current.initialize())!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await api.auth.signOut();
      await api.auth.signInWithEmailAndPassword(
        email: email('farther'),
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
      await fixture.wait(tester, find.text('Mechanic dashboard'));
      await tester.tap(find.byTooltip('Jobs'));
      await fixture.tap(tester, 'Confirmed assignment');
      await fixture.tap(tester, 'Start journey');
      await fixture.tap(tester, 'Share foreground location');
      await fixture.wait(tester, find.text('Current observation'));
      await fixture.tap(tester, 'Request directions');
      final label = find.text('Local schematic · synthetic test route');
      await fixture.wait(tester, label);
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('job-071-concurrent-mechanic-map');
      final reply = find.text(
        'Concurrent Driver received the tracked position',
      );
      for (
        var attempt = 0;
        attempt < 100 && reply.evaluate().isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(reply, findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(seconds: 25));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await fixture.tap(tester, 'Share foreground location');
      final recovered = find.text('Driver tracking recovered');
      for (
        var attempt = 0;
        attempt < 45 && recovered.evaluate().isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(recovered, findsOneWidget);
      await api.auth.signOut();
    },
  );
}
