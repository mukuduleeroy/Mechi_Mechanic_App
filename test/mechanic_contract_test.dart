import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/core/design_system/design_system.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/mechanic/mechanic_data.dart';

import 'backend_contract_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native GPS permission denial never requests a position', () async {
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    final receiver =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final methods = <String>[];
    receiver.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return switch (call.method) {
        'isLocationServiceEnabled' => true,
        'checkPermission' || 'requestPermission' => 0,
        _ => throw StateError('Location requested without permission'),
      };
    });
    addTearDown(() => receiver.setMockMethodCallHandler(channel, null));
    await expectLater(
      NativeMechanicDevice().position(requestPermission: true),
      throwsA(isA<MechanicFailure>()),
    );
    expect(methods, [
      'isLocationServiceEnabled',
      'checkPermission',
      'requestPermission',
    ]);
  });

  test(
    'failed evidence upload may retry with the same UUID and cannot cross accounts',
    () async {
      final auth = support.FakeAuth(support.FakeIdentity('first'));
      final submissions = <Json>[];
      final api = MechiApi(
        auth,
        'https://api.example.invalid/api/v1',
        adapter: support.FakeAdapter((request) {
          expect(request.uri.path, '/api/v1/mechanics/me/documents');
          submissions.add(request.data as Json);
          if (submissions.length == 1) {
            throw DioException.connectionError(
              requestOptions: request,
              reason: 'simulated disconnect',
            );
          }
          return support.response(200, {'id': submissions.last['id']});
        }),
      );
      final repository = MechanicRepository(api);
      final document = PrivateUpload(
        'fixture.pdf',
        'application/pdf',
        Uint8List.fromList([1, 2, 3]),
      );
      await expectLater(
        repository.upload(document, 'QUALIFICATION', 'owned-qualification'),
        throwsA(isA<DioException>()),
      );
      await repository.upload(document, 'QUALIFICATION', 'owned-qualification');
      expect(submissions, hasLength(2));
      expect(submissions.first, submissions.last);
      expect(submissions.last['qualificationId'], 'owned-qualification');
      auth.currentUser = support.FakeIdentity('second');
      expect(
        () =>
            repository.upload(document, 'QUALIFICATION', 'owned-qualification'),
        throwsStateError,
      );
      await auth.changes.close();
    },
  );

  testWidgets('mechanic destinations reuse the approved compact navigation', (
    tester,
  ) async {
    String? action;
    await tester.pumpWidget(
      MaterialApp(
        theme: Mechi.theme,
        home: Center(
          child: DashboardNavigation.mechanic(
            availableWidth: 240,
            selectedIndex: 2,
            onHome: () => action = 'home',
            onJobs: () => action = 'jobs',
            onEarnings: () => action = 'earnings',
            onProfile: () => action = 'profile',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DashboardNavigation)).width, 240);
    final earnings = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Earnings',
    );
    expect(tester.widget<IconButton>(earnings).isSelected, isTrue);
    await tester.tap(find.byTooltip('Jobs'));
    expect(action, 'jobs');
  });
}
