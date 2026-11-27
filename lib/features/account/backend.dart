import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiProvider = Provider<MechiApi?>((ref) => null);

class BackendConfiguration {
  const BackendConfiguration({
    required this.environment,
    required this.baseUrl,
    required this.project,
    required this.emulatorHost,
    required this.emulatorPort,
    required this.fixtures,
  });

  static const current = BackendConfiguration(
    environment: String.fromEnvironment(
      'MECHI_ENV',
      defaultValue: 'production',
    ),
    baseUrl: String.fromEnvironment('MECHI_API_URL'),
    project: String.fromEnvironment('MECHI_FIREBASE_PROJECT'),
    emulatorHost: String.fromEnvironment('MECHI_AUTH_EMULATOR_HOST'),
    emulatorPort: int.fromEnvironment(
      'MECHI_AUTH_EMULATOR_PORT',
      defaultValue: 9099,
    ),
    fixtures: bool.fromEnvironment('MECHI_FIXTURES'),
  );

  final String environment, baseUrl, project, emulatorHost;
  final int emulatorPort;
  final bool fixtures;

  Future<MechiApi?> initialize() async {
    final local = environment == 'development' || environment == 'test';
    if (local && kReleaseMode) {
      throw StateError('Release builds require a live Mechi environment');
    }
    if (fixtures) {
      if (!local || kReleaseMode) {
        throw StateError('Fixtures require a local debug configuration');
      }
      return null;
    }
    if (!local && environment != 'staging' && environment != 'production') {
      throw StateError('Invalid Mechi environment');
    }
    final uri = Uri.tryParse(baseUrl);
    const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2', '::1'};
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.replaceFirst(RegExp(r'/$'), '') != '/api/v1' ||
        (uri.scheme != 'https' &&
            !(local &&
                localHosts.contains(uri.host) &&
                uri.scheme == 'http')) ||
        (!local && localHosts.contains(uri.host))) {
      throw StateError('Invalid Mechi API configuration');
    }
    final emulator = emulatorHost.isNotEmpty;
    if (emulator) {
      if (!local ||
          kReleaseMode ||
          !localHosts.contains(emulatorHost) ||
          project !=
              (environment == 'test' ? 'demo-mechi-test' : 'demo-mechi-dev') ||
          emulatorPort != (environment == 'test' ? 9199 : 9099)) {
        throw StateError('Invalid Auth emulator configuration');
      }
    } else if (project.isEmpty ||
        project.startsWith('demo-') ||
        environment == 'test') {
      throw StateError('A valid Firebase project is required');
    }
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    final localAppSuffix = environment == 'test'
        ? '4d6563686954657374'
        : '4d65636869446576';
    final appId = emulator
        ? '1:123456789:$platform:$localAppSuffix'
        : const String.fromEnvironment('MECHI_FIREBASE_APP_ID');
    const apiKey = String.fromEnvironment('MECHI_FIREBASE_API_KEY');
    const sender = String.fromEnvironment('MECHI_FIREBASE_SENDER');
    if (!emulator &&
        (!RegExp(r'^1:[0-9]+:(ios|android|web):[0-9a-f]+$').hasMatch(appId) ||
            !RegExp(r'^A[A-Za-z0-9_-]{38}$').hasMatch(apiKey) ||
            !RegExp(r'^[0-9]+$').hasMatch(sender))) {
      throw StateError('Live Firebase app configuration is required');
    }
    final app = await Firebase.initializeApp(
      options: FirebaseOptions(
        // Firebase Installations validates the key format before Auth can
        // switch to its local emulator. This is a format-only dummy value.
        apiKey: emulator ? 'A${'0' * 38}' : apiKey,
        appId: appId,
        messagingSenderId: emulator ? '123456789' : sender,
        projectId: project,
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    if (emulator) {
      await auth.useAuthEmulator(
        emulatorHost,
        emulatorPort,
        automaticHostMapping: false,
      );
    }
    return MechiApi(auth, baseUrl);
  }
}

typedef Json = Map<String, dynamic>;

class ApiFailure implements Exception {
  const ApiFailure(this.status, this.code, this.requestId, this.message);
  final int? status;
  final String? code, requestId;
  final String message;

  bool get recoverable => status == null || status == 429 || status! >= 500;

