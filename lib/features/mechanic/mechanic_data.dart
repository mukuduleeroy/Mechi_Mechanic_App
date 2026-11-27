import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../account/backend.dart';
import '../account/session.dart';

class MechanicFailure implements Exception {
  const MechanicFailure(this.message);
  final String message;
}

class MechanicProfile {
  MechanicProfile.fromJson(Json json)
    : displayName = json['displayName'] as String,
      bio = json['bio'] as String?,
      experienceYears = json['experienceYears'] as int?,
      status = json['verificationStatus'] as String,
      reason = json['reason'] as String?,
      availability = json['availability'] as String,
      editable = json['editable'] as bool,
      requirements = json['requirements'] as Json;

  final String displayName, status, availability;
  final String? bio, reason;
  final int? experienceYears;
  final bool editable;
  final Json requirements;
  bool get approved => status == 'APPROVED';
}

class MechanicData {
  MechanicData(
    this.profile,
    this.qualifications,
    this.documents,
    this.services,
    this.areas,
    this.categories,
  );
  final MechanicProfile profile;
  final List<Json> qualifications, documents, services, areas, categories;
}

class PrivateUpload {
  PrivateUpload(this.name, this.mime, this.bytes) : id = vehicleRequestId();
  final String name, mime, id;
  final Uint8List bytes;
}

abstract class MechanicDevice {
  Future<PrivateUpload?> pickDocument(int maxBytes);
  Future<Json> position({required bool requestPermission});
}

class NativeMechanicDevice implements MechanicDevice {
  @override
  Future<PrivateUpload?> pickDocument(int maxBytes) async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = selected.firstOrNull;
    if (file == null) return null;
    final mime = switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => throw const MechanicFailure('Choose a PDF, PNG or JPEG file.'),
    };
    if ((file.lengthSync() ?? 0) > maxBytes) {
      throw const MechanicFailure(
        'The selected file is too large or unreadable.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const MechanicFailure('The selected file is too large.');
      }
      bytes.add(chunk);
    }
    if (bytes.length == 0 || bytes.length > maxBytes) {
      throw const MechanicFailure('The selected file is empty or too large.');
    }
    return PrivateUpload(file.name, mime, bytes.takeBytes());
  }

  @override
  Future<Json> position({required bool requestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const MechanicFailure('Turn on device location to go available.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const MechanicFailure(
        'Allow location while using Mechi to go available.',
      );
    }
    final point = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
      if (point.accuracy >= 0 && point.accuracy <= 10000)
        'accuracyMetres': point.accuracy,
      if (point.heading >= 0 && point.heading < 360) 'heading': point.heading,
      'observedAt': point.timestamp.toUtc().toIso8601String(),
    };
  }
}

final mechanicDeviceProvider = Provider<MechanicDevice>(
  (_) => NativeMechanicDevice(),
);

class MechanicRepository {
  MechanicRepository(this.api) : ownerUid = api.auth.currentUser?.uid;
  final MechiApi api;
  final String? ownerUid;

  Future<T> request<T>(
    String method,
    String path, {
    Json? body,
    CancelToken? cancel,
  }) {
    if (ownerUid == null || api.auth.currentUser?.uid != ownerUid) {
      throw StateError('Mechanic account changed');
    }
    return api.request<T>(
      method,
      path == 'service-categories'
          ? path
          : 'mechanics/me${path.isEmpty ? '' : '/$path'}',
      body: body,
      cancelToken: cancel,
      ownerUid: ownerUid,
    );
  }

  Future<MechanicData> load(CancelToken cancel) async {
    final results = await Future.wait<Object>([
      request<Json>('GET', '', cancel: cancel),
      for (final path in [
        'qualifications',
        'documents',
        'services',
        'areas',
        'service-categories',
      ])
        request<List<dynamic>>('GET', path, cancel: cancel),
    ]);
    List<Json> list(int index) => (results[index] as List).cast<Json>();
    return MechanicData(
      MechanicProfile.fromJson(results[0] as Json),
      list(1),
      list(2),
      list(3),
      list(4),
      list(5),
    );
  }

  Future<void> upload(
    PrivateUpload file,
    String type,
    String? qualificationId,
  ) => request<Json>(
    'POST',
    'documents',
    body: {
      'id': file.id,
      'type': type,
      'qualificationId': qualificationId,
      'contentType': file.mime,
      'contentBase64': base64Encode(file.bytes),
    },
  );

  Future<Json> availability(String value) =>
      request<Json>('PATCH', 'availability', body: {'status': value});
}

final mechanicRepositoryProvider = Provider.autoDispose((ref) {
  ref.watch(sessionProvider.select((session) => session.account?.id));
  return MechanicRepository(ref.watch(apiProvider)!);
});

final mechanicDataProvider = FutureProvider.autoDispose
    .family<MechanicData, String>((ref, owner) async {
      final session = ref.watch(
        sessionProvider.select(
          (value) => (value.account?.id, value.role?.role),
        ),
      );
      if (session != (owner, AccountRole.mechanic)) {
        throw StateError('Mechanic session changed');
      }
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return ref.watch(mechanicRepositoryProvider).load(cancel);
    });
