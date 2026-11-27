import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../marketplace/marketplace_data.dart';
import 'execution_panel.dart' show operationalStatus;

class AppointmentPanel extends ConsumerStatefulWidget {
  const AppointmentPanel({
    super.key,
    required this.mechanic,
    required this.openJob,
  });
  final bool mechanic;
  final ValueChanged<String> openJob;

  @override
  ConsumerState<AppointmentPanel> createState() => _AppointmentPanelState();
}

class _AppointmentPanelState extends ConsumerState<AppointmentPanel>
    with WidgetsBindingObserver, ForegroundPoll<AppointmentPanel> {
  final from = TextEditingController(),
      until = TextEditingController(),
      zone = TextEditingController(),
      buffer = TextEditingController(text: '0'),
      reason = TextEditingController();
  List<Json> appointments = [], windows = [];
  String? error, cancelId;
  bool editor = false, busy = false;
  Timer? clock;

  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && appointments.any((item) => item['status'] == 'BOOKED')) {
        setState(() {});
      }
    });
  }

  bool activationOpened(Json item) =>
      !DateTime.now().isBefore(DateTime.parse(item['startsAt'] as String));

  bool activationEnded(Json item) =>
      !DateTime.now().isBefore(DateTime.parse(item['endsAt'] as String));

  String appointmentStatus(Json item) {
    if (item['job'] case final Json job) {
      return operationalStatus(job['status']);
    }
    if (item['status'] == 'CANCELLED') return 'Cancelled';
    return activationEnded(item) ? 'Activation window ended' : 'Booked';
  }

  @override
  void dispose() {
    clock?.cancel();
    for (final controller in [from, until, zone, buffer, reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Future<void> poll() async {
    final store = ref.read(marketplaceProvider);
    final rows = await store.get<List<dynamic>>('appointments');
    final shifts = widget.mechanic
        ? await store.get<List<dynamic>>('mechanics/me/schedule')
        : const [];
    if (mounted) {
      setState(() {
        appointments = rows.cast<Json>();
        windows = shifts.cast<Json>();
      });
    }
  }

  @override
  void pollError(Object failure) =>
      setState(() => error = marketplaceError(failure));

  Future<void> chooseWindowBoundary(TextEditingController controller) async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final stored = DateTime.tryParse(controller.text)?.toLocal();
    final initial = stored != null && !stored.isBefore(today) ? stored : now;
    final date = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initial),
      firstDate: today,
      lastDate: DateTime(9999, 12, 31),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    controller.text = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc().toIso8601String();
  }

  Future<void> change(Future<void> Function() call) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await call();
      if (mounted) {
        setState(() {
          editor = false;
          cancelId = null;
        });
        await refresh();
      }
    } catch (failure) {
      if (mounted) pollError(failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(marketplaceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Mechi.gap,
      children: [
        if (error != null) InformationNotice(error!),
        const SectionTitle('Appointments'),
        if (appointments.isEmpty)
          const InformationNotice('No scheduled appointments.'),
        for (final item in appointments)
          Panel(
            child: Column(
              children: [
                SectionTitle(
                  item['request']['serviceSnapshot']['name'] as String,
                ),
                InfoRow('Starts', item['startsAt'].toString()),
                InfoRow('Ends', item['endsAt'].toString()),
                ChipLabel(appointmentStatus(item)),
                if (item['status'] == 'BOOKED') ...[
                  if (widget.mechanic)
                    ActionButton(
                      activationEnded(item)
                          ? 'Request operational review'
                          : 'Activate appointment',
                      busy || !activationOpened(item)
                          ? null
                          : () => change(() async {
                              try {
                                final job = await store.post(
                                  "appointments/${item['id']}/activate",
                                );
                                if (mounted) {
                                  widget.openJob(job['id'] as String);
                                }
                              } catch (failure) {
                                final details = ApiFailure.of(failure);
                                if (details.status != 409) rethrow;
                                if (mounted) {
                                  setState(() => error = details.message);
                                }
                              }
                            }),
                    ),
                  ActionButton(
                    'Cancel appointment',
                    busy
                        ? null
                        : () => setState(() => cancelId = item['id'] as String),
                    secondary: true,
                  ),
                  if (cancelId == item['id']) ...[
                    MechiFormField(
                      controller: reason,
                      label: 'Cancellation reason',
                      maxLength: 500,
                    ),
                    ActionButton(
                      'Confirm cancellation',
                      busy
                          ? null
                          : () => change(() async {
                              if (reason.text.trim().isEmpty) {
                                throw const ApiFailure(
                                  400,
                                  null,
                                  null,
                                  'Enter the cancellation reason.',
                                );
                              }
                              await store.post(
                                "appointments/${item['id']}/cancel",
                                body: {'reason': reason.text.trim()},
                              );
                              reason.clear();
                            }),
                    ),
                  ],
                ],
                if (item['jobId'] case final String id)
                  ActionButton(
                    'Open appointment job',
                    () => widget.openJob(id),
                  ),
              ],
            ),
          ),
        if (widget.mechanic) ...[
          const SectionTitle('Working schedule'),
          for (final row in windows)
            Panel(
              child: Column(
                children: [
                  InfoRow('Starts', row['startsAt'].toString()),
                  InfoRow('Ends', row['endsAt'].toString()),
                  InfoRow('Time zone', row['zone'] as String),
                  ActionButton(
                    'Remove working window',
                    busy
                        ? null
                        : () => change(() async {
                            await store.api.request<void>(
                              'DELETE',
                              "mechanics/me/schedule/${row['id']}",
                              ownerUid: store.owner,
                              cancelToken: store.token,
                            );
                          }),
                    secondary: true,
                  ),
                ],
              ),
            ),
          if (!editor)
            ActionButton(
              'Add working window',
              () => setState(() => editor = true),
              secondary: true,
            ),
          if (editor)
            Panel(
              child: Column(
                children: [
                  SettingsRow(
                    title: 'Choose working start',
                    subtitle: 'Uses the device time zone',
                    icon: LucideIcons.clock,
                    onTap: busy ? null : () => chooseWindowBoundary(from),
                  ),
                  MechiFormField(
                    controller: from,
                    label: 'Start (ISO 8601 with time zone)',
                  ),
                  SettingsRow(
                    title: 'Choose working end',
                    icon: LucideIcons.clock,
                    onTap: busy ? null : () => chooseWindowBoundary(until),
                  ),
                  MechiFormField(
                    controller: until,
                    label: 'End (ISO 8601 with time zone)',
                  ),
                  MechiFormField(controller: zone, label: 'Region time zone'),
                  MechiFormField(
                    controller: buffer,
                    label: 'Travel buffer in minutes',
                    keyboardType: TextInputType.number,
                  ),
                  ActionButton(
                    'Save working window',
                    busy
                        ? null
                        : () => change(() async {
                            final minutes = int.tryParse(buffer.text.trim());
                            if (minutes == null ||
                                minutes < 0 ||
                                minutes > 120) {
                              throw const ApiFailure(
                                400,
                                null,
                                null,
                                'Enter a travel buffer from 0 to 120 minutes.',
                              );
                            }
                            await store.post(
                              'mechanics/me/schedule',
                              body: {
                                'startsAt': from.text.trim(),
                                'endsAt': until.text.trim(),
                                'zone': zone.text.trim(),
                                'bufferMinutes': minutes,
                              },
                            );
                          }),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
