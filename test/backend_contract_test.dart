import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechi/features/account/backend.dart';
import 'package:mechi/features/account/driver_data.dart';
import 'package:mechi/features/account/session.dart';

class FakeIdentity implements User {
  FakeIdentity(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.invalid';
  @override
  bool get emailVerified => true;
  @override
  String? get phoneNumber => null;
  int forced = 0;
  String token = 'initial-token';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) {
      forced++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      token = 'refreshed-token';
    }
    return token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements FirebaseAuth {
  FakeAuth(this.currentUser);
  @override
  User? currentUser;
  final changes = StreamController<User?>.broadcast();

  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* changes.stream;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef Fetch = FutureOr<ResponseBody> Function(RequestOptions);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final Fetch respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody response(int status, Object? value) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const account = {
  'id': 'fixture-driver',
  'email': 'driver@example.invalid',
  'phone': null,
  'status': 'ACTIVE',
  'grantedRoles': ['DRIVER'],
  'roleContexts': [role],
  'driverProfileComplete': true,
  'mechanicProfileComplete': null,
  'mechanicVerificationStatus': null,
};
const role = {
  'role': 'DRIVER',
  'profileComplete': true,
  'canContinueOnboarding': true,
  'canPerformMechanicWork': false,
  'verificationStatus': null,
};

void main() {
  test(
    'requests attach Firebase tokens and coordinate one safe forced refresh',
    () async {
      final user = FakeIdentity('driver');
      final auth = FakeAuth(user);
      var attempts = 0;
      final api = MechiApi(
        auth,
        'https://api.example.invalid/api/v1',
        adapter: FakeAdapter((options) {
          attempts++;
          expect(options.uri.path, '/api/v1/vehicles');
          if (options.headers['Authorization'] == 'Bearer initial-token') {
            return response(401, {'code': 'TOKEN_EXPIRED'});
          }
          expect(options.headers['Authorization'], 'Bearer refreshed-token');
          return response(200, <Object>[]);
        }),
      );
      final rows = await Future.wait(
        List.generate(3, (_) => api.request<List<dynamic>>('GET', 'vehicles')),
      );
      expect(rows, [[], [], []]);
      expect(user.forced, 1);
      expect(attempts, 6);
      await auth.changes.close();
    },
  );

  test('unsafe writes and permission errors never force refresh', () async {
    final user = FakeIdentity('driver');
    final auth = FakeAuth(user);
    var attempts = 0;
    final api = MechiApi(
      auth,
      'https://api.example.invalid/api/v1',
      adapter: FakeAdapter((options) {
        attempts++;
        return options.method == 'PATCH'
            ? response(401, {'code': 'TOKEN_EXPIRED'})
            : response(403, {'code': 'ROLE_REQUIRED'});
      }),
    );
    await expectLater(
      api.request<Json>('PATCH', 'vehicles/item', body: {'colour': 'blue'}),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      api.request<Json>('GET', 'drivers/me'),
      throwsA(isA<DioException>()),
    );
    expect(user.forced, 0);
    expect(attempts, 2);
    await auth.changes.close();
  });

  test('private repositories cannot write after an account switch', () async {
    final auth = FakeAuth(FakeIdentity('first'));
    var calls = 0;
    final api = MechiApi(
      auth,
      'https://api.example.invalid/api/v1',
      adapter: FakeAdapter((_) {
        calls++;
        return response(200, {});
      }),
    );
    final first = DriverRepository(api);
    auth.currentUser = FakeIdentity('second');
    expect(() => first.updateProfile('Wrong', 'Owner', null), throwsStateError);
    expect(calls, 0);
    await auth.changes.close();
  });

  test(
    'session restoration uses Mechi account and role selection, then clears on logout',
    () async {
      final auth = FakeAuth(FakeIdentity('driver'));
      final requests = <String>[];
      final api = MechiApi(
        auth,
        'https://api.example.invalid/api/v1',
        adapter: FakeAdapter((options) {
          requests.add(options.path);
          if (options.path == 'auth/me') return response(200, account);
          if (options.path == 'auth/select-role') return response(200, role);
          return response(500, {});
        }),
      );
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(api)],
      );
      final ready = Completer<Session>();
      container.listen(sessionProvider, (_, state) {
        if (state.stage == SessionStage.ready && !ready.isCompleted) {
          ready.complete(state);
        }
      });
      expect(
        (await ready.future.timeout(const Duration(seconds: 2))).account?.id,
        'fixture-driver',
      );
      expect(requests, ['auth/me', 'auth/select-role']);
      await container.read(sessionProvider.notifier).signOut();
      await Future<void>.delayed(Duration.zero);
      final cleared = container.read(sessionProvider);
      expect(cleared.stage, SessionStage.signedOut);
      expect(cleared.account, isNull);
      container.dispose();
      await auth.changes.close();
    },
  );

  test(
    'production rejects insecure API and Auth emulator before SDK initialization',
    () async {
      const config = BackendConfiguration(
        environment: 'production',
        baseUrl: 'http://127.0.0.1:3000/api/v1',
        project: 'demo-mechi-dev',
        emulatorHost: '127.0.0.1',
        emulatorPort: 9099,
        fixtures: false,
      );
      await expectLater(config.initialize(), throwsStateError);
      const secureUrl = BackendConfiguration(
        environment: 'production',
        baseUrl: 'https://api.example.invalid/api/v1',
        project: 'demo-mechi-dev',
        emulatorHost: '127.0.0.1',
        emulatorPort: 9099,
        fixtures: false,
      );
      await expectLater(secureUrl.initialize(), throwsStateError);
    },
  );
  test(
    'offline catalogue falls back to confirmed data only for its owner',
    () async {
      final auth = FakeAuth(FakeIdentity('first'));
      var offline = false;
      final api = MechiApi(
        auth,
        'https://api.example.invalid/api/v1',
        adapter: FakeAdapter((options) {
          if (offline) {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'simulated loss of connectivity',
            );
          }
          return response(200, {
            'items': [
              {'id': 'fixture', 'name': 'Toyota'},
            ],
            'nextOffset': null,
          });
        }),
      );
      final repository = DriverRepository(api);
      const path = 'vehicle-catalogue/manufacturers';
      final online = await repository.cataloguePage(path);
      expect(online.cached, false);
      offline = true;
      final cached = await repository.cataloguePage(path);
      expect(cached.cached, true);
      expect(cached.items.single['name'], 'Toyota');
      await expectLater(
        repository.updateProfile('New', 'Name', null),
        throwsA(isA<DioException>()),
      );
      auth.currentUser = FakeIdentity('second');
      await expectLater(repository.cataloguePage(path), throwsStateError);
      await auth.changes.close();
    },
  );
}
