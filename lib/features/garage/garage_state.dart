import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../assistance/domain.dart';

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
    Vehicle('corolla', 'Toyota', 'Corolla', 2018, 'AFK 3127'),
    Vehicle('fit', 'Honda', 'Fit', 2017, 'AES 1084'),
    Vehicle('ranger', 'Ford', 'Ranger', 2021, 'AGC 5402'),
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
  VehicleRepository get repository =>
      LocalVehicles(ref.read(preferencesProvider));
  @override
  Garage build() => repository.load();
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
