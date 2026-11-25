import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/lucide_icons.dart';
import '../../core/design_system/mechi_ui.dart';
import '../garage/vehicle_image.dart';
import '../../core/design_system/mechi_logo.dart';
import '../garage/garage_state.dart';
import 'demo_map.dart';
import 'domain.dart';
import 'job_state.dart';
import 'request_screens.dart';

class JobScreen extends ConsumerWidget {
  const JobScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(jobsProvider);
    final controller = ref.read(jobsProvider.notifier);
    final job = controller.find(id);
    if (job == null) {
      return Screen(
        title: 'Job details',
        onBack: () => backOrHome(context),
        children: const [Text('Job unavailable.')],
      );
    }
    final mechanic = job.mechanicId == null
        ? null
        : ref.watch(mechanicsProvider).byId(job.mechanicId!);
    void back() => backOrHome(context);
    void receipt() => context.push('/receipt/$id');

    switch (job.status) {
      case JobStatus.quoted:
        return Screen(
          title: 'Review quote',
          onBack: back,
          footer: Panel(
            child: Column(
              children: [
                InfoRow('Total (USD)', usd(job.quote!.total), bold: true),
                ActionButton('Accept quote', () async {
                  await controller.move(job, JobStatus.accepted);
                }),
                TextButton(
                  onPressed: () {
                    controller.move(job, JobStatus.searching);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/discover/$id');
                    }
                  },
                  child: const Text('Decline quote'),
                ),
              ],
            ),
          ),
          children: [
            Panel(
              child: Column(
                children: [
                  MechanicIdentity(mechanic!),
                  InfoRow('Estimated arrival', '${mechanic.eta} min'),
                  InfoRow('Service', job.request.service.label),
                  InfoRow('Problem', job.request.problem),
                  InfoRow('Vehicle', job.request.vehicle.name),
                  InfoRow('Location', job.request.location),
                ],
              ),
            ),
            CostPanel(job.quote!),
            TextButton(
              onPressed: () => _cancel(context, controller, job),
              child: const Text('Cancel request'),
            ),
            const Panel(
              child: Text(
                'Your booking starts after you accept the quoted price.',
              ),
            ),
          ],
        );
      case JobStatus.accepted:
      case JobStatus.mechanicEnRoute:
      case JobStatus.mechanicArrived:
        final assigned = mechanic!;
        final (label, progress, eta) = switch (job.status) {
          JobStatus.accepted => (
            'Simulate departure',
            0.0,
            '${assigned.eta} min',
          ),
          JobStatus.mechanicEnRoute => (
            'Simulate arrival',
            .56,
            '${(assigned.eta / 2).ceil()} min',
          ),
          _ => ('Start simulated repair', 1.0, 'Arrived'),
        };
        return Screen(
          title: 'Track mechanic',
          onBack: back,
          footer: ActionButton(label, () => controller.advanceDemo(job)),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Mechi.radius),
              child: SizedBox(
                height: 290,
                child: DemoMap(
                  selected: assigned.id,
                  movement: progress,
                  location: job.request.location,
                ),
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipLabel(job.status.label, icon: LucideIcons.navigation),
                  const SizedBox(height: 8),
                  MechanicIdentity(assigned),
                  InfoRow('Arrival', eta, bold: true),
                  InfoRow('Meet at', job.request.location),
                  TextButton.icon(
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: const Text('Contact mechanic'),
                        content: Text(
                          '${assigned.name} will meet you at ${job.request.location}. Calls and messages are simulated.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    label: const Text('Contact mechanic'),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _cancel(context, controller, job),
              child: const Text('Cancel job'),
            ),
          ],
        );
      case JobStatus.repairInProgress:
      case JobStatus.awaitingCustomerConfirmation:
        final complete = job.status == JobStatus.awaitingCustomerConfirmation;
        final quote = job.quote!;
        return Screen(
          title: 'Repair status',
          onBack: back,
          footer: ActionButton(
            complete ? 'Review completion' : 'Advance demo repair',
            () {
              if (complete) {
                _completion(context, controller, job, mechanic!);
              } else {
                controller.advanceDemo(job);
              }
            },
          ),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MechanicIdentity(mechanic!),
                  const SizedBox(height: 8),
                  ChipLabel(
                    job.status.label,
                    icon: complete ? LucideIcons.check : LucideIcons.wrench,
                  ),
                  const SizedBox(height: 8),
                  Center(child: VehicleImage(job.request.vehicle, height: 100)),
                  Center(
                    child: ProgressRing(
                      job.progress / 100,
                      caption: complete ? 'Work complete' : 'Repair progress',
                    ),
                  ),
                  InfoRow('Vehicle', job.request.vehicle.name),
                  InfoRow(
                    'Estimated completion',
                    complete
                        ? 'Ready for review'
                        : '${(100 - job.progress) ~/ 4} min',
                  ),
                  InfoRow('Approved price', usd(quote.total), bold: true),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work and parts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    complete || job.progress >= 80
                        ? quote.work
                        : job.progress >= 50
                        ? 'Diagnosis complete. Repair underway.'
                        : 'Inspecting the reported issue.',
                  ),
                  InfoRow(
                    complete || job.progress >= 80
                        ? 'Parts used'
                        : 'Planned parts',
                    quote.partName,
                  ),
                ],
              ),
            ),
          ],
        );
      case JobStatus.paymentPending:
      case JobStatus.paymentProcessing:
      case JobStatus.paymentFailed:
      case JobStatus.cashPending:
        return PaymentScreen(job: job);
      case JobStatus.completed:
      case JobStatus.paid:
      case JobStatus.reviewed:
        return Screen(
          title: 'Job summary',
          onBack: back,
          footer: job.status == JobStatus.completed
              ? ActionButton(
                  'Continue to payment',
                  () => controller.move(job, JobStatus.paymentPending),
                )
              : ActionButton('View receipt', receipt),
          children: [
            ...summary(context, job, mechanic!),
            if (job.status == JobStatus.paid)
              ActionButton(
                'Rate mechanic',
                () => context.push('/review/$id'),
                secondary: true,
              ),
            if (job.rating != null)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow('Your rating', '${job.rating} / 5', bold: true),
                    if (job.review?.isNotEmpty ?? false) Text(job.review!),
                  ],
                ),
              ),
          ],
        );
      case JobStatus.draft:
      case JobStatus.searching:
      case JobStatus.cancelled:
        return Screen(
          title: 'Service request',
          onBack: back,
          children: [
            Panel(
              child: Column(
                children: [
                  ChipLabel(job.status.label),
                  InfoRow('Service', job.request.service.label),
                  InfoRow('Problem', job.request.problem),
                  InfoRow('Location', job.request.location),
                ],
              ),
            ),
            if (job.status == JobStatus.searching) ...[
              ActionButton(
                'Find mechanics',
                () => context.pushReplacement('/discover/$id'),
              ),
              TextButton(
                onPressed: () => _cancel(context, controller, job),
                child: const Text('Cancel job'),
              ),
            ],
          ],
        );
    }
  }

  Future<void> _cancel(
    BuildContext context,
    JobsController controller,
    Job job,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Mechi.scrim,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep job'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await controller.move(job, JobStatus.cancelled);
    }
  }

  Future<void> _completion(
    BuildContext context,
    JobsController controller,
    Job job,
    Mechanic mechanic,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Mechi.white,
      barrierColor: Mechi.scrim,
      sheetAnimationStyle: AnimationStyle(
        duration: Mechi.animate(context),
        reverseDuration: Mechi.animate(context),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Mechi.sheetRadius),
        ),
      ),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Text(
                'Repair complete',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(mechanic.name),
              const SizedBox(height: 16),
              const ProgressRing(1, caption: 'Work completed'),
              const ChipLabel('Ready for inspection', icon: LucideIcons.check),
              const SizedBox(height: 14),
              const Text(
                'Review the work and parts before confirming completion.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ActionButton(
                'Review job',
                () => showDialog<void>(
                  context: sheet,
                  barrierColor: Mechi.scrim,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Work completed'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.quote!.work),
                          const SizedBox(height: 8),
                          InfoRow('Parts used', job.quote!.partName),
                          InfoRow(
                            'Approved total',
                            usd(job.quote!.total),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Back to confirmation'),
                      ),
                    ],
                  ),
                ),
                secondary: true,
              ),
              const SizedBox(height: 8),
              ActionButton('Confirm completion', () {
                controller.move(job, JobStatus.completed);
                Navigator.pop(sheet);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class CostPanel extends StatelessWidget {
  const CostPanel(this.quote, {super.key});
  final Quote quote;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        InfoRow('Labour', usd(quote.labour)),
        InfoRow('Parts', usd(quote.parts)),
        InfoRow('Call-out fee', usd(quote.callout)),
        const Divider(color: Mechi.line),
        InfoRow('Total (USD)', usd(quote.total), bold: true),
      ],
    ),
  );
}

