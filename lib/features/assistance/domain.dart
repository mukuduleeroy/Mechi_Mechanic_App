enum Service {
  roadside('Roadside assistance'),
  home('Home service');

  const Service(this.label);
  final String label;
}

enum JobStatus {
  draft('Draft'),
  searching('Finding mechanics'),
  quoted('Quote ready'),
  accepted('Booking confirmed'),
  mechanicEnRoute('Mechanic en route'),
  mechanicArrived('Mechanic arrived'),
  repairInProgress('Repair in progress'),
  awaitingCustomerConfirmation('Repair ready for review'),
  completed('Repair confirmed'),
  paymentPending('Payment pending'),
  paymentProcessing('Processing payment'),
  paymentFailed('Payment failed'),
  cashPending('Cash awaiting confirmation'),
  paid('Paid'),
  reviewed('Reviewed'),
  cancelled('Cancelled');

  const JobStatus(this.label);
  final String label;
  bool get settled => this == paid || this == reviewed;
  bool allows(JobStatus next) => switch (this) {
    draft => [searching, cancelled],
    searching => [quoted, cancelled],
    quoted => [accepted, searching, cancelled],
    accepted => [mechanicEnRoute, cancelled],
    mechanicEnRoute => [mechanicArrived, cancelled],
    mechanicArrived => [repairInProgress, cancelled],
    repairInProgress => [awaitingCustomerConfirmation],
    awaitingCustomerConfirmation => [completed],
    completed => [paymentPending],
    paymentPending || paymentFailed => [paymentProcessing, cashPending],
    paymentProcessing => [paid, paymentFailed],
    cashPending => [paid],
    paid => [reviewed],
    reviewed || cancelled => <JobStatus>[],
  }.contains(next);
}

enum PaymentMethod {
  ecoCash('EcoCash'),
  card('Debit or credit card'),
  zimswitch('Zimswitch'),
  cash('Cash');

  const PaymentMethod(this.label);
  final String label;
}

String usd(int cents) =>
    '\$${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

class Vehicle {
  const Vehicle(
    this.id,
    this.make,
    this.model,
    this.year,
    this.plate, {
    this.colour,
  });
  final String id, make, model, plate;
  final int year;
  final String? colour;
  String get name => '$make $model';
  Map<String, Object?> toJson() => {
    'id': id,
    'make': make,
    'model': model,
    'year': year,
    'plate': plate,
    if (colour != null) 'colour': colour,
  };
  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    j['id'],
    j['make'],
    j['model'],
    j['year'],
    j['plate'],
    colour: j['colour'] as String?,
  );
}

class Mechanic {
  const Mechanic(
    this.id,
    this.name,
    this.area,
    this.specialty,
    this.rating,
    this.distance,
    this.eta,
    this.experience,
    this.callout,
  );
  final int id, eta, experience, callout;
  final String name, area, specialty;
  final double rating, distance;
  String get initials => name.split(' ').map((part) => part[0]).join();
}

class ServiceRequest {
  const ServiceRequest(
    this.service,
    this.problem,
    this.details,
    this.vehicle,
    this.location,
  );
  final Service service;
  final String problem, details, location;
  final Vehicle vehicle;
  Map<String, Object?> toJson() => {
    'service': service.name,
    'problem': problem,
    'details': details,
    'vehicle': vehicle.toJson(),
    'location': location,
  };
  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
    Service.values.byName(j['service']),
    j['problem'],
    j['details'],
    Vehicle.fromJson(j['vehicle']),
    j['location'],
  );
}

class Quote {
  const Quote(this.labour, this.parts, this.callout, this.work, this.partName);
  final int labour, parts, callout;
  final String work, partName;
  int get total => labour + parts + callout;
  Map<String, Object?> toJson() => {
    'labour': labour,
    'parts': parts,
    'callout': callout,
    'work': work,
    'partName': partName,
  };
  factory Quote.fromJson(Map<String, dynamic> j) =>
      Quote(j['labour'], j['parts'], j['callout'], j['work'], j['partName']);
}

class Job {
  Job({
    required this.id,
    required this.request,
    required this.date,
    this.status = JobStatus.draft,
    this.mechanicId,
    this.quote,
    this.progress = 0,
    this.method,
    this.paidAt,
    this.rating,
    this.review,
  });
  final String id;
  final ServiceRequest request;
  final DateTime date;
  final JobStatus status;
  final int? mechanicId, rating;
  final int progress;
  final Quote? quote;
  final PaymentMethod? method;
  final DateTime? paidAt;
  final String? review;
  String get receiptId => 'R-$id';
  Job update({
    JobStatus? status,
    int? mechanicId,
    Quote? quote,
    int? progress,
    PaymentMethod? method,
    DateTime? paidAt,
    int? rating,
    String? review,
  }) {
    if (status != null && !this.status.allows(status)) {
      throw StateError(
        'Invalid transition ${this.status.name} to ${status.name}',
      );
    }
    return Job(
      id: id,
      request: request,
      date: date,
      status: status ?? this.status,
      mechanicId: status == JobStatus.searching
          ? null
          : mechanicId ?? this.mechanicId,
      quote: status == JobStatus.searching ? null : quote ?? this.quote,
      progress: progress ?? this.progress,
      method: method ?? this.method,
      paidAt: paidAt ?? this.paidAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'request': request.toJson(),
    'date': date.toIso8601String(),
    'status': status.name,
    'mechanic': mechanicId,
    'quote': quote?.toJson(),
    'progress': progress,
    'method': method?.name,
    'paidAt': paidAt?.toIso8601String(),
    'rating': rating,
    'review': review,
  };
  factory Job.fromJson(Map<String, dynamic> j) => Job(
    id: j['id'],
    request: ServiceRequest.fromJson(j['request']),
    date: DateTime.parse(j['date']),
    status: JobStatus.values.byName(j['status']),
    mechanicId: j['mechanic'],
    quote: j['quote'] == null ? null : Quote.fromJson(j['quote']),
    progress: j['progress'] ?? 0,
    method: j['method'] == null
        ? null
        : PaymentMethod.values.byName(j['method']),
    paidAt: j['paidAt'] == null ? null : DateTime.parse(j['paidAt']),
    rating: j['rating'],
    review: j['review'],
  );
}
