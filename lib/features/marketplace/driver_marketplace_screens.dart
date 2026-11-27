import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../account/driver_data.dart';
import '../account/session.dart';
import '../assistance/domain.dart';
import '../mechanic/mechanic_data.dart';
import 'marketplace_data.dart';

class ConnectedRequestScreen extends ConsumerStatefulWidget {
  const ConnectedRequestScreen({super.key, required this.initial});
  final Service initial;

  @override
  ConsumerState<ConnectedRequestScreen> createState() =>
      _ConnectedRequestScreenState();
}

class _ConnectedRequestScreenState
    extends ConsumerState<ConnectedRequestScreen> {
  late Service service = widget.initial;
  final issue = TextEditingController();
  final address = TextEditingController(), duration = TextEditingController();
  final key = SubmissionKey();
  final form = GlobalKey<FormState>();
  String? selected, category;
  Json? location;
  List<Json>? windows;
  Json? selectedWindow;
  DateTime? appointmentDate;
  String get appointmentDay =>
      appointmentDate?.toIso8601String().split('T').first ?? '';

  Future<void> chooseAppointmentDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final existing = appointmentDate;
    final date = await showDatePicker(
      context: context,
      initialDate: existing != null && !existing.isBefore(today)
          ? existing
          : today,
      firstDate: today,
      lastDate: DateTime(9999, 12, 31),
    );
    if (date != null && mounted && date != appointmentDate) {
      setState(() {
        appointmentDate = date;
        windows = null;
        selectedWindow = null;
        availabilityQuery = null;
      });
    }
  }

  (String?, String, String, Json?)? availabilityQuery;

  (String?, String, String, Json?) get currentQuery =>
      (category, appointmentDay, duration.text.trim(), location);

  Future<void> findWindows() async {
    final query = currentQuery;
    final (categoryId, date, minutesText, fix) = query;
    final minutes = int.tryParse(minutesText);
    if (categoryId == null ||
        fix == null ||
        minutes == null ||
        minutes < 15 ||
        minutes > 480 ||
        !RegExp(r'^[1-9][0-9]{3}-[0-9]{2}-[0-9]{2}$').hasMatch(date) ||
        DateTime.tryParse(date)?.toIso8601String().split('T').first != date) {
      setState(
        () => error =
            'Enter the appointment date and duration, choose a category, and confirm the service location.',
      );
      return;
    }
    await run(() async {
      final result = await ref
          .read(marketplaceProvider)
          .post(
            'service-requests/schedule-options',
            body: {
              'categoryId': categoryId,
              'date': date,
              'durationMinutes': minutes,
              'latitude': fix['latitude'],
              'longitude': fix['longitude'],
            },
          );
      if (mounted && currentQuery == query && service == Service.home) {
        setState(() {
          availabilityQuery = query;
          windows = (result['windows'] as List).cast<Json>();
          selectedWindow = null;
        });
      }
    });
  }

  String windowLabel(Json window) {
    String utc(Object? instant) =>
        instant.toString().replaceFirst('T', ' ').substring(0, 16);
    return "${utc(window['startsAt'])} to ${utc(window['endsAt'])} UTC";
  }

  bool busy = false;
  String? error;

  @override
  void dispose() {
    issue.dispose();
    address.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = marketplaceError(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionProvider).account?.id;
    if (owner == null) return const SizedBox.shrink();
    final repository = ref.watch(marketplaceProvider);
    final driver = ref.watch(driverDataProvider(owner));
    final categories = ref.watch(categoriesProvider);
    final vehicles = driver.value?.vehicles ?? const <Vehicle>[];
    final options = (categories.value ?? const <ServiceCategory>[])
        .where(
          (item) =>
              item.id != null &&
              (service == Service.roadside ? item.immediate : item.scheduled),
        )
        .toList();
    final vehicle =
        vehicles.where((item) => item.id == selected).firstOrNull ??
        vehicles.firstOrNull;
    return Form(
      key: form,
      child: Screen(
        title: 'Request assistance',
        onBack: busy ? null : context.pop,
        footer: ActionButton(
          busy ? 'Please wait…' : 'Find mechanics',
          busy || vehicle == null || location == null
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  if (service == Service.home &&
                      (selectedWindow == null ||
                          availabilityQuery != currentQuery)) {
                    setState(
                      () => error =
                          'Check availability and select a current appointment window.',
                    );
                    return;
                  }
                  final payload = <String, dynamic>{
                    'vehicleId': vehicle.id,
                    'categoryId': category,
                    'serviceType': service == Service.home
                        ? 'HOME'
                        : 'ROADSIDE',
                    if (service == Service.home) ...{
                      'scheduledStart': selectedWindow!['startsAt'],
                      'durationMinutes': int.parse(duration.text.trim()),
                      'serviceAddress': address.text.trim(),
                    },
                    'issue': issue.text.trim(),
                    ...location!,
                    'confirmed': true,
                  };
                  run(() async {
                    final saved = await repository.post(
                      'service-requests',
                      body: payload,
                      key: key.forPayload(payload),
                    );
                    if (mounted) {
                      this.context.pushReplacement('/requests/${saved['id']}');
                    }
                  });
                },
        ),
        children: [
          const SectionTitle('What do you need?'),
          SegmentPicker<Service>(
            options: const [
              (
                value: Service.roadside,
                label: 'Roadside',
                icon: LucideIcons.alertTriangle,
              ),
              (
                value: Service.home,
                label: 'Home service',
                icon: LucideIcons.home,
              ),
            ],
            value: service,
            onChanged: (value) {
              if (!busy) {
                setState(() {
                  service = value;
                  category = null;
                });
              }
            },
          ),
          if (service == Service.home)
            Panel.grouped(
              child: Column(
                children: [
                  MechiFormField(
                    controller: address,
                    label: 'Service address',
                    maxLength: 300,
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Enter the service address'
                        : null,
                  ),
                  SettingsRow(
                    title: 'Appointment date',
                    icon: LucideIcons.clock,
                    subtitle: appointmentDate == null
                        ? 'Choose a date'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(appointmentDate!),
                    onTap: busy ? null : chooseAppointmentDate,
                  ),
                  MechiFormField(
                    controller: duration,
                    label: 'Service duration in minutes',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final minutes = int.tryParse(value?.trim() ?? '');
                      return minutes == null || minutes < 15 || minutes > 480
                          ? 'Enter 15 to 480 minutes'
                          : null;
                    },
                  ),
                ],
              ),
            ),

          if (error != null) InformationNotice(error!),
          if (driver.isLoading || categories.isLoading)
            const InformationNotice('Loading assistance options…'),
          if (driver.hasError || categories.hasError)
            ActionButton('Retry', () {
              ref.invalidate(driverDataProvider(owner));
              ref.invalidate(categoriesProvider);
            }),
          const SectionTitle('Service details'),
          Panel.grouped(
            child: Column(
              children: [
                SelectionField<ServiceCategory>(
                  key: ValueKey(service),
                  icon: LucideIcons.wrench,
                  title: 'Problem category',
                  options: options,
                  value: options
                      .where((item) => item.id == category)
                      .firstOrNull,
                  labelFor: (item) => item.name,
                  onChanged: (item) => category = item.id,
                  validator: (item) =>
                      item == null ? 'Select a problem category' : null,
                ),
                MechiFormField(
                  controller: issue,
                  label: 'Describe the issue',
                  maxLength: 240,
                  validator: (text) => text?.trim().isNotEmpty == true
                      ? null
                      : 'Describe the issue',
                ),
              ],
            ),
          ),
          const SectionTitle('Your vehicle'),
          Panel.grouped(
            child: SelectionField<Vehicle>(
              icon: LucideIcons.car,
              title: 'Vehicle',
              options: vehicles,
              value: vehicle,
              labelFor: (item) => '${item.name} · ${item.plate}',
              onChanged: (item) => selected = item.id,
            ),
          ),
          const SectionTitle('Location'),
          Panel.grouped(
            child: SettingsRow(
              title: location == null
                  ? 'Confirm current location'
                  : 'Current location confirmed',
              icon: LucideIcons.mapPin,
              onTap: busy
                  ? null
                  : () => run(() async {
                      final point = await ref
                          .read(mechanicDeviceProvider)
                          .position(requestPermission: true);
                      if (mounted) {
                        setState(
                          () => location = {
                            'longitude': point['longitude'],
                            'latitude': point['latitude'],
                            'observedAt': point['observedAt'],
                            'locationSource': 'GPS',
                          },
                        );
                      }
                    }),
            ),
          ),
          if (service == Service.home) ...[
            ActionButton(
              'Check appointment availability',
              busy ? null : findWindows,
              secondary: true,
            ),
            if (windows case final available?)
              if (available.isEmpty)
                const InformationNotice(
                  'No appointment windows found for this date. Try another date.',
                )
              else
                Panel.grouped(
                  child: SelectionField<Json>(
                    key: ObjectKey(available),
                    title: 'Appointment window',
                    icon: LucideIcons.clock,
                    options: available,
                    value: selectedWindow,
                    labelFor: windowLabel,
                    onChanged: (window) =>
                        setState(() => selectedWindow = window),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class DriverRequestProgress extends ConsumerStatefulWidget {
  const DriverRequestProgress({super.key, required this.id});
  final String id;
  @override
  ConsumerState<DriverRequestProgress> createState() =>
      _DriverRequestProgressState();
}

class _DriverRequestProgressState extends ConsumerState<DriverRequestProgress>
    with WidgetsBindingObserver, ForegroundPoll<DriverRequestProgress> {
  Json? request, selected;
  List<Json> offers = [];
  String? error;
  bool busy = false;

  @override
  String get marketplaceScope => widget.id;

  @override
  MarketplaceRepository get marketplaceConnection =>
      ref.read(marketplaceProvider);

  @override
  bool get keepPolling =>
      request == null || openRequestStatuses.contains(request!['status']);

  @override
  Future<void> poll() async {
    if (busy) return;
    final repository = ref.read(marketplaceProvider);
    final record = await repository.get<Json>('service-requests/${widget.id}');
    final quotes = await repository.get<List<dynamic>>(
      'service-requests/${widget.id}/quotations',
    );
    if (!mounted) return;
    setState(() {
      request = record;
      if (!openRequestStatuses.contains(record['status'])) selected = null;
      offers = quotes.cast<Json>();
      error = null;
    });
  }

  @override
  void pollError(Object failure) =>
      setState(() => error = marketplaceError(failure));

  Future<void> change(String path) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(marketplaceProvider).post(path);
      if (!mounted) return;
      setState(() {
        busy = false;
        selected = null;
      });
      await refresh();
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = marketplaceError(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(marketplaceProvider);
    final quote = selected;
    final jobId = request?['jobId'] as String?;
    final booking = request?['appointment'] as Json?;
    return Screen(
      title: quote == null ? 'Assistance request' : 'Quotation details',
      onBack: busy
          ? null
          : quote != null
          ? () => setState(() => selected = null)
          : context.pop,
      children: [
        if (error != null) ...[
          InformationNotice(error!),
          ActionButton('Refresh', refresh),
        ],
        if (quote != null) ...[
          quotePanel(quote),
          ActionButton(
            'Accept quotation',
            busy ||
                    !keepPolling ||
                    !offers.any(
                      (offer) =>
                          offer['id'] == quote['id'] &&
                          offer['status'] == 'PENDING',
                    )
                ? null
                : () async {
                    final confirmed = await confirmMarketplace(
                      context,
                      'Accept quotation?',
                      'Confirm this quotation to book the mechanic.',
                    );
                    if (mounted && confirmed) {
                      await change('quotations/${quote['id']}/accept');
                    }
                  },
          ),
        ] else ...[
          InformationNotice(
            request == null
                ? 'Loading request…'
                : statusLabel(request!['status']),
          ),
          if (booking != null && jobId == null) ...[
            Panel(
              child: Column(
                children: [
                  InfoRow('Appointment', booking['status'].toString()),
                  InfoRow('Starts', booking['startsAt'].toString()),
                  InfoRow('Ends', booking['endsAt'].toString()),
                ],
              ),
            ),
            ActionButton('View appointments', () => context.push('/history')),
          ],
          if (jobId != null)
            ActionButton(
              'View confirmed assignment',
              () => context.push('/assignments/$jobId'),
            ),
          if (request != null && keepPolling) ...[
            for (final offer in offers)
              Panel.grouped(
                child: SettingsRow(
                  title: (offer['mechanic'] as Json)['displayName'] as String,
                  subtitle: minorLabel(
                    offer['currency'],
                    offer['totalMinor'],
                    offer['minorDigits'],
                  ),
                  icon: LucideIcons.wrench,
                  onTap: () => setState(() => selected = offer),
                ),
              ),
            ActionButton(
              'Cancel request',
              busy
                  ? null
                  : () async {
                      final result = await confirmMarketplace(
                        context,
                        'Cancel request?',
                        'Outstanding invitations and quotations will close.',
                      );
                      if (mounted && result) {
                        await change('service-requests/${widget.id}/cancel');
                      }
                    },
              secondary: true,
            ),
          ],
          if (request != null &&
              !keepPolling &&
              jobId == null &&
              booking == null)
            ActionButton(
              'New request',
              () => context.pushReplacement('/request'),
            ),
        ],
      ],
    );
  }
}

Future<bool> confirmMarketplace(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: Mechi.scrim,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

Widget quotePanel(Json quote) {
  final mechanic = quote['mechanic'] as Json?;
  return Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mechanic != null) ...[
          SectionTitle(mechanic['displayName'] as String),
          if (mechanic['verificationStatus'] == 'APPROVED')
            const ChipLabel('Verified'),
          if (mechanic['experienceYears'] != null)
            InfoRow('Experience', "${mechanic['experienceYears']} years"),
        ],
        for (final item in (quote['items'] as List).cast<Json>())
          InfoRow(
            '${item['description']}${item['estimated'] == true ? ' (estimate)' : ''}',
            minorLabel(
              quote['currency'],
              item['amountMinor'],
              quote['minorDigits'],
            ),
          ),
        InfoRow(
          'Total',
          minorLabel(
            quote['currency'],
            quote['totalMinor'],
            quote['minorDigits'],
          ),
          bold: true,
        ),
        if (quote['notes'] != null) Text(quote['notes'] as String),
        if (quote['expiresAt'] != null)
          InfoRow(
            'Valid until',
            DateTime.parse(
              quote['expiresAt'] as String,
            ).toLocal().toString().split('.').first,
          ),
      ],
    ),
  );
}
