import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../assistance/domain.dart';
import 'backend.dart';
import 'session.dart';

class DriverProfile {
  DriverProfile.fromJson(Json json)
    : firstName = json['firstName'] as String,
      lastName = json['lastName'] as String,
      contactPreference = json['contactPreference'] as String?,
      region = (json['region'] as Json?)?['name'] as String?,
      completed = json['completedAt'] != null;
  final String firstName, lastName;
  final String? contactPreference, region;
  final bool completed;
  String get name => '$firstName $lastName';
}

class EmergencyContact {
  EmergencyContact.fromJson(Json json)
    : id = json['id'] as String,
      name = json['name'] as String,
      phone = json['phone'] as String,
      relationship = json['relationship'] as String,
      isPrimary = json['isPrimary'] as bool;
  final String id, name, phone, relationship;
  final bool isPrimary;
}

class CatalogueChoice {
  const CatalogueChoice(
    this.id,
    this.make,
    this.model,
    this.generation,
    this.yearFrom,
    this.yearTo,
  );
  final String id, make, model;
  final String? generation;
  final int? yearFrom, yearTo;
  String get label =>
      [make, model, if (generation != null) generation].join(' ');
}

class ServiceCategory {
  ServiceCategory.fromJson(Json json)
    : id = json['id'] as String?,
      code = json['code'] as String,
      name = json['name'] as String,
      immediate = json['supportsImmediate'] as bool,
      scheduled = json['supportsScheduled'] as bool;
  final String? id;
  final String code, name;
  final bool immediate, scheduled;
}

class DriverData {
  const DriverData(this.profile, this.vehicles, this.contacts);
  final DriverProfile profile;
  final List<Vehicle> vehicles;
  final List<EmergencyContact> contacts;
}

class CatalogueEntries {
  const CatalogueEntries(this.items, {this.cached = false});
  final List<Json> items;
  final bool cached;
}

class DriverRepository {
  DriverRepository(this.api) : ownerUid = api.auth.currentUser?.uid;
  final MechiApi api;
  final String? ownerUid;
  final _catalogue = <String, List<Json>>{};

  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    if (ownerUid == null || api.auth.currentUser?.uid != ownerUid) {
      throw StateError('Driver session changed');
    }
    return api.request<T>(
      method,
      path,
      body: body,
      query: query,
      cancelToken: cancelToken,
      ownerUid: ownerUid,
    );
  }

  Future<DriverData> load(CancelToken token) async {
    final results = await Future.wait<Object>([
      _request<Json>('GET', 'drivers/me', cancelToken: token),
      _request<List<dynamic>>('GET', 'vehicles', cancelToken: token),
      _request<List<dynamic>>(
        'GET',
        'drivers/me/emergency-contacts',
        cancelToken: token,
      ),
    ]);
    return DriverData(
      DriverProfile.fromJson(results[0] as Json),
      (results[1] as List).cast<Json>().map(Vehicle.fromJson).toList(),
      (results[2] as List).cast<Json>().map(EmergencyContact.fromJson).toList(),
    );
  }

  Future<void> updateProfile(String first, String last, String? preference) =>
      _request<Json>(
        'PATCH',
        'drivers/me',
        body: {
          'firstName': first,
          'lastName': last,
          'contactPreference': preference,
        },
      );

  Future<void> updateContact(
    EmergencyContact? contact,
    Json values,
  ) => _request<Json>(
    contact == null ? 'POST' : 'PATCH',
    'drivers/me/emergency-contacts${contact == null ? '' : '/${contact.id}'}',
    body: values,
  );

  Future<void> deleteContact(String id) =>
      _request<void>('DELETE', 'drivers/me/emergency-contacts/$id');

  Future<Vehicle> saveVehicle(Vehicle value, {required bool create}) async {
    final result = await _request<Json>(
      create ? 'POST' : 'PATCH',
      create ? 'vehicles' : 'vehicles/${value.id}',
      body: {
        if (create) 'id': value.id,
        'variantId': value.variantId,
        'make': value.variantId == null ? value.make : null,
        'model': value.variantId == null ? value.model : null,
        'year': value.year,
        'plate': value.plate,
        'colour': value.colour,
      },
    );
    return Vehicle.fromJson(result);
  }

  Future<void> archiveVehicle(String id) =>
      _request<void>('DELETE', 'vehicles/$id');
  Future<void> setDefault(String id) =>
      _request<Json>('PUT', 'vehicles/$id/default');

  Future<CatalogueEntries> cataloguePage(String path) async {
    if (ownerUid == null || api.auth.currentUser?.uid != ownerUid) {
      throw StateError('Driver session changed');
    }
    try {
      final items = <Json>[];
      int? offset = 0;
      while (offset != null) {
        final page = await _request<Json>(
          'GET',
          path,
          query: {'offset': offset, 'limit': 100},
        );
        items.addAll((page['items'] as List).cast<Json>());
        offset = page['nextOffset'] as int?;
      }
      _catalogue[path] = items;
      return CatalogueEntries(items);
    } on DioException catch (error) {
      final cached = _catalogue[path];
      if (cached != null &&
          error.type != DioExceptionType.cancel &&
          api.auth.currentUser?.uid == ownerUid &&
          ApiFailure.of(error).recoverable) {
        return CatalogueEntries(cached, cached: true);
      }
      rethrow;
    }
  }
}

final driverRepositoryProvider = Provider((ref) {
  ref.watch(sessionProvider.select((session) => session.account?.id));
  return DriverRepository(ref.watch(apiProvider)!);
});

final driverDataProvider = FutureProvider.autoDispose
    .family<DriverData, String>((ref, owner) async {
      final repository = ref.watch(driverRepositoryProvider);
      final accountId = ref.watch(
        sessionProvider.select((session) => session.account?.id),
      );
      if (accountId != owner ||
          ref.read(sessionProvider).account?.status != AccountStatus.active) {
        throw StateError('Driver session changed');
      }
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final data = await repository.load(token);
      if (token.isCancelled) throw StateError('Driver session changed');
      return data;
    });

final categoriesProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiProvider)!;
  final token = CancelToken();
  ref.onDispose(token.cancel);
  final rows = await api.request<List<dynamic>>(
    'GET',
    'service-categories',
    cancelToken: token,
  );
  return rows.cast<Json>().map(ServiceCategory.fromJson).toList();
});
