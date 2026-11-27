import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';

const _installationKey = 'mechi.push.installation';

final pushRegistrationProvider = Provider((ref) {
  final service = PushRegistration(ref.watch(apiProvider));
  ref.onDispose(service.dispose);
  return service;
});

class PushRegistration {
  PushRegistration(this.api);
  final MechiApi? api;
  StreamSubscription<String>? tokens;
  Future<void>? pending;
  bool stopping = false;

  bool get enabled =>
      const bool.fromEnvironment('MECHI_ENABLE_PUSH') &&
      BackendConfiguration.current.emulatorHost.isEmpty &&
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform) &&
      api != null;

  Future<void> register() async {
    final backend = api;
    final owner = backend?.auth.currentUser?.uid;
    if (!enabled || backend == null || owner == null || stopping) return;
    final messenger = FirebaseMessaging.instance;
    final permission = await messenger.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied ||
        permission.authorizationStatus == AuthorizationStatus.notDetermined) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await messenger.getAPNSToken() == null) {
      throw StateError('APNs registration is unavailable');
    }
    final preferences = await SharedPreferences.getInstance();
    final installation =
        preferences.getString(_installationKey) ?? vehicleRequestId();
    await preferences.setString(_installationKey, installation);
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'IOS'
        : 'ANDROID';
    Future<void> send(String token) async {
      if (stopping || backend.auth.currentUser?.uid != owner) return;
      final previous = pending;
      final request = () async {
        try {
          await previous;
        } catch (_) {
          // A newer token can still be registered after a failed refresh.
        }
        if (stopping || backend.auth.currentUser?.uid != owner) return;
        await backend.request<Json>(
          'POST',
          'users/me/device-tokens',
          ownerUid: owner,
          body: {
            'installationId': installation,
            'token': token,
            'platform': platform,
          },
        );
      }();
      pending = request;
      try {
        await request;
      } finally {
        if (identical(pending, request)) pending = null;
      }
    }

    // The backend sends through the Admin SDK registration-token contract.
    // ignore: deprecated_member_use
    final token = await messenger.getToken();
    if (token == null) throw StateError('Device registration is unavailable');
    await send(token);
    if (stopping || backend.auth.currentUser?.uid != owner) return;
    await messenger.setForegroundNotificationPresentationOptions(
      alert: true,
      sound: false,
      badge: false,
    );
    await tokens?.cancel();
    if (stopping || backend.auth.currentUser?.uid != owner) return;
    // The backend sends through the Admin SDK registration-token contract.
    // ignore: deprecated_member_use
    tokens = messenger.onTokenRefresh.listen((value) {
      unawaited(send(value).catchError((Object _) {}));
    });
  }

  Future<void> revoke() async {
    final backend = api;
    final owner = backend?.auth.currentUser?.uid;
    if (!enabled || backend == null || owner == null) return;
    stopping = true;
    try {
      await tokens?.cancel();
      tokens = null;
      await pending?.catchError((Object _) {});
      final preferences = await SharedPreferences.getInstance();
      final installation = preferences.getString(_installationKey);
      if (installation == null) return;
      try {
        await backend.request<void>(
          'DELETE',
          'users/me/device-tokens/$installation',
          ownerUid: owner,
        );
      } catch (_) {
        // Invalidate the device token when the account cannot reach Mechi.
        // The backend sends through the Admin SDK registration-token contract.
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      }
    } finally {
      stopping = false;
    }
  }

  void dispose() {
    stopping = true;
    unawaited(tokens?.cancel());
  }
}
