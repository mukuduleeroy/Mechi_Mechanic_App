import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';

abstract interface class JobRepository {
  List<Job> load();
  Future<void> save(List<Job> jobs);
}

abstract interface class MechanicRepository {
  List<Mechanic> get all;
  Mechanic byId(int id);
}

abstract interface class ServiceRequestRepository {
  Quote quote(ServiceRequest request, Mechanic mechanic);
}

abstract interface class LocationRepository {
  List<String> get locations;
}

abstract interface class PaymentRepository {
  Future<bool> process(Job job, {required bool fail});
}

abstract interface class ReceiptRepository {
  Job? receipt(String id, Iterable<Job> jobs);
}

abstract interface class ReviewRepository {
  Job submit(Job job, int rating, String review);
}

class DemoMechanics implements MechanicRepository {
  const DemoMechanics();
  @override
  List<Mechanic> get all => const [
    Mechanic(
      0,
      'Tariro Moyo',
      'Avondale',
      'Diagnostics & roadside',
      4.9,
      2.4,
      8,
      9,
      1200,
    ),
    Mechanic(
      1,
      'Nyasha Dube',
      'Belgravia',
      'Electrical & batteries',
      4.8,
      3.1,
      11,
      7,
      1000,
    ),
    Mechanic(
      2,
      'Kudzai Ncube',
      'Milton Park',
      'Tyres & suspension',
      4.9,
      3.8,
      13,
      11,
      1200,
    ),
    Mechanic(
      3,
      'Rudo Chirenje',
      'Eastlea',
      'Brakes & scheduled servicing',
      4.7,
      5.2,
      17,
      6,
      1400,
    ),
    Mechanic(
      4,
      'Farai Banda',
      'Newlands',
      'Cooling & electrical',
      4.8,
      6.4,
      20,
      8,
      1500,
    ),
    Mechanic(
      5,
      'Tendai Maseko',
      'Mount Pleasant',
      'Engine & general repair',
      4.9,
      7.5,
      24,
      12,
      1600,
    ),
  ];

  @override
  Mechanic byId(int id) => all.firstWhere((m) => m.id == id);
}

class DemoLocations implements LocationRepository {
  const DemoLocations();
  @override
  List<String> get locations => const [
    'Avondale Shopping Centre',
    'Samora Machel Avenue',
    'Borrowdale Village',
    'Newlands Shopping Centre',
  ];
}

class DemoService implements ServiceRequestRepository {
  const DemoService();
  @override
  Quote quote(ServiceRequest request, Mechanic mechanic) {
    final (cost, parts, work, part) = switch (request.problem) {
      'Flat tyre' => (
        1800,
        600,
        'Located the puncture, patched the tyre and checked pressure.',
        'Tyre puncture kit',
      ),
      'Battery / starting' => (
        2000,
        800,
        'Tested the charging circuit and restored the battery connection.',
        'Battery terminal kit',
      ),
      'Routine service' => (
        3500,
        2600,
        'Changed engine oil and checked fluids, belts and brakes.',
        'Engine oil and filter',
      ),
      'Overheating' => (
        2500,
        900,
        'Pressure tested the cooling system and replaced a worn clamp.',
        'Coolant and clamp',
      ),
      _ => (
        2400,
        0,
        'Inspected the reported problem and ran a diagnostic test.',
        'None',
      ),
    };
    return Quote(cost, parts, mechanic.callout, work, part);
  }
}

class DemoPayment implements PaymentRepository {
  const DemoPayment();
  @override
  Future<bool> process(Job job, {required bool fail}) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    return !fail;
  }
}

class DemoReceipt implements ReceiptRepository {
  const DemoReceipt();
  @override
  Job? receipt(String id, Iterable<Job> jobs) {
    for (final job in jobs) {
      if (job.id == id && job.status.settled) return job;
    }
    return null;
  }
}

class DemoReview implements ReviewRepository {
  const DemoReview();
  @override
  Job submit(Job job, int rating, String review) {
    if (rating < 1 || rating > 5) throw ArgumentError.value(rating);
    return job.update(
      status: JobStatus.reviewed,
      rating: rating,
      review: review.trim(),
    );
  }
}

class LocalJobs implements JobRepository {
  const LocalJobs(this.prefs);
  final SharedPreferences prefs;
  static const key = 'mechi.jobs.v1';

  @override
  List<Job> load() {
    final raw = prefs.getString(key);
    if (raw != null) {
      return (jsonDecode(raw) as List).map((json) {
        final job = Job.fromJson(json);
        return job.status == JobStatus.paymentProcessing
            ? job.update(status: JobStatus.paymentFailed)
            : job;
      }).toList();
    }
    final date = DateTime.utc(2026, 11, 8, 8, 30);
    const vehicle = Vehicle('corolla', 'Toyota', 'Corolla', 2018, 'AFK 3127');
    const service = DemoService();
    final mechanics = const DemoMechanics().all;
    return [
      for (final (i, type, problem) in [
        (0, Service.home, 'Routine service'),
        (1, Service.roadside, 'Battery / starting'),
      ])
        Job(
          id: 'DEMO-00${i + 1}',
          request: ServiceRequest(
            type,
            problem,
            '',
            vehicle,
            const DemoLocations().locations[i],
          ),
          date: date.subtract(Duration(days: i * 5)),
          mechanicId: i,
          quote: service.quote(
            ServiceRequest(type, problem, '', vehicle, ''),
            mechanics[i],
          ),
          progress: 100,
          status: i == 0 ? JobStatus.reviewed : JobStatus.paid,
          method: i == 0 ? PaymentMethod.ecoCash : PaymentMethod.cash,
          paidAt: date
              .subtract(Duration(days: i * 5))
              .add(const Duration(hours: 1)),
          rating: i == 0 ? 5 : null,
          review: i == 0 ? 'Arrived on time and explained the work.' : null,
        ),
    ];
  }

  @override
  Future<void> save(List<Job> jobs) => prefs.setString(
    key,
    jsonEncode(jobs.map((job) => job.toJson()).toList()),
  );
}
