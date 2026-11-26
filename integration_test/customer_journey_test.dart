import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechi/main.dart' as app;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/journey.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('roadside request to paid receipt and review', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await app.main();
    await tester.pumpAndSettle();
    final capture = const bool.fromEnvironment('MECHI_CAPTURE')
        ? (String name) async {
            for (final image in find.byType(Image).evaluate()) {
              await precacheImage((image.widget as Image).image, image);
            }
            await tester.pumpAndSettle();
            await binding.takeScreenshot(name);
          }
        : null;
    if (capture != null) {
      for (final (label, screenshot) in [
        ('Vehicles', 'vehicles'),
        ('Profile', 'profile'),
        ('Job history', 'job-history'),
      ]) {
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
        await capture(screenshot);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      await capture('home');
    }
    await bookRepair(
      tester,
      capture: capture,
      captureProfiles: capture != null,
    );
    await payAndReview(tester, capture: capture);
  });
}
