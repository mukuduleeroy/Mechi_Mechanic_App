import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import 'domain.dart';
import 'mechanic_components.dart';
import 'payment_components.dart';

class JobHistoryCard extends StatelessWidget {
  const JobHistoryCard({
    super.key,
    required this.job,
    required this.onDetails,
    required this.onReceipt,
  });
  final Job job;
  final VoidCallback onDetails;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final icon = switch (job.request.problem) {
      'Battery / starting' => LucideIcons.batteryCharging,
      'Overheating' => LucideIcons.thermometer,
      'Flat tyre' => LucideIcons.car,
      _ => LucideIcons.wrench,
    };
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(icon),
              const SizedBox(width: Mechi.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.request.problem, style: type.labelLarge),
                    Text(job.request.vehicle.name, style: type.bodySmall),
                    const SizedBox(height: 4),
                    ChipLabel(
                      job.status.label,
                      icon: job.status.settled ? LucideIcons.check : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Mechi.gap),
              Text(
                job.quote == null ? job.id : usd(job.quote!.total),
                textAlign: TextAlign.end,
                style: type.labelLarge,
              ),
            ],
          ),
          const Divider(height: 12, color: Mechi.line),
          Row(
            spacing: Mechi.gap,
            children: [
              Expanded(
                child: ActionButton(
                  'Details',
                  onDetails,
                  secondary: true,
                  compact: true,
                ),
              ),
              if (job.status.settled)
                Expanded(
                  child: ActionButton(
                    'Receipt',
                    onReceipt,
                    secondary: true,
                    compact: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

List<Widget> serviceCompletionSections(
  BuildContext context,
  Job job,
  Mechanic mechanic,
) => [
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
