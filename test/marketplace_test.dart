import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/marketplace/driver_marketplace_screens.dart';
import 'package:mechi/features/marketplace/marketplace_data.dart';

class _PollProbe extends StatefulWidget {
  const _PollProbe(this.check);
  final Future<void> Function() check;
  @override
  State<_PollProbe> createState() => _PollProbeState();
}

class _PollProbeState extends State<_PollProbe>
    with WidgetsBindingObserver, ForegroundPoll<_PollProbe> {
  @override
  Future<void> poll() => widget.check();
  @override
  void pollError(Object error) {}
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Market implements MarketplaceRepository {
  String status = 'SEARCHING';
  final calls = <String>[];
  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add(path);
    if (path.endsWith('/quotations')) {
      if (status != 'OFFERS_RECEIVED') return <Json>[] as T;
      return [
            <String, dynamic>{
              'id': 'quote',
              'status': 'PENDING',
              'currency': 'USD',
              'totalMinor': '1100',
              'mechanic': <String, dynamic>{
                'displayName': 'Approved mechanic',
                'verificationStatus': 'APPROVED',
              },
              'items': [
                <String, dynamic>{
                  'description': 'Diagnostic',
                  'amountMinor': '1100',
                },
              ],
            },
          ]
          as T;
    }
    return <String, dynamic>{'status': status} as T;
  }

  @override
  Future<Json> post(String path, {Json? body, String? key}) async {
    calls.add(path);
    status = path.endsWith('/cancel') ? 'CANCELLED' : 'ASSIGNED';
    return {'id': 'job'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('resubmission retains the key only for the same logical payload', () {
    final submission = SubmissionKey();
    final first = submission.forPayload({'id': 'fixture'});
    expect(first, submission.forPayload({'id': 'fixture'}));
    expect(first, isNot(submission.forPayload({'id': 'changed'})));
    final previous = submission.forPayload({'id': 'changed'});
    submission.reset();
    expect(previous, isNot(submission.forPayload({'id': 'changed'})));
  });

  test(
    'prices format integer minor units without floating-point conversion',
    () {
      expect(minorLabel('USD', '1500', 2), 'USD 15.00');
      expect(minorLabel('JPY', '5', 0), 'JPY 5');
      expect(minorLabel('BHD', '5', 3), 'BHD 0.005');
    },
  );

  testWidgets('foreground polling never overlaps and resumes after pause', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      _PollProbe(() async {
        calls++;
        await pending.future;
      }),
    );
    await tester.pump(const Duration(seconds: 12));
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 12));
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'request renders persisted searching, offer detail and terminal outcome',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final market = _Market();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [marketplaceProvider.overrideWithValue(market)],
          child: const MaterialApp(home: DriverRequestProgress(id: 'request')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Searching for mechanics'), findsOneWidget);
      market.status = 'OFFERS_RECEIVED';
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approved mechanic'));
      await tester.pumpAndSettle();
      expect(find.text('Diagnostic'), findsOneWidget);
      await tester.tap(find.text('Accept quotation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(
        market.calls.where((call) => call == 'quotations/quote/accept'),
        hasLength(1),
      );
      expect(find.text('Confirmed assignment'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'driver confirms cancellation and the terminal request stops polling',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final market = _Market();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [marketplaceProvider.overrideWithValue(market)],
          child: const MaterialApp(home: DriverRequestProgress(id: 'request')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Request cancelled'), findsOneWidget);
      expect(
        market.calls.where((call) => call == 'service-requests/request/cancel'),
        hasLength(1),
      );
      final count = market.calls.length;
      await tester.pump(const Duration(seconds: 12));
      expect(market.calls, hasLength(count));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
