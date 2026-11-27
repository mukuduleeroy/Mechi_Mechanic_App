import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:material_ui/material_ui.dart' show DatePickerDialog;
import 'package:integration_test/integration_test.dart';
import 'package:mechi/app/mechi_app.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/garage/garage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connected_driver_test.dart' as fixture;

const run = String.fromEnvironment('MECHI_MARKETPLACE_FIXTURE_ID');
const base = String.fromEnvironment('MECHI_API_URL');
const verify071 = bool.fromEnvironment('MECHI_VERIFY_PHASE_071');
String email(String role) => 'p06-$role-$run@example.invalid';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Driver and Mechanic confirm the same real assignment', (
    tester,
  ) async {
    expect(fixture.project, 'demo-mechi-test');
    expect(run, matches(RegExp(r'^[a-f0-9]{16}$')));
    final api = (await BackendConfiguration.current.initialize())!;
    // Lose a response after the local server committed the action. The
    // transport failure reaches the real screen's normal recovery path.
    final lose = <String>{};
    final lost = <String>{};
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (result, handler) {
          final request = result.requestOptions;
          final path = request.uri.path;
          if (request.method == 'POST' && lose.remove(path)) {
            lost.add(path);
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            handler.next(result);
          }
        },
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await api.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          preferencesProvider.overrideWithValue(prefs),
        ],
        child: const MechiApp(),
      ),
    );
    Future<void> login(String role, String expected) async {
      await api.auth.signOut();
      await tester.pumpAndSettle();
      await api.auth.signInWithEmailAndPassword(
        email: email(role),
        password: fixture.fictionalPassword,
      );
      await fixture.wait(tester, find.text(expected));
    }

    await login('driver', 'Quick actions');
    await fixture.tap(tester, 'Breakdown');
    await fixture.wait(tester, find.text('Problem category'));
    await fixture.tap(tester, 'Problem category');
    await fixture.tap(tester, 'Battery and starting');
    await fixture.enter(
      tester,
      'Describe the issue',
      'Synthetic battery assistance',
    );
    await fixture.tap(tester, 'Confirm current location');
    await fixture.wait(tester, find.text('Current location confirmed'));
    await binding.takeScreenshot('01-driver-assistance');
    lose.add('/api/v1/service-requests');
    await fixture.tap(tester, 'Find mechanics');
    await fixture.wait(tester, find.textContaining('Cannot reach Mechi'));
    await fixture.tap(tester, 'Find mechanics');
    await fixture.wait(tester, find.text('Assistance request'));
    await fixture.wait(tester, find.text('Searching for mechanics'));
    await binding.takeScreenshot('02-driver-searching');
    final requests = await api.request<List<dynamic>>(
      'GET',
      'service-requests',
    );
    final id = (requests.single as Json)['id'] as String;

    await login('near', 'Mechanic dashboard');
    await fixture.wait(tester, find.text('Battery and starting'));
    await binding.takeScreenshot('08-mechanic-incoming');
    await fixture.tap(tester, 'Battery and starting');
    await fixture.wait(tester, find.text('Request details'));
    await binding.takeScreenshot('09-mechanic-request-details');
    await fixture.tap(tester, 'Prepare quotation');
    await fixture.enter(tester, 'Currency code', 'USD');
    await fixture.enter(tester, 'Description', 'Call-out');
    await fixture.enter(tester, 'Amount in minor units', '1200');
    await binding.takeScreenshot('10-mechanic-quote-form');
    lose.add('/api/v1/service-requests/$id/quotations');
    await fixture.tap(tester, 'Submit quotation');
    await fixture.wait(tester, find.textContaining('Cannot reach Mechi'));
    await fixture.tap(tester, 'Submit quotation');
    await fixture.wait(tester, find.text('Withdraw quotation'));
    await binding.takeScreenshot('11-mechanic-pending-quote');

    // A separate authenticated Mechanic REST client submits a competing offer.
    final credentials =
        await fixture.emulator(
              'POST',
              'identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fixture',
              {
                'email': email('farther'),
                'password': fixture.fictionalPassword,
                'returnSecureToken': true,
              },
            )
            as Json;
    final second = Dio(
      BaseOptions(
        baseUrl: '$base/',
        headers: {'Authorization': "Bearer ${credentials['idToken']}"},
      ),
    );
    addTearDown(second.close);
    final quote = await second.post<Json>(
      'service-requests/$id/quotations',
      options: Options(headers: {'Idempotency-Key': vehicleRequestId()}),
      data: {
        'currency': 'USD',
        'items': [
          {
            'category': 'CALL_OUT',
            'description': 'Call-out',
            'amountMinor': '1500',
          },
        ],
      },
    );
    expect(quote.statusCode, 200);

    await login('driver', 'Quick actions');
    await tester.tap(find.byTooltip('Job history'));
    await fixture.wait(tester, find.text('Offers received'));
    await fixture.tap(tester, 'Offers received');
    await fixture.wait(tester, find.text('Marketplace Second Mechanic'));
    expect(find.text('Marketplace First Mechanic'), findsOneWidget);
    await binding.takeScreenshot('04-driver-offers');
    await fixture.tap(tester, 'Marketplace Second Mechanic');
    await fixture.wait(tester, find.text('Quotation details'));
    await binding.takeScreenshot('05-driver-quotation-details');
    await fixture.tap(tester, 'Accept quotation');
    await binding.takeScreenshot('06-driver-acceptance-confirmation');
    lose.add('/api/v1/quotations/${quote.data!['id']}/accept');
    await fixture.tap(tester, 'Confirm');
    await fixture.wait(tester, find.text('View confirmed assignment'));
    await fixture.tap(tester, 'View confirmed assignment');
    await fixture.wait(tester, find.text('Job reference'));
    await binding.takeScreenshot('07-driver-assignment');
    final jobs = await api.request<List<dynamic>>('GET', 'jobs');
    final job = (jobs.single as Json)['id'];
    final mechanicJobs = await second.get<List<dynamic>>(
      'jobs',
      queryParameters: {'role': 'MECHANIC'},
    );
    expect((mechanicJobs.data!.single as Json)['id'], job);
    expect(lost, hasLength(3));
    expect(lose, isEmpty);
    await login('farther', 'Mechanic dashboard');
    await tester.tap(find.byTooltip('Jobs'));
    await fixture.wait(tester, find.text('Confirmed assignment'));
    await fixture.tap(tester, 'Confirmed assignment');
    await fixture.wait(tester, find.text('Job reference'));
    expect(find.text(job as String), findsOneWidget);
    await binding.takeScreenshot('12-mechanic-assignment');

    if (const bool.fromEnvironment('MECHI_VERIFY_JOB_EXECUTION')) {
      await fixture.tap(tester, 'Start journey');
      await fixture.wait(tester, find.text('Share foreground location'));
      await fixture.tap(tester, 'Share foreground location');
      await fixture.wait(tester, find.text('Current observation'));
      await fixture.tap(tester, 'Request directions');
      await fixture.wait(tester, find.text('Test route'));
      await fixture.wait(
        tester,
        find.text('Local schematic · synthetic test route'),
      );
      expect(find.bySemanticsLabel('Mechanic vehicle'), findsOneWidget);
      await binding.takeScreenshot('job-071-tracking-map');
      if (const bool.fromEnvironment('MECHI_CONCURRENT_DRIVER')) {
        final reply = find.text(
          'Concurrent Driver received the tracked position',
        );
        for (
          var attempt = 0;
          attempt < 90 && reply.evaluate().isEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
        }
        expect(reply, findsOneWidget);
      }
      if (verify071) {
        await fixture.tap(tester, 'Call service participant');
        await fixture.wait(
          tester,
          find.text('A verified phone number is unavailable.'),
        );

        await login('driver', 'Quick actions');
        await tester.tap(find.byTooltip('Job history'));
        await fixture.tap(tester, 'En route');
        await fixture.wait(tester, find.text('Local schematic'));
        Future<void> postFix(double latitude, int heading) async {
          await second.put<Json>(
            'jobs/$job/location',
            data: {
              'latitude': latitude,
              'longitude': 51,
              'heading': heading,
              'accuracyMetres': 5,
              'observedAt': DateTime.now().toUtc().toIso8601String(),
            },
          );
          await fixture.wait(tester, find.textContaining('$latitude, 51'));
        }

        await postFix(10.002, 10);
        await postFix(10.004, 30);
        const stale = 'Location unavailable or stale';
        for (var i = 0; i < 24 && find.text(stale).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text(stale), findsOneWidget);
        await tester.ensureVisible(find.text(stale));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('job-071-tracking-stale');
        await postFix(10.006, 35);

        await login('farther', 'Mechanic dashboard');
        await tester.tap(find.byTooltip('Jobs'));
        await fixture.tap(tester, 'En route');
        await fixture.wait(tester, find.text('Confirm arrival'));
      }
      await fixture.tap(tester, 'Confirm arrival');
      await fixture.enter(
        tester,
        'Reason',
        'Confirmed near the synthetic destination',
      );
      await binding.takeScreenshot('job-02-arrival');
      await fixture.tap(tester, 'Submit');
      await fixture.wait(tester, find.text('Start diagnosis'));
      await fixture.tap(tester, 'Start diagnosis');
      await fixture.wait(tester, find.text('Record diagnosis'));
      await fixture.tap(tester, 'Record diagnosis');
      await fixture.enter(tester, 'Findings', 'Connector needed adjustment');
      await fixture.enter(tester, 'Recommended work', 'Secure connector');
      await binding.takeScreenshot('job-03-diagnosis');
      await fixture.tap(tester, 'Submit');
      await fixture.tap(tester, 'Request additional charges');
      await fixture.enter(tester, 'Reason', 'Additional connector');
      await fixture.enter(tester, 'Additional amount in minor units', '250');
      await binding.takeScreenshot('job-04-additional-price');
      await fixture.tap(tester, 'Submit');
      await fixture.wait(tester, find.text('Awaiting approval'));

      final driverSession =
          await fixture.emulator(
                'POST',
                'identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fixture',
                {
                  'email': email('driver'),
                  'password': fixture.fictionalPassword,
                  'returnSecureToken': true,
                },
              )
              as Json;
      final driver = Dio(
        BaseOptions(
          baseUrl: '$base/',
          headers: {'Authorization': "Bearer ${driverSession['idToken']}"},
        ),
      );
      addTearDown(driver.close);
      final current = (await driver.get<Json>('jobs/$job')).data!;
      final revisions = (await driver.get<List<dynamic>>(
        'jobs/$job/price-revisions',
      )).data!;
      final revision = revisions.single as Json;
      final decision = verify071 ? 'decline' : 'approve';
      await driver.post<Json>(
        "jobs/$job/price-revisions/${revision['id']}/$decision",
        options: Options(headers: {'Idempotency-Key': vehicleRequestId()}),
        data: {'version': current['version']},
      );
      await fixture.wait(tester, find.text('Start service'));
      await fixture.tap(tester, 'Start service');
      await fixture.wait(tester, find.text('Submit completion'));
      await binding.takeScreenshot('job-05-service-progress');
      await driver.post<Json>(
        'jobs/$job/messages',
        options: Options(headers: {'Idempotency-Key': vehicleRequestId()}),
        data: {'text': 'Thank you for the update.'},
      );
      await fixture.wait(tester, find.text('Thank you for the update.'));
      await tester.ensureVisible(find.text('Thank you for the update.'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('job-06-message');
      await fixture.tap(tester, 'Submit completion');
      await fixture.enter(
        tester,
        'Work performed',
        'Secured and checked the connector',
      );
      await fixture.tap(tester, 'Submit');
      await fixture.wait(tester, find.text('Completion submitted'));

      await login('driver', 'Quick actions');
      await tester.tap(find.byTooltip('Job history'));
      await fixture.wait(tester, find.text('Completion submitted'));
      await fixture.tap(tester, 'Completion submitted');
      await fixture.wait(tester, find.text('Confirm completion'));
      await tester.ensureVisible(find.text('Confirm completion'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('job-07-completion-review');
      await fixture.tap(tester, 'Confirm completion');
      await fixture.wait(tester, find.text('Service completed'));
      await binding.takeScreenshot('job-08-completed');
      final assigned = (await second.get<Json>(
        'jobs/$job',
        queryParameters: {'role': 'MECHANIC'},
      )).data!;
      expect(assigned['status'], 'COMPLETED');
      if (verify071) {
        final events = (await driver.get<List<dynamic>>(
          'jobs/$job/events',
        )).data!.cast<Json>();
        expect(
          events.any((event) => event['kind'] == 'PRICE_DECLINED'),
          isTrue,
        );
        final completion = events.singleWhere(
          (event) => event['kind'] == 'COMPLETION',
        );
        expect(completion['payload']['approvedPrice']['totalMinor'], '1500');

        final today = DateTime.now().toUtc();
        final day = DateTime.utc(
          today.year,
          today.month,
          today.day,
          today.hour,
          today.minute + 4,
        );
        await login('farther', 'Mechanic dashboard');
        await tester.tap(find.byTooltip('Jobs'));
        await fixture.tap(tester, 'Add working window');
        await fixture.enter(
          tester,
          'Start (ISO 8601 with time zone)',
          day.toIso8601String(),
        );
        await fixture.enter(
          tester,
          'End (ISO 8601 with time zone)',
          day.add(const Duration(hours: 4)).toIso8601String(),
        );
        await fixture.enter(tester, 'Region time zone', 'UTC');
        await fixture.enter(tester, 'Travel buffer in minutes', '5');
        await fixture.tap(tester, 'Save working window');
        await fixture.wait(tester, find.text('Remove working window'));
        await tester.ensureVisible(find.text('Remove working window'));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('job-071-mechanic-schedule');

        await login('driver', 'Quick actions');
        await fixture.tap(tester, 'Breakdown');
        await fixture.tap(tester, 'Home service');
        await fixture.enter(
          tester,
          'Service address',
          'Synthetic service destination',
        );
        await fixture.tap(tester, 'Appointment date');
        final datePicker = find.byType(DatePickerDialog);
        await fixture.wait(tester, datePicker);
        final todayOnDevice = DateTime.now();
        if (day.day != todayOnDevice.day || day.month != todayOnDevice.month) {
          final calendar = tester.widget<DatePickerDialog>(datePicker);
          final target = find.descendant(
            of: datePicker,
            matching: find.text('${day.day}'),
          );
          if (calendar.initialDate?.month != day.month) {
            await tester.tap(find.byTooltip('Next month'));
            await tester.pumpAndSettle();
          }
          await tester.tap(target.last);
        }
        await fixture.tap(tester, 'OK');
        await fixture.enter(tester, 'Service duration in minutes', '30');
        await fixture.tap(tester, 'Problem category');
        await fixture.tap(tester, 'Battery and starting');
        await fixture.enter(
          tester,
          'Describe the issue',
          'Synthetic scheduled service',
        );
        await fixture.tap(tester, 'Confirm current location');
        await fixture.wait(tester, find.text('Current location confirmed'));
        await fixture.tap(tester, 'Check appointment availability');
        await fixture.wait(tester, find.text('Appointment window'));
        await fixture.tap(tester, 'Appointment window');
        String clockText(DateTime value) =>
            value.toIso8601String().replaceFirst('T', ' ').substring(0, 16);
        await fixture.tap(
          tester,
          "${clockText(day)} to ${clockText(day.add(const Duration(minutes: 30)))} UTC",
        );
        await binding.takeScreenshot('job-071-scheduled-request');
        await fixture.tap(tester, 'Find mechanics');
        await fixture.wait(tester, find.text('Searching for mechanics'));
        final home = (await driver.get<List<dynamic>>(
          'service-requests',
        )).data!.cast<Json>().singleWhere((request) => request['id'] != id);

        await login('farther', 'Mechanic dashboard');
        await fixture.tap(tester, 'Battery and starting');
        await fixture.tap(tester, 'Prepare quotation');
        await fixture.enter(tester, 'Currency code', 'USD');
        await fixture.enter(tester, 'Description', 'Home service');
        await fixture.enter(tester, 'Amount in minor units', '1500');
        await fixture.tap(tester, 'Submit quotation');
        await fixture.wait(tester, find.text('Withdraw quotation'));

        await login('driver', 'Quick actions');
        await tester.tap(find.byTooltip('Job history'));
        await fixture.tap(tester, 'Offers received');
        await fixture.tap(tester, 'Marketplace Second Mechanic');
        await fixture.tap(tester, 'Accept quotation');
        await fixture.tap(tester, 'Confirm');
        await fixture.wait(tester, find.text('View appointments'));
        await binding.takeScreenshot('job-071-appointment');
        final booked = (await driver.get<List<dynamic>>(
          'appointments',
        )).data!.cast<Json>().single;
        expect(booked['status'], 'BOOKED');
        expect(
          (await driver.get<Json>(
            "service-requests/${home['id']}",
          )).data!['appointment']['id'],
          booked['id'],
        );

        await login('farther', 'Mechanic dashboard');
        await tester.tap(find.byTooltip('Jobs'));
        await fixture.wait(tester, find.text('Activate appointment'));
        final untilStart = day.difference(DateTime.now().toUtc());
        if (untilStart > Duration.zero) {
          await Future<void>.delayed(untilStart + const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 16));
          await tester.pumpAndSettle();
        }
        await fixture.tap(tester, 'Activate appointment');
        await fixture.wait(tester, find.text('Start journey'));
        await fixture.tap(tester, 'Start journey');
        await fixture.wait(tester, find.text('Confirm arrival'));
        await fixture.tap(tester, 'Confirm arrival');
        await fixture.enter(tester, 'Reason', 'Arrived at scheduled location');
        await fixture.tap(tester, 'Submit');
        await fixture.wait(tester, find.text('Report unsuccessful service'));
        await fixture.tap(tester, 'Report unsuccessful service');
        await fixture.tap(tester, 'Service outcome');
        await fixture.tap(tester, 'Replacement parts unavailable');
        await fixture.enter(tester, 'Reason', 'Requested part was unavailable');
        await fixture.tap(tester, 'Submit');
        await fixture.wait(tester, find.text('Service unsuccessful'));
        await binding.takeScreenshot('job-071-unsuccessful-service');

        await login('driver', 'Quick actions');
        await tester.tap(find.byTooltip('Notifications'));
        await fixture.wait(tester, find.text('Job updated'));
        await tester.ensureVisible(find.text('Job updated').first);
        await binding.takeScreenshot('job-071-notifications');
        final notices = (await driver.get<List<dynamic>>(
          'notifications',
        )).data!.cast<Json>();
        final latest = notices.firstWhere(
          (notice) => notice['title'] == 'Job updated',
        );
        await tester.tap(find.text('Job updated').first);
        await fixture.wait(tester, find.text('Service unsuccessful'));
        final afterRead = (await driver.get<List<dynamic>>(
          'notifications',
        )).data!.cast<Json>();
        expect(
          afterRead.firstWhere(
            (notice) => notice['id'] == latest['id'],
          )['readAt'],
          isNotNull,
        );
        await fixture.tap(tester, 'Raise a dispute');
        await fixture.enter(
          tester,
          'Reason',
          'Request review of the unsuccessful service',
        );
        await fixture.tap(tester, 'Submit');
        await fixture.wait(tester, find.text('Awaiting operational review'));
        await tester.ensureVisible(find.text('Awaiting operational review'));
        await binding.takeScreenshot('job-071-dispute');
      }
      expect(
        (await second.get<Json>('mechanics/me/availability')).data!['status'],
        'OFFLINE',
      );
      await api.auth.signOut();
      return;
    }

    await login('driver', 'Quick actions');
    final ownVehicles = await api.request<List<dynamic>>('GET', 'vehicles');
    final categories = await api.request<List<dynamic>>(
      'GET',
      'service-categories',
    );
    final category = categories.cast<Json>().firstWhere(
      (item) => item['code'] == 'BATTERY_STARTING',
    );
    final empty = await api.request<Json>(
      'POST',
      'service-requests',
      idempotencyKey: vehicleRequestId(),
      body: {
        'vehicleId': (ownVehicles.single as Json)['id'],
        'categoryId': category['id'],
        'serviceType': 'ROADSIDE',
        'issue': 'Synthetic out-of-range test',
        'longitude': 21.7,
        'latitude': 10.7,
        'locationSource': 'MANUAL',
        'confirmed': true,
      },
    );
    await tester.tap(find.byTooltip('Job history'));
    await fixture.wait(tester, find.text('Searching for mechanics'));
    await fixture.tap(tester, 'Searching for mechanics');
    final outcome = find.text('No mechanic available');
    for (var retry = 0; retry < 55 && outcome.evaluate().isEmpty; retry++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(outcome, findsOneWidget);
    final terminal = await api.request<Json>(
      'GET',
      "service-requests/${empty['id']}",
    );
    expect(terminal['status'], 'NO_MECHANIC_AVAILABLE');
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await binding.takeScreenshot('03-driver-no-mechanic');
    await api.auth.signOut();
  });
}
