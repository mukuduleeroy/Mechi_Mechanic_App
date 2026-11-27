import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../account/backend.dart';
import '../account/session.dart';

final marketplaceProvider = Provider.autoDispose((ref) {
  ref.watch(sessionProvider.select((value) => value.account?.id));
  final api = ref.watch(apiProvider)!;
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return MarketplaceRepository(api, token);
});

class MarketplaceRepository {
  MarketplaceRepository(this.api, this.token)
    : owner = api.auth.currentUser?.uid;
  final MechiApi api;
  final CancelToken token;
  final String? owner;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => api.request(
    'GET',
    path,
    query: query,
    ownerUid: owner,
    cancelToken: token,
  );

  Future<Json> post(String path, {Json? body, String? key}) => api.request(
    'POST',
    path,
    body: body,
    idempotencyKey: key,
    ownerUid: owner,
    cancelToken: token,
  );
}

class SubmissionKey {
  String? _payload;
  String? _key;

  void reset() {
    _payload = null;
    _key = null;
  }

  String forPayload(Json data) {
    final payload = jsonEncode(data);
    if (payload != _payload) {
      _payload = payload;
      _key = vehicleRequestId();
    }
    return _key!;
  }
}

const openRequestStatuses = {'SEARCHING', 'OFFERS_RECEIVED'};

String marketplaceError(Object error) {
  final failure = ApiFailure.of(error);
  return switch (failure.status) {
    422 => 'Roadside assistance is unavailable at this location.',
    409 => 'This request or offer has changed. Refresh it before continuing.',
    404 => 'This marketplace record is unavailable.',
    _ => failure.message,
  };
}

String statusLabel(Object? status) => switch (status) {
  'SEARCHING' => 'Searching for mechanics',
  'OFFERS_RECEIVED' => 'Offers received',
  'NO_MECHANIC_AVAILABLE' => 'No mechanic available',
  'ASSIGNED' || 'CONFIRMED' => 'Confirmed assignment',
  'CANCELLED' => 'Request cancelled',
  'EXPIRED' => 'Expired',
  'QUOTED' || 'PENDING' => 'Pending',
  _ => (status ?? '').toString().toLowerCase(),
};

String minorLabel(Object? currency, Object? minor, [Object? precision]) {
  final amount = minor?.toString();
  if (amount == null || !RegExp(r'^[0-9]+$').hasMatch(amount)) return '—';
  final digits = precision is int && precision >= 0 && precision <= 4
      ? precision
      : 2;
  if (digits == 0) return '$currency $amount';
  final padded = amount.padLeft(digits + 1, '0');
  final split = padded.length - digits;
  return '$currency ${padded.substring(0, split)}.${padded.substring(split)}';
}

mixin ForegroundPoll<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  static const _configuredSeconds = int.fromEnvironment(
    'MECHI_MARKETPLACE_POLL_SECONDS',
    defaultValue: 4,
  );
  Timer? _timer;
  bool _checking = false, _refreshAgain = false;
  bool _foreground = true;
  int _failures = 0;
  io.Socket? _marketplaceSocket;
  Timer? _socketRetry;
  int _socketGeneration = 0;
  String? get marketplaceScope => null;
  MarketplaceRepository? get marketplaceConnection => null;

  Future<void> _watchMarketplace({bool refreshToken = false}) async {
    final scope = marketplaceScope;
    final repository = marketplaceConnection;
    if (!_foreground || scope == null || repository == null || !mounted) return;
    final generation = ++_socketGeneration;
    void retry() {
      if (!mounted || !_foreground || generation != _socketGeneration) return;
      _stopMarketplaceSocket();
      _socketRetry = Timer(const Duration(seconds: 12), () {
        unawaited(_watchMarketplace(refreshToken: true));
      });
    }

    try {
      final token = await repository.api.auth.currentUser?.getIdToken(
        refreshToken,
      );
      if (!mounted ||
          !_foreground ||
          generation != _socketGeneration ||
          token == null) {
        return;
      }
      final host = Uri.parse(repository.api.dio.options.baseUrl).origin;
      final socket = io.io(
        '$host/jobs',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .disableReconnection()
            .enableForceNew()
            .setAuth({'token': token})
            .build(),
      );
      _marketplaceSocket = socket;
      socket.onConnect((_) {
        socket.emitWithAck(
          'watch-marketplace',
          scope,
          ack: (reply) {
            if (!mounted || generation != _socketGeneration) return;
            if (reply is Map && reply['ok'] == true) {
              unawaited(refresh());
            } else {
              retry();
            }
          },
        );
      });
      socket.onDisconnect((_) => retry());
      socket.onConnectError((_) => retry());
      socket.on('marketplace-changed', (_) {
        if (mounted && generation == _socketGeneration) unawaited(refresh());
      });
      socket.connect();
    } catch (_) {
      retry();
    }
  }

  void _stopMarketplaceSocket() {
    _socketGeneration++;
    _socketRetry?.cancel();
    _marketplaceSocket?.dispose();
    _marketplaceSocket = null;
  }

  bool get keepPolling => true;

  Future<void> poll();
  void pollError(Object error);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(refresh());
      if (mounted) unawaited(_watchMarketplace());
    });
  }

  Future<void> refresh() async {
    _timer?.cancel();
    if (!mounted || !_foreground) return;
    if (_checking) {
      _refreshAgain = true;
      return;
    }
    _checking = true;
    try {
      await poll();
      _failures = 0;
    } catch (error) {
      _failures = min(3, _failures + 1);
      if (mounted) pollError(error);
    } finally {
      _checking = false;
      if (_refreshAgain && mounted && _foreground) {
        _refreshAgain = false;
        scheduleMicrotask(refresh);
      } else if (mounted && _foreground && keepPolling) {
        final seconds = (_configuredSeconds.clamp(2, 15) * (1 << _failures))
            .clamp(2, 60);
        _timer = Timer(Duration(seconds: seconds), refresh);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _stopMarketplaceSocket();
    } else if (!wasForeground) {
      unawaited(_watchMarketplace());
    }
    if (_foreground && keepPolling) {
      unawaited(refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _stopMarketplaceSocket();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
