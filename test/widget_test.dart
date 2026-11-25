import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechi/app/mechi_app.dart';
import 'package:mechi/core/design_system/mechi_ui.dart';
import 'package:mechi/features/garage/garage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      (Mechi.sans, 'Inter.ttf'),
      (Mechi.mono, 'IBMPlexMono-Regular.ttf'),
      ('Lucide', 'lucide.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$asset'));
      await loader.load();
    }
  });
  Future<void> launch(
    WidgetTester tester, [
    Size size = const Size(390, 844),
  ]) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesProvider.overrideWithValue(preferences)],
        child: const MechiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> captureGolden(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (final image in find.byType(Image).evaluate()) {
        await precacheImage((image.widget as Image).image, image);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).hitTestable(),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('home, request, job, payment and receipt at 390 × 844', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Hello, Tadiwa M.'), findsOneWidget);
    await captureGolden(tester, 'home');
    await bookRepair(tester, capture: (name) => captureGolden(tester, name));
    await captureGolden(tester, 'payment');
    await payAndReview(tester);
    await captureGolden(tester, 'receipt');
    await tapLabel(tester, 'Done');
    await tester.pageBack();
    await tester.pumpAndSettle();
    if (find.byTooltip('Job history').evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Job history'));
    await tester.pumpAndSettle();
    expect(find.text('Reviewed'), findsWidgets);
    expect(find.text('Flat tyre'), findsOneWidget);
  });

  testWidgets(
    'small phone: map marker selects a mechanic and declines a quote',
    (tester) async {
      await launch(tester, const Size(320, 640));
      await tapLabel(tester, 'Request assistance');
      await tapLabel(tester, 'Problem category');
      await tapLabel(tester, 'Flat tyre');
      await tapLabel(tester, 'Service location');
      await tapLabel(tester, 'Avondale Shopping Centre');
      await tapLabel(tester, 'Find mechanics');
      await tester.tap(find.byTooltip('Nyasha Dube'));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'View profile');
      expect(find.text('Nyasha Dube'), findsOneWidget);
      await tapLabel(tester, 'Get quote');
      expect(find.text('\$34.00'), findsWidgets);
      await tapLabel(tester, 'Decline quote');
      expect(find.text('Nearby mechanics'), findsOneWidget);
    },
  );

  testWidgets('a saved paint change is visible in Vehicles and on Home', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byTooltip('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Toyota Corolla'));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Choose a vehicle model');
    final generation = find.text('GD · Example year 2005');
    await tester.scrollUntilVisible(
      generation,
      180,
      scrollable: find.descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tapLabel(tester, 'GD · Example year 2005');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Red'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Red'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Save vehicle');
    expect(find.text('Red'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Red'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final vehicle = LocalVehicles(prefs).load().active;
    expect(vehicle.name, 'Honda Fit GD');
    expect(vehicle.year, 2005);
    expect(vehicle.colour, 'Red');
    await captureGolden(tester, 'vehicle-paint');
  });

  testWidgets('design tokens and component states', (tester) async {
    expect(Mechi.theme.colorScheme.primary, Mechi.blue);
    expect(Mechi.theme.scaffoldBackgroundColor, Mechi.canvas);
    await launch(tester);
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    final gallery = find.text('Component gallery');
    await tester.ensureVisible(gallery);
    await tester.tap(gallery);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Disabled'))
          .onPressed,
      isNull,
    );
    expect(find.byType(ProgressRing), findsOneWidget);
  });
}
