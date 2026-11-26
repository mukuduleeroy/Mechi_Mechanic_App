import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/core/design_system/design_system.dart';
import 'package:mechi/features/assistance/demo_map.dart';
import 'package:mechi/features/assistance/domain.dart';
import 'package:mechi/features/assistance/mechanic_reviews.dart';
import 'package:mechi/features/assistance/payment_components.dart';

Future<void> preview(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(theme: Mechi.theme, home: child));

Finder iconButton(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == tooltip,
);

void main() {
  testWidgets(
    'dashboard navigation keeps compact width and dispatches a typed destination',
    (tester) async {
      DashboardDestination? selected;

      await preview(
        tester,
        Scaffold(
          body: Center(
            child: DashboardNavigation(
              availableWidth: 240,
              onDestination: (destination) => selected = destination,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DashboardNavigation)).width, 240);
      expect(
        tester.getSemantics(iconButton('Home')).getSemanticsData().tooltip,
        'Home',
      );
      await tester.tap(find.byTooltip('Home'));
      expect(selected, isNull);
      await tester.tap(find.byTooltip('Vehicles'));
      expect(selected, DashboardDestination.vehicles);
    },
  );

  testWidgets('disabled map, rating and payment controls retain their state', (
    tester,
  ) async {
    int? rating;
    var recenters = 0;
    await preview(
      tester,
      Scaffold(
        body: ListView(
          children: [
            MapControls(onRecenter: () => recenters++),
            RatingPicker(rating: 2, onChanged: (value) => rating = value),
            const PaymentMethodPicker(
              method: PaymentMethod.cash,
              onChanged: null,
            ),
          ],
        ),
      ),
    );

    final zoom = tester.widget<IconButton>(iconButton('Zoom out'));
    expect(zoom.onPressed, isNull);
    await tester.tap(find.byTooltip('Recenter map'));
    expect(recenters, 1);
    await tester.tap(find.byTooltip('4 stars'));
    expect(rating, 4);
    expect(
      tester.widgetList<RadioListTile<PaymentMethod>>(
        find.byType(RadioListTile<PaymentMethod>),
      ),
      everyElement(
        isA<RadioListTile<PaymentMethod>>().having(
          (tile) => tile.enabled,
          'enabled',
          false,
        ),
      ),
    );
  });

  testWidgets('page footer stays reachable with a compact keyboard viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var completed = false;
    await preview(
      tester,
      Screen(
        title: 'Assistance',
        footer: ActionButton('Continue', () => completed = true),
        children: [
          MechiFormField.description(controller: controller, label: 'Issue'),
        ],
      ),
    );
    await tester.showKeyboard(find.byType(TextFormField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextFormField), 'Flat tyre');
    await tester.pumpAndSettle();
    final footer = find.text('Continue');
    expect(tester.getBottomRight(footer).dy, lessThan(390));
    await tester.tap(footer);
    expect(completed, isTrue);
    expect(controller.text, 'Flat tyre');
  });
  testWidgets(
    'payment dialog waits for its result and dispatches the receipt action',
    (tester) async {
      final result = Completer<bool?>();
      var requests = 0;
      var receipts = 0;
      await preview(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ActionButton('Pay', () {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PaymentResultDialog(
                  process: () {
                    requests++;
                    return result.future;
                  },
                  amount: '\$36.00',
                  method: PaymentMethod.card,
                  onReceipt: () => receipts++,
                ),
              );
            }),
          ),
        ),
      );
      await tester.tap(find.text('Pay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Print receipt'), findsNothing);
      result.complete(true);
      await tester.pumpAndSettle();
      expect(requests, 1);
      await tester.tap(find.text('Print receipt'));
      await tester.pumpAndSettle();
      expect(receipts, 1);
    },
  );
}