  static ApiFailure of(Object error) {
    if (error is DioException) {
      if (error.error is FirebaseAuthException) return of(error.error!);
      final response = error.response;
      final data = response?.data;
      final body = data is Json ? data : const <String, dynamic>{};
      final message = body['message'];
      return ApiFailure(
        response?.statusCode,
        body['code'] as String?,
        response?.headers.value('x-request-id'),
        message is String
            ? message
            : message is List
            ? message.whereType<String>().join(' · ')
            : 'Cannot reach Mechi. Check your connection and retry.',
      );
    }
    if (error is FirebaseAuthException) {
      return ApiFailure(null, error.code, null, switch (error.code) {
        'network-request-failed' =>
          'Cannot reach Firebase. Check your connection and retry.',
        'invalid-verification-code' => 'The verification code is invalid.',
        'weak-password' => 'Use a stronger password.',
        'email-already-in-use' =>
          'Sign in or reset the password for this address.',
        _ => 'Authentication could not be completed.',
      });
    }
    return const ApiFailure(
      null,
      null,
      null,
      'Cannot complete this operation. Please retry.',
    );
  }
}

class MechiApi {
  MechiApi(this.auth, String baseUrl, {HttpClientAdapter? adapter})
    : dio = Dio(
        BaseOptions(
          baseUrl: '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/',
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          followRedirects: false,
        ),
      ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _authenticate, onError: _refresh),
    );
  }
  final FirebaseAuth auth;
  final _restrictions = StreamController<String>.broadcast();
  Stream<String> get restrictedUsers => _restrictions.stream;
  final Dio dio;
  Future<String?>? _refreshing;
  String? _refreshUid;
  static const _replayablePosts = {'auth/bootstrap'};

  Future<void> _authenticate(
    RequestOptions request,
    RequestInterceptorHandler handler,
  ) async {
    final configured = Uri.parse(dio.options.baseUrl);
    if (request.uri.origin != configured.origin) {
      handler.reject(
        DioException(requestOptions: request, type: DioExceptionType.cancel),
      );
      return;
    }
    final user = auth.currentUser;
    final expectedUid = request.extra['uid'];
    if (request.extra.containsKey('uid') && user?.uid != expectedUid) {
      handler.reject(
        DioException(requestOptions: request, type: DioExceptionType.cancel),
      );
      return;
    }
    if (user == null) {
      handler.next(request);
      return;
    }
    try {
      final token = await (request.extra['retried'] == true
          ? user.getIdToken()
          : _refreshUid == user.uid && _refreshing != null
          ? _refreshing!
          : user.getIdToken());
      if (auth.currentUser?.uid != user.uid || token == null) {
        handler.reject(
          DioException(requestOptions: request, type: DioExceptionType.cancel),
        );
        return;
      }
      request.extra['uid'] = user.uid;
      request.headers['Authorization'] = 'Bearer $token';
      handler.next(request);
    } on FirebaseAuthException catch (error) {
      handler.reject(DioException(requestOptions: request, error: error));
    }
  }

  Future<void> _refresh(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final failure = ApiFailure.of(error);
    final user = auth.currentUser;
    if (failure.code == 'ACCOUNT_RESTRICTED' &&
        user != null &&
        request.extra['uid'] == user.uid &&
        !_restrictions.isClosed) {
      _restrictions.add(user.uid);
    }
    if (failure.status == 401 &&
        {'TOKEN_REVOKED', 'FIREBASE_ACCOUNT_DISABLED'}.contains(failure.code) &&
        user != null &&
        request.extra['uid'] == user.uid) {
      await auth.signOut();
    }
    final safe =
        request.method == 'GET' ||
        request.method == 'HEAD' ||
        _replayablePosts.contains(request.path);
    if (!safe ||
        failure.status != 401 ||
        failure.code != 'TOKEN_EXPIRED' ||
        request.extra['retried'] == true ||
        user == null ||
        request.extra['uid'] != user.uid) {
      handler.next(error);
      return;
    }
    try {
      final pending = _refreshUid == user.uid ? _refreshing : null;
      final sent = request.headers['Authorization'];
      final current = pending == null ? await user.getIdToken() : null;
      final flight = pending ?? (_refreshUid == user.uid ? _refreshing : null);
      if (flight != null) {
        await flight;
      } else if (sent == 'Bearer $current') {
        final refresh = user.getIdToken(true);
        _refreshUid = user.uid;
        _refreshing = refresh;
        try {
          await refresh;
        } finally {
          if (identical(_refreshing, refresh)) {
            _refreshing = null;
            _refreshUid = null;
          }
        }
      }
      if (auth.currentUser?.uid != user.uid) {
        handler.next(error);
        return;
      }
      request.extra['retried'] = true;
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on FirebaseAuthException {
      handler.next(error);
    }
  }

  Future<T> request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    String? ownerUid,
    String? idempotencyKey,
  }) async {
    final uid = ownerUid ?? auth.currentUser?.uid;
    final response = await dio.request<T>(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        method: method,
        extra: {'uid': uid},
        headers: idempotencyKey == null
            ? null
            : {'Idempotency-Key': idempotencyKey},
      ),
      cancelToken: cancelToken,
    );
    if (auth.currentUser?.uid != uid) {
      throw DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.cancel,
      );
    }
    return response.data as T;
  }
}

String vehicleRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
