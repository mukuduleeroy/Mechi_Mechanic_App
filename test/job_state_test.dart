import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechi/features/assistance/domain.dart';
import 'package:mechi/features/assistance/job_state.dart';
import 'package:mechi/features/garage/garage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'job persistence, failure, retry, duplicate protection and receipt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer container() => ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      final first = container();
      var controller = first.read(jobsProvider.notifier);
      const vehicle = Vehicle('test', 'Honda', 'Fit', 2017, 'TEST 123');
      final job = controller.start(
        const ServiceRequest(
          Service.roadside,
          'Flat tyre',
          '',
          vehicle,
          'Avondale',
        ),
      );
      expect(() => controller.move(job, JobStatus.paid), throwsStateError);
      final mechanic = first.read(mechanicsProvider).byId(0);
      await controller.quote(job, mechanic);
      expect(controller.find(job.id)!.quote!.total, 3600);
      await controller.move(job, JobStatus.accepted);
      first.dispose();
      final second = container();
      addTearDown(second.dispose);
      controller = second.read(jobsProvider.notifier);
      expect(controller.active!.id, job.id);
      expect(controller.active!.status, JobStatus.accepted);
      for (var i = 0; i < 6; i++) {
        await controller.advanceDemo(job);
      }
      expect(controller.active!.progress, 100);
      expect(controller.active!.status, JobStatus.awaitingCustomerConfirmation);
      await controller.move(job, JobStatus.completed);
      await controller.move(job, JobStatus.paymentPending);
      expect(
        await controller.pay(job, PaymentMethod.ecoCash, fail: true),
        false,
      );
      final retry = controller.pay(job, PaymentMethod.ecoCash, fail: false);
      expect(
        await controller.pay(job, PaymentMethod.card, fail: false),
        isNull,
      );
      expect(await retry, true);
      final receipt = second
          .read(receiptProvider)
          .receipt(job.id, second.read(jobsProvider));
      expect(receipt!.receiptId, 'R-${job.id}');
      expect(receipt.quote!.total, 3600);
      expect(receipt.method, PaymentMethod.ecoCash);
      await controller.review(job, 5, '  Excellent  ');
      expect(controller.find(job.id)!.review, 'Excellent');
      expect(controller.active, isNull);
    },
  );
}
