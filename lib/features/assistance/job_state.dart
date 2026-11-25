import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../garage/garage_state.dart';
import 'domain.dart';
import 'repositories.dart';

final mechanicsProvider = Provider<MechanicRepository>(
  (ref) => const DemoMechanics(),
);
final locationsProvider = Provider<LocationRepository>(
  (ref) => const DemoLocations(),
);
final jobsRepositoryProvider = Provider<JobRepository>(
  (ref) => LocalJobs(ref.watch(preferencesProvider)),
);
final paymentProvider = Provider<PaymentRepository>(
  (ref) => const DemoPayment(),
);
final quoteProvider = Provider<ServiceRequestRepository>(
  (ref) => const DemoService(),
);
final receiptProvider = Provider<ReceiptRepository>(
  (ref) => const DemoReceipt(),
);
final reviewProvider = Provider<ReviewRepository>((ref) => const DemoReview());
final demoClockProvider = Provider<DateTime>(
  (ref) => DateTime.utc(2026, 11, 25, 10),
);
final jobsProvider = NotifierProvider<JobsController, List<Job>>(
  JobsController.new,
);

class JobsController extends Notifier<List<Job>> {
  Future<void> _writes = Future.value();
  @override
  List<Job> build() => ref.watch(jobsRepositoryProvider).load();

  Job? get active {
    for (final job in state) {
      if (!job.status.settled && job.status != JobStatus.cancelled) return job;
    }
    return null;
  }

  Job? find(String id) {
    for (final job in state) {
      if (job.id == id) return job;
    }
    return null;
  }

  Future<void> _put(Job job) {
    state = [job, ...state.where((item) => item.id != job.id)];
    final snapshot = state;
    final repository = ref.read(jobsRepositoryProvider);
    _writes = _writes.then(
      (_) => repository.save(snapshot),
      onError: (Object _) => repository.save(snapshot),
    );
    return _writes;
  }

  Job start(ServiceRequest request) {
    if (active != null) {
      throw StateError('Finish or cancel the current job first.');
    }
    final id = 'MC-${(state.length + 1).toString().padLeft(4, '0')}';
    final job = Job(
      id: id,
      request: request,
      date: ref.read(demoClockProvider).add(Duration(minutes: state.length)),
    ).update(status: JobStatus.searching);
    _put(job);
    return job;
  }

  Future<void> quote(Job job, Mechanic mechanic) => _put(
    find(job.id)!.update(
      status: JobStatus.quoted,
      mechanicId: mechanic.id,
      quote: ref.read(quoteProvider).quote(job.request, mechanic),
    ),
  );

  Future<void> move(Job job, JobStatus next, {int? progress}) =>
      _put(find(job.id)!.update(status: next, progress: progress));

  Future<void> advanceDemo(Job job) async {
    final current = find(job.id)!;
    switch (current.status) {
      case JobStatus.accepted:
        await move(current, JobStatus.mechanicEnRoute);
      case JobStatus.mechanicEnRoute:
        await move(current, JobStatus.mechanicArrived);
      case JobStatus.mechanicArrived:
        await move(current, JobStatus.repairInProgress, progress: 20);
      case JobStatus.repairInProgress:
        if (current.progress >= 80) {
          await move(
            current,
            JobStatus.awaitingCustomerConfirmation,
            progress: 100,
          );
        } else {
          await _put(current.update(progress: current.progress + 30));
        }
      default:
        return;
    }
  }

  Future<bool?> pay(Job job, PaymentMethod method, {required bool fail}) async {
    final current = find(job.id)!;
    if (current.status != JobStatus.paymentPending &&
        current.status != JobStatus.paymentFailed) {
      return null;
    }
    if (method == PaymentMethod.cash) {
      await _put(current.update(status: JobStatus.cashPending, method: method));
      return null;
    }
    final processing = current.update(
      status: JobStatus.paymentProcessing,
      method: method,
    );
    await _put(processing);
    final result = await ref
        .read(paymentProvider)
        .process(processing, fail: fail);
    final latest = find(job.id);
    if (latest?.status != JobStatus.paymentProcessing) return null;
    await _put(
      latest!.update(
        status: result ? JobStatus.paid : JobStatus.paymentFailed,
        paidAt: result ? job.date.add(const Duration(minutes: 46)) : null,
      ),
    );
    return result;
  }

  Future<void> confirmCash(Job job) => _put(
    find(job.id)!.update(
      status: JobStatus.paid,
      paidAt: job.date.add(const Duration(minutes: 46)),
    ),
  );

  Future<void> review(Job job, int rating, String text) =>
      _put(ref.read(reviewProvider).submit(find(job.id)!, rating, text));
}