List<Widget> summary(BuildContext context, Job job, Mechanic mechanic) => [
  Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ChipLabel('Repair complete', icon: LucideIcons.checkCircle2),
        const SizedBox(height: 12),
        Text(
          job.request.problem,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const LinearProgressIndicator(
          value: 1,
          borderRadius: BorderRadius.all(Radius.circular(10)),
          minHeight: 6,
        ),
        const SizedBox(height: 8),
        InfoRow('Job reference', job.id),
        InfoRow('Status', job.status.label),
      ],
    ),
  ),
  Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MechanicIdentity(mechanic),
        InfoRow('Vehicle', job.request.vehicle.name),
        InfoRow('Service', job.request.service.label),
        InfoRow('Location', job.request.location),
        if (job.request.details.isNotEmpty)
          InfoRow('Reported issue', job.request.details),
        const Divider(color: Mechi.line),
        Text('Work completed', style: Theme.of(context).textTheme.titleMedium),
        Text(job.quote!.work),
        InfoRow('Parts used', job.quote!.partName),
      ],
    ),
  ),
  CostPanel(job.quote!),
];

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.job});
  final Job job;
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late PaymentMethod method =
      widget.job.method ?? ref.read(garageProvider).payment;
  bool fail = false, submitting = false;

  Future<void> _submit() async {
    if (submitting) return;
    final job = widget.job;
    final controller = ref.read(jobsProvider.notifier);
    final selected = method;
    final amount = usd(job.quote!.total);
    setState(() => submitting = true);
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Mechi.scrim,
      animationStyle: AnimationStyle(
        duration: Mechi.animate(context),
        reverseDuration: Mechi.animate(context),
      ),
      builder: (dialog) => AlertDialog(
        title: const Text('Confirm payment', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$amount USD', style: Theme.of(dialog).textTheme.titleLarge),
            InfoRow('Pay with', selected.label),
            InfoRow('Job', job.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Yes, pay'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (yes != true) {
      setState(() => submitting = false);
      return;
    }
    if (selected == PaymentMethod.cash) {
      await controller.pay(job, selected, fail: false);
      if (mounted) setState(() => submitting = false);
      return;
    }
    final shouldFail = fail;
    setState(() => fail = false);
    final router = GoRouter.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Mechi.scrim,
      builder: (_) => _PaymentResult(
        process: () => controller.pay(job, selected, fail: shouldFail),
        amount: amount,
        method: selected,
        onReceipt: () => router.push('/receipt/${job.id}'),
      ),
    );
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final processing = job.status == JobStatus.paymentProcessing;
    final cash = job.status == JobStatus.cashPending;
    return Screen(
      title: 'Payment',
      onBack: () => backOrHome(context),
      footer: Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total (USD)'),
                  Text(
                    usd(job.quote!.total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ActionButton(
                cash
                    ? 'Confirm cash received'
                    : processing
                    ? 'Processing…'
                    : 'Pay now',
                cash
                    ? () => ref.read(jobsProvider.notifier).confirmCash(job)
                    : processing || submitting
                    ? null
                    : _submit,
              ),
            ),
          ],
        ),
      ),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChipLabel('Simulated payment', icon: LucideIcons.shield),
              InfoRow('Service', job.request.problem),
              InfoRow('Job reference', job.id),
              if (cash)
                const Text(
                  'Cash awaiting confirmation. Use the button to simulate the mechanic acknowledging receipt.',
                ),
              if (job.status == JobStatus.paymentFailed)
                const Text(
                  'Payment failed. You can retry or select a different method.',
                  style: TextStyle(color: Mechi.error),
                ),
            ],
          ),
        ),
        CostPanel(job.quote!),
        if (!cash) ...[
          Text(
            'Payment method',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: RadioGroup<PaymentMethod>(
              groupValue: method,
              onChanged: (value) {
                if (value != null && !submitting && !processing) {
                  setState(() => method = value);
                }
              },
              child: Column(
                children: [
                  for (final option in PaymentMethod.values)
                    RadioListTile<PaymentMethod>(
                      enabled: !processing && !submitting,
                      value: option,
                      secondary: Icon(
                        switch (option) {
                          PaymentMethod.ecoCash => LucideIcons.smartphone,
                          PaymentMethod.card => LucideIcons.creditCard,
                          PaymentMethod.zimswitch => LucideIcons.landmark,
                          PaymentMethod.cash => LucideIcons.banknote,
                        },
                        size: 21,
                        color: Mechi.blue,
                      ),
                      title: Text(option.label),
                      controlAffinity: ListTileControlAffinity.trailing,
                      subtitle: Text(
                        option == PaymentMethod.cash
                            ? 'Confirm after handing over cash'
                            : 'Demo payment',
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (method != PaymentMethod.cash)
            SwitchListTile(
              title: const Text('Simulate failure on next attempt'),
              value: fail,
              onChanged: processing || submitting
                  ? null
                  : (value) => setState(() => fail = value),
            ),
        ],
      ],
    );
  }
}

class _PaymentResult extends StatefulWidget {
  const _PaymentResult({
    required this.process,
    required this.amount,
    required this.method,
    required this.onReceipt,
  });
  final Future<bool?> Function() process;
  final String amount;
  final PaymentMethod method;
  final VoidCallback onReceipt;
  @override
  State<_PaymentResult> createState() => _PaymentResultState();
}

class _PaymentResultState extends State<_PaymentResult> {
  late final result = Future<bool?>.microtask(widget.process);
  @override
  Widget build(BuildContext context) => FutureBuilder<bool?>(
    future: result,
    builder: (context, snapshot) {
      final done = snapshot.connectionState == ConnectionState.done;
      final paid = snapshot.data == true;
      return PopScope(
        canPop: done,
        child: AlertDialog(
          title: Text(
            !done
                ? 'Processing payment'
                : paid
                ? 'Payment successful'
                : 'Payment failed',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!done)
                const CircularProgressIndicator()
              else
                Icon(
                  paid ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                  color: paid ? Mechi.blue : Mechi.error,
                  size: 48,
                ),
              const SizedBox(height: 12),
              Text(
                '${widget.amount} USD · ${widget.method.label}',
                textAlign: TextAlign.center,
              ),
              if (paid)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Your receipt is ready.'),
                ),
            ],
          ),
          actions: done
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(paid ? 'Done' : 'Back to payment'),
                  ),
                  if (paid)
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onReceipt();
                      },
                      child: const Text('Print receipt'),
                    ),
                ]
              : null,
        ),
      );
    },
  );
}

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  int printCount = 0;
  @override
  Widget build(BuildContext context) {
    final job = ref
        .watch(receiptProvider)
        .receipt(widget.id, ref.watch(jobsProvider));
    if (job == null) {
      return Screen(
        title: 'Receipt',
        onBack: () => backOrHome(context),
        children: const [Text('Receipt unavailable.')],
      );
    }
    final mechanic = ref.watch(mechanicsProvider).byId(job.mechanicId!);
    final local = job.paidAt!.toUtc().add(const Duration(hours: 2));
    final date = local
        .toIso8601String()
        .replaceFirst('T', ' ')
        .substring(0, 16);
    return Scaffold(
      backgroundColor: Mechi.navy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => backOrHome(context),
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      color: Mechi.white,
                      size: 19,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Your receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Mechi.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: Mechi.pale,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              color: Mechi.muted,
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            key: ValueKey(printCount),
                            tween: Tween(begin: 0, end: 1),
                            duration: Mechi.animate(context, Mechi.printMotion),
                            curve: Mechi.curve,
                            builder: (_, value, child) => ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                heightFactor: value,
                                child: child,
                              ),
                            ),
                            child: Container(
                              color: Mechi.paper,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.all(16),
                              child: DefaultTextStyle.merge(
                                style: const TextStyle(
                                  fontFamily: Mechi.mono,
                                  fontSize: 11,
                                ),
                                child: Column(
                                  children: [
                                    const MechiLogo(height: 44),
                                    const Text('DEMONSTRATION SERVICE RECEIPT'),
                                    const SizedBox(height: 8),
                                    const Divider(color: Mechi.line),
                                    InfoRow('Receipt', job.receiptId),
                                    InfoRow('Job', job.id),
                                    InfoRow('Date (Harare)', date),
                                    InfoRow('Mechanic', mechanic.name),
                                    InfoRow(
                                      'Vehicle',
                                      job.request.vehicle.name,
                                    ),
                                    InfoRow('Service', job.request.problem),
                                    const Divider(color: Mechi.line),
                                    InfoRow('Labour', usd(job.quote!.labour)),
                                    InfoRow('Parts', usd(job.quote!.parts)),
                                    InfoRow(
                                      'Call-out',
                                      usd(job.quote!.callout),
                                    ),
                                    const Divider(color: Mechi.line),
                                    InfoRow(
                                      'TOTAL USD',
                                      usd(job.quote!.total),
                                      bold: true,
                                    ),
                                    InfoRow('Method', job.method!.label),
                                    const InfoRow(
                                      'Status',
                                      'DEMO PAID',
                                      bold: true,
                                    ),
                                    const SizedBox(height: 10),
                                    ExcludeSemantics(
                                      child: SizedBox(
                                        height: 22,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            for (var i = 0; i < 42; i++)
                                              Container(
                                                width: i % 4 == 0 ? 3 : 1.8,
                                                margin: EdgeInsets.only(
                                                  right: i % 3 == 0 ? 2.4 : 1.4,
                                                ),
                                                color: Mechi.navy,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: [
                  if (job.status == JobStatus.paid)
                    ActionButton(
                      'Rate mechanic',
                      () => context.push('/review/${job.id}'),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          'Print again',
                          () => setState(() => printCount++),
                          secondary: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ActionButton(
                          'Done',
                          () => backOrHome(context),
                          secondary: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final review = TextEditingController();
  int rating = 0;
  bool submitting = false;
  @override
  void dispose() {
    review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(jobsProvider);
    final controller = ref.read(jobsProvider.notifier);
    final job = controller.find(widget.id);
    final available = job?.status == JobStatus.paid;
    return Screen(
      title: 'Rate mechanic',
      onBack: () => backOrHome(context),
      footer: available
          ? ActionButton(
              'Submit review',
              rating == 0 || submitting
                  ? null
                  : () async {
                      setState(() => submitting = true);
                      await controller.review(job!, rating, review.text);
                      if (context.mounted) backOrHome(context);
                    },
            )
          : null,
      children: [
        if (!available)
          const Panel(child: Text('Review unavailable or already submitted.'))
        else ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MechanicIdentity(
                  ref.watch(mechanicsProvider).byId(job!.mechanicId!),
                ),
                const SizedBox(height: 14),
                const Text('How was your service?'),
                Wrap(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        tooltip: '$i star${i == 1 ? '' : 's'}',
                        onPressed: () => setState(() => rating = i),
                        icon: Icon(
                          LucideIcons.star,
                          color: i <= rating ? Mechi.star : Mechi.muted,
                        ),
                      ),
                  ],
                ),
                if (rating > 0) ChipLabel('$rating / 5'),
              ],
            ),
          ),
          TextField(
            controller: review,
            maxLength: 240,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Review (optional)'),
          ),
        ],
      ],
    );
  }
}
