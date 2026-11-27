import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../job_execution/execution_panel.dart';
import '../job_execution/appointment_panel.dart';
import 'driver_marketplace_screens.dart';
import 'marketplace_data.dart';

class MarketplaceAssignments extends ConsumerStatefulWidget {
  const MarketplaceAssignments({super.key, this.mechanic = false, this.id});
  final bool mechanic;
  final String? id;

  @override
  ConsumerState<MarketplaceAssignments> createState() =>
      _MarketplaceAssignmentsState();
}

class _MarketplaceAssignmentsState extends ConsumerState<MarketplaceAssignments>
    with WidgetsBindingObserver, ForegroundPoll<MarketplaceAssignments> {
  Json? detail;
  List<Json>? jobs, requests;
  String? error;
  late String? active = widget.mechanic ? widget.id : null;
  String? get selectedJob => widget.mechanic ? active : widget.id;

  @override
  bool get keepPolling => selectedJob == null || detail == null;

  @override
  Future<void> poll() async {
    final repository = ref.read(marketplaceProvider);
    final query = {'role': widget.mechanic ? 'MECHANIC' : 'DRIVER'};
    final id = selectedJob;
    if (id != null) {
      final result = await repository.get<Json>('jobs/$id', query: query);
      if (mounted && id == selectedJob) {
        setState(() {
          detail = result;
          error = null;
        });
      }
    } else {
      final rows = await repository.get<List<dynamic>>('jobs', query: query);
      final pending = widget.mechanic
          ? const []
          : await repository.get<List<dynamic>>('service-requests');
      if (mounted) {
        setState(() {
          jobs = rows.cast<Json>();
          requests = pending.cast<Json>();
          error = null;
        });
      }
    }
  }

  @override
  void pollError(Object failure) =>
      setState(() => error = marketplaceError(failure));

  @override
  Widget build(BuildContext context) {
    ref.watch(marketplaceProvider);
    final record = detail;
    final content = <Widget>[
      if (error != null) ...[
        InformationNotice(error!),
        ActionButton('Refresh', refresh),
      ],
      if (record != null) ...[
        ChipLabel(operationalStatus(record['status'])),
        Panel(
          child: Column(
            children: [
              InfoRow('Job reference', record['id'] as String),
              InfoRow('Mechanic', record['mechanic']['displayName'] as String),
              InfoRow(
                'Vehicle',
                "${record['vehicleSnapshot']['make']} ${record['vehicleSnapshot']['model']}",
              ),
              InfoRow('Service', record['serviceSnapshot']['name'] as String),
              InfoRow(
                'Service area',
                record['serviceSnapshot']['area'] as String,
              ),
              if (record['interventionRequired'] == true)
                const InformationNotice(
                  'This assignment requires operational review.',
                ),
            ],
          ),
        ),
        quotePanel(record['priceSnapshot'] as Json),
        JobExecutionPanel(
          key: ValueKey(record['id']),
          id: record['id'] as String,
          mechanic: widget.mechanic,
          job: record,
          refreshJob: poll,
        ),
      ] else if (selectedJob != null) ...[
        const InformationNotice('Loading assignment…'),
      ] else ...[
        if (jobs == null) const InformationNotice('Loading assignments…'),
        if (jobs?.isEmpty == true)
          const InformationNotice('No confirmed assignments.'),
        for (final job in jobs ?? const <Json>[])
          Panel.grouped(
            child: SettingsRow(
              title: job['serviceSnapshot']['name'] as String,
              subtitle: operationalStatus(job['status']),
              icon: LucideIcons.wrench,
              onTap: widget.mechanic
                  ? () {
                      setState(() => active = job['id'] as String);
                      refresh();
                    }
                  : () => context.push('/assignments/${job['id']}'),
            ),
          ),
        AppointmentPanel(
          mechanic: widget.mechanic,
          openJob: (id) {
            if (widget.mechanic) {
              setState(() => active = id);
              refresh();
            } else {
              context.push('/assignments/$id');
            }
          },
        ),
        for (final request in requests ?? const <Json>[])
          if (request['status'] != 'ASSIGNED')
            Panel.grouped(
              child: SettingsRow(
                title: request['serviceSnapshot']['name'] as String,
                subtitle: statusLabel(request['status']),
                icon: LucideIcons.history,
                onTap: () => context.push('/requests/${request['id']}'),
              ),
            ),
      ],
    ];
    if (!widget.mechanic) {
      return Screen(
        title: widget.id == null ? 'Job history' : 'Confirmed assignment',
        onBack: context.pop,
        children: content,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Mechi.gap,
      children: [
        if (active != null)
          ActionButton('Back to jobs', () {
            setState(() {
              active = null;
              detail = null;
            });
            refresh();
          }, secondary: true),
        ...content,
      ],
    );
  }
}
