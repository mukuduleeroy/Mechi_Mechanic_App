import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../assistance/domain.dart';
import '../account/backend.dart';
import '../account/driver_data.dart';
import '../account/session.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized'),
);
final garageProvider = NotifierProvider<GarageController, Garage>(
  GarageController.new,
);

abstract interface class VehicleRepository {
  Garage load();
  Future<void> save(Garage garage);
}

class Garage {
  const Garage(
    this.vehicles,
    this.selected,
    this.customer,
    this.lowData,
    this.emergency,
    this.payment,
  );
  final List<Vehicle> vehicles;
  final String selected, customer, emergency;
  final bool lowData;
  final PaymentMethod payment;
  Vehicle? get activeOrNull => vehicles.isEmpty ? null : active;
  Vehicle get active => vehicles.firstWhere(
    (v) => v.id == selected,
    orElse: () => vehicles.first,
  );
}

class LocalVehicles implements VehicleRepository {
  LocalVehicles(this.prefs);
  final SharedPreferences prefs;
  static const key = 'mechi.garage.v1';
  static const seeds = [
    Vehicle('corolla', 'Toyota', 'Corolla', 2018, 'AFK 3127', colour: 'silver'),
    Vehicle('fit', 'Honda', 'Fit', 2017, 'AES 1084', colour: 'white'),
    Vehicle('ranger', 'Ford', 'Ranger', 2021, 'AGC 5402', colour: 'graphite'),
  ];
  @override
  Garage load() {
    final raw = prefs.getString(key);
    if (raw == null) {
      return const Garage(
        seeds,
        'corolla',
        'Tadiwa M.',
        true,
        '',
        PaymentMethod.ecoCash,
      );
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return Garage(
      (data['vehicles'] as List).map((json) => Vehicle.fromJson(json)).toList(),
      data['selected'],
      data['customer'],
      data['lowData'],
      data['emergency'],
      PaymentMethod.values.byName(data['payment']),
    );
  }

  @override
  Future<void> save(Garage g) => prefs.setString(
    key,
    jsonEncode({
      'vehicles': g.vehicles.map((v) => v.toJson()).toList(),
      'selected': g.selected,
      'customer': g.customer,
      'lowData': g.lowData,
      'emergency': g.emergency,
      'payment': g.payment.name,
    }),
  );
}

class GarageController extends Notifier<Garage> {
  String? _selection;
  String? _selectionOwner;

  void selectForSession(String id) {
    final owner = ref.read(sessionProvider).account?.id;
    if (owner == null || !state.vehicles.any((vehicle) => vehicle.id == id)) {
      return;
    }
    _selectionOwner = owner;
    _selection = id;
    final garage = state;
    state = Garage(
      garage.vehicles,
      id,
      garage.customer,
      garage.lowData,
      garage.emergency,
      garage.payment,
    );
  }

  VehicleRepository get repository =>
      LocalVehicles(ref.read(preferencesProvider));
  @override
  Garage build() {
    if (ref.watch(apiProvider) == null) return repository.load();
    final owner = ref.watch(
      sessionProvider.select(
        (value) => value.stage == SessionStage.ready ? value.account?.id : null,
      ),
    );
    if (_selectionOwner != owner) {
      _selectionOwner = owner;
      _selection = null;
    }
    if (owner == null) {
      return const Garage([], '', '', true, '', PaymentMethod.ecoCash);
    }
    final data = ref.watch(driverDataProvider(owner)).value;
    final vehicles = data?.vehicles ?? const <Vehicle>[];
    final defaultVehicle = vehicles
        .where((vehicle) => vehicle.isDefault)
        .firstOrNull;
    final selected = vehicles.any((vehicle) => vehicle.id == _selection)
        ? _selection
        : null;
    return Garage(
      vehicles,
      selected ?? defaultVehicle?.id ?? vehicles.firstOrNull?.id ?? '',
      data?.profile.name ?? 'Driver',
      true,
      '',
      PaymentMethod.ecoCash,
    );
  }

  Future<void> save({
    Vehicle? vehicle,
    String? selected,
    String? customer,
    bool? lowData,
    String? emergency,
    PaymentMethod? payment,
  }) async {
    final vehicles = [...state.vehicles];
    if (vehicle != null) {
      final index = vehicles.indexWhere((item) => item.id == vehicle.id);
      if (index < 0) {
        vehicles.add(vehicle);
      } else {
        vehicles[index] = vehicle;
      }
    }
    final next = Garage(
      vehicles,
      selected ?? state.selected,
      customer ?? state.customer,
      lowData ?? state.lowData,
      emergency ?? state.emergency,
      payment ?? state.payment,
    );
    state = next;
    await repository.save(next);
  }
}
