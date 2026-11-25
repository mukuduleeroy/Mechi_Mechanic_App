import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label).hitTestable();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> bookRepair(
  WidgetTester tester, {
  Future<void> Function(String)? capture,
}) async {
  await tapLabel(tester, 'Request assistance');
  await tapLabel(tester, 'Find mechanics');
  expect(find.text('Select a problem category'), findsOneWidget);
  expect(find.text('Select a service location'), findsOneWidget);
  await tapLabel(tester, 'Problem category');
  await tapLabel(tester, 'Flat tyre');
  await tapLabel(tester, 'Service location');
  await tapLabel(tester, 'Avondale Shopping Centre');
  await tapLabel(tester, 'Find mechanics');
  await capture?.call('discovery');
  await tapLabel(tester, 'View profile');
  await tapLabel(tester, 'Get quote');
  expect(find.text('Review quote'), findsOneWidget);
  expect(find.text('\$36.00'), findsWidgets);
  await tapLabel(tester, 'Accept quote');
  await tapLabel(tester, 'Simulate departure');
  await tapLabel(tester, 'Simulate arrival');
  await tapLabel(tester, 'Start simulated repair');
  await capture?.call('repair');
  for (var i = 0; i < 3; i++) {
    await tapLabel(tester, 'Advance demo repair');
  }
  await tapLabel(tester, 'Review completion');
  await tapLabel(tester, 'Review job');
  expect(find.text('Tyre puncture kit'), findsWidgets);
  await tapLabel(tester, 'Back to confirmation');
  await tapLabel(tester, 'Confirm completion');
  await tapLabel(tester, 'Continue to payment');
}

Future<void> payAndReview(WidgetTester tester) async {
  await tapLabel(tester, 'Pay now');
  final confirm = find.text('Yes, pay');
  await tester.tap(confirm);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  expect(find.text('Payment successful'), findsOneWidget);
  await tapLabel(tester, 'Print receipt');
  expect(find.text('R-MC-0003'), findsOneWidget);
  expect(find.text('\$36.00'), findsOneWidget);
  await tapLabel(tester, 'Rate mechanic');
  await tester.tap(find.byTooltip('5 stars'));
  await tester.enterText(find.byType(TextField), 'Fast tyre repair.');
  await tester.pumpAndSettle();
  await tapLabel(tester, 'Submit review');
  expect(find.text('Your receipt'), findsOneWidget);
}
