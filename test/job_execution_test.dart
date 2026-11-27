import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/job_execution/appointment_panel.dart';
import 'package:mechi/features/job_execution/execution_panel.dart';
import 'package:mechi/features/job_execution/job_notifications.dart';
import 'package:mechi/features/job_execution/native_job_actions.dart';
import 'package:mechi/features/job_execution/tracking_map.dart';
import 'package:mechi/features/assistance/demo_map.dart';
import 'package:mechi/features/marketplace/marketplace_data.dart';

class _JobStore implements MarketplaceRepository {
  final calls = <({String path, Json? body, String? key})>[];

  @override
  Future<Json> post(String path, {Json? body, String? key}) async {
    calls.add((path: path, body: body, key: key));
    if (path.endsWith('/cancel') && calls.length == 1) {
      throw const ApiFailure(null, null, null, 'Connection lost');
    }
    return {'status': 'CANCELLED', 'version': 2};
  }

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (path == 'notifications') {
      return <Json>[
            {
              'id': 'notice',
              'title': 'Assigned job cancelled',
              'readAt': null,
              'event': {'jobId': 'synthetic-job'},
            },
          ]
          as T;
    }
    if (path.endsWith('/tracking')) {
      return {'position': null, 'stale': true} as T;
    }
    if (path.endsWith('/timeline')) {
      return <Json>[
            {'status': 'CONFIRMED', 'createdAt': '2026-11-27T08:00:00Z'},
            {'status': 'EN_ROUTE', 'createdAt': '2026-11-27T08:01:00Z'},
          ]
          as T;
    }
    return <Json>[] as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('coordinates and route geometry reject malformed input', () {
    expect(
      jobCoordinate({'latitude': -17.8, 'longitude': 31.05}),
      const Offset(31.05, -17.8),
    );
    expect(jobCoordinate({'latitude': -91, 'longitude': 31.05}), isNull);
    expect(decodeJobRoute('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), [
      const Offset(-120.2, 38.5),
      const Offset(-120.95, 40.7),
      const Offset(-126.453, 43.252),
    ]);
    expect(decodeJobRoute('_'), isEmpty);
  });

  testWidgets('live observations update marker position and heading', (
    tester,
  ) async {
    Future<void> map(double lng, int heading) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobTrackingMap(
              destination: const Offset(31.0, -17.8),
              fix: {'latitude': -17.8, 'longitude': lng, 'heading': heading},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await map(30.99, 180);
    final before = tester.widget<DemoMap>(find.byType(DemoMap));
    await map(31.01, 90);
    final after = tester.widget<DemoMap>(find.byType(DemoMap));
    expect(
      before.trackingFix!.position.dx,
      lessThan(before.jobOverlay!.destination.dx),
    );
    expect(
      after.trackingFix!.position.dx,
      greaterThan(after.jobOverlay!.destination.dx),
    );
    expect(after.trackingFix!.heading, 90);
    expect(after.jobOverlay!.route, isEmpty);
  });

  testWidgets(
    'native actions report unavailable handlers and only pass valid phone numbers',
    (tester) async {
      const channel = MethodChannel('mechi/job_actions');
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'dial';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(await openJobDialler('invalid'), isFalse);
      expect(await openJobDialler('+263771234567'), isTrue);
      expect(
        await openJobDirections(Uri.https('www.google.com', '/maps/dir/')),
        isFalse,
      );
      expect(calls.map((call) => call.method), ['dial', 'directions']);
      expect(calls.first.arguments, '+263771234567');
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    required bool mechanic,
    _JobStore? store,
    String status = 'EN_ROUTE',
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceProvider.overrideWithValue(store ?? _JobStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: JobExecutionPanel(
                id: 'synthetic-job',
                mechanic: mechanic,
                job: {'status': status, 'version': 1},
                refreshJob: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'driver sees persisted timeline and stale tracking without mechanic actions',
    (tester) async {
      await mount(tester, mechanic: false);
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Location unavailable or stale'), findsOneWidget);
      expect(find.text('Confirm arrival'), findsNothing);
      expect(find.text('Share foreground location'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'assigned cancellation confirms the reason and retries with the same key',
    (tester) async {
      final store = _JobStore();
      await mount(tester, mechanic: false, store: store);
      Future<void> tap(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tap('Cancel assigned job');
      final reason = find.widgetWithText(TextField, 'Reason');
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Unable to continue');
      await tap('Submit');
      expect(find.text('Cancel assigned job?'), findsOneWidget);
      expect(store.calls, isEmpty);
      await tap('Confirm');
      expect(store.calls.single.body, {
        'version': 1,
        'reason': 'Unable to continue',
      });
      await tap('Submit');
      await tap('Confirm');
      expect(store.calls, hasLength(2));
      expect(store.calls.last.key, isNotNull);
      expect(store.calls.last.key, store.calls.first.key);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mechanic submits structured unsuccessful-service outcome', (
    tester,
  ) async {
    final store = _JobStore();
    await mount(tester, mechanic: true, status: 'ARRIVED', store: store);
    Future<void> tap(String name) async {
      final target = find.text(name);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap('Report unsuccessful service');
    await tap('Service outcome');
    await tap('Replacement parts unavailable');
    final field = find.widgetWithText(TextField, 'Reason');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Part unavailable');
    await tap('Submit');
    expect(store.calls.single.path, 'jobs/synthetic-job/report-unsuccessful');
    expect(store.calls.single.body, {
      'version': 1,
      'reason': 'Part unavailable',
      'outcome': 'PARTS_UNAVAILABLE',
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'opening an unread notification marks it read and opens its job',
    (tester) async {
      final store = _JobStore();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const JobNotifications(),
                ),
                child: const Text('Open notices'),
              ),
            ),
          ),
          GoRoute(
            path: '/assignments/:id',
            builder: (_, state) =>
                Scaffold(body: Text("Job ${state.pathParameters['id']}")),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [marketplaceProvider.overrideWithValue(store)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Open notices'));
      await tester.pumpAndSettle();
      expect(find.text('Unread'), findsOneWidget);
      await tester.tap(find.text('Assigned job cancelled'));
      await tester.pumpAndSettle();
      expect(store.calls.single.path, 'notifications/notice/read');
      expect(find.text('Job synthetic-job'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('working windows use themed date and time pickers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [marketplaceProvider.overrideWithValue(_JobStore())],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppointmentPanel(mechanic: true, openJob: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add working window'));
    await tester.pumpAndSettle();
    final choose = find.text('Choose working start');
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Start (ISO 8601 with time zone)'),
          )
          .controller!
          .text,
      endsWith('Z'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('assigned mechanic sees foreground and arrival controls', (
    tester,
  ) async {
    await mount(tester, mechanic: true);
    expect(find.text('Confirm arrival'), findsOneWidget);
    expect(find.text('Share foreground location'), findsOneWidget);
    expect(find.text('Confirm completion'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
