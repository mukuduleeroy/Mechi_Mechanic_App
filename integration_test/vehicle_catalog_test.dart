import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/features/garage/garage_state.dart';
import 'package:mechi/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('browse, add and repaint a catalog vehicle', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Vehicles'));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Browse catalog');
    await tapLabel(tester, 'DE · Example year 2009');

    final plate = find.byType(TextFormField).at(3);
    await tester.ensureVisible(plate);
    await tester.enterText(plate, 'TEST 2009');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final blue = find.widgetWithText(ChoiceChip, 'Blue');
    await tester.ensureVisible(blue);
    await tester.pumpAndSettle();
    await tester.tap(blue);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Save vehicle');
    expect(find.text('Mazda Demio DE'), findsOneWidget);
    expect(find.text('Blue'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Mazda Demio DE · 2009'), findsOneWidget);
    expect(find.text('Blue'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(LocalVehicles(prefs).load().active.colour, 'Blue');
  });
}
