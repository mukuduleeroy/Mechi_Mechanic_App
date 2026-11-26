import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/design_system.dart';
import 'mechanic_components.dart';
import 'mechanic_reviews.dart';
import 'payment_components.dart';
import 'job_components.dart';
import '../garage/vehicle_image.dart';
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
                  const SizedBox(height: Mechi.gap),
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
                  const SizedBox(height: Mechi.gap),
                  ChipLabel(
                    job.status.label,
                    icon: complete ? LucideIcons.check : LucideIcons.wrench,
                  ),
                  const SizedBox(height: Mechi.gap),
                  Center(child: VehicleImage(job.request.vehicle, height: 100)),
                  const Divider(color: Mechi.line),
                  const SectionTitle('Service milestones'),
                  SettingsRow(
                    icon: job.progress >= 50
                        ? LucideIcons.check
                        : LucideIcons.locateFixed,
                    title: 'Inspection',
                    subtitle: job.progress >= 50 ? 'Complete' : 'In progress',
                  ),
                  SettingsRow(
                    icon: job.progress >= 80
                        ? LucideIcons.check
                        : LucideIcons.wrench,
                    title: 'Repair',
                    subtitle: job.progress >= 80
                        ? 'Work recorded'
                        : job.progress >= 50
                        ? 'In progress'
                        : 'Pending inspection',
                  ),
                  SettingsRow(
                    icon: LucideIcons.shieldCheck,
                    title: 'Customer review',
                    subtitle: complete
                        ? 'Ready for review'
                        : 'Pending completion',
                  ),
                  const Divider(color: Mechi.line),
                  InfoRow('Vehicle', job.request.vehicle.name),
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
            ...serviceCompletionSections(context, job, mechanic!),
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
              const CircleAvatar(
                radius: 46,
                backgroundColor: Mechi.pale,
                foregroundColor: Mechi.navy,
                child: Icon(LucideIcons.checkCircle2, size: 40),
              ),
              const SizedBox(height: 12),
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
                          const SizedBox(height: Mechi.gap),
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
              const SizedBox(height: Mechi.gap),
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
      builder: (_) => PaymentResultDialog(
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
          PaymentMethodPicker(
            method: method,
            onChanged: processing || submitting
                ? null
                : (value) {
                    setState(() => method = value);
                  },
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
                    ServiceReceipt(
                      job: job,
                      mechanicName: mechanic.name,
                      date: date,
                      printCount: printCount,
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
                      )
                    else if (job.status == JobStatus.reviewed)
                      const ChipLabel(
                        'Review submitted',
                        icon: LucideIcons.check,
                      ),
                    const SizedBox(height: Mechi.gap),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Mechi.ink,
                              foregroundColor: Mechi.white,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => setState(() => printCount++),
                            icon: const Icon(LucideIcons.printer, size: 16),
                            label: const Text('Print again'),
                          ),
                        ),
                        const SizedBox(width: Mechi.gap),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Mechi.white,
                              foregroundColor: Mechi.ink,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => backOrHome(context),
                            child: const Text('Done'),
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
  final feedback = <String>{};
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
    final available =
        job?.status == JobStatus.paid ||
        (submitting && job?.status == JobStatus.reviewed);
    final type = Theme.of(context).textTheme;
    return Screen(
      title: 'Rate mechanic',
      backgroundColor: Mechi.white,
      onBack: () => backOrHome(context),
      footer: available
          ? FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: rating == 0 || submitting
                  ? null
                  : () async {
                      setState(() => submitting = true);
                      final message = [
                        if (review.text.trim().isNotEmpty) review.text.trim(),
                        if (feedback.isNotEmpty) feedback.join(' · '),
                      ].join('\n\n');
                      try {
                        await controller.review(job!, rating, message);
                        if (context.mounted) backOrHome(context);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() => submitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Couldn’t save the review.'),
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit review'),
            )
          : null,
      children: [
        if (!available)
          const Panel(child: Text('Review unavailable or already submitted.'))
        else ...[
          Panel(
            color: Mechi.canvas,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MechanicIdentity(
                  ref.watch(mechanicsProvider).byId(job!.mechanicId!),
                ),
                const SizedBox(height: Mechi.gap),
                Text(
                  '${job.request.service.label} · Completed',
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          Text('How was your service?', style: type.headlineMedium),
          Text(
            'Choose a star rating and share your experience.',
            style: type.bodySmall,
          ),
          RatingPicker(
            rating: rating,
            onChanged: submitting
                ? null
                : (value) {
                    setState(() => rating = value);
                  },
          ),
          Text('What went well?', style: type.titleMedium),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in [
                'Arrived on time',
                'Professional',
                'Fair pricing',
                'Quality repair',
              ])
                FilterChip(
                  label: Text(tag),
                  backgroundColor: Mechi.canvas,
                  selectedColor: Mechi.pale,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  selected: feedback.contains(tag),
                  onSelected: submitting
                      ? null
                      : (selected) => setState(() {
                          if (selected) {
                            feedback.add(tag);
                          } else {
                            feedback.remove(tag);
                          }
                        }),
                ),
            ],
          ),
          Text('Your review', style: type.titleMedium),
          TextField(
            controller: review,
            enabled: !submitting,
            maxLength: 240,
            minLines: 4,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Review (optional)',
              fillColor: Mechi.canvas,
            ),
          ),
        ],
      ],
    );
  }
}
