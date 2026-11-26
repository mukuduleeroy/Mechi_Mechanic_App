import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/design_system.dart';
import 'dashboard_components.dart';
import 'vehicle_components.dart';
import '../assistance/job_components.dart';
import '../assistance/domain.dart';
import '../assistance/job_state.dart';
import '../assistance/repositories.dart';
import 'garage_state.dart';
import 'profile_components.dart';
import 'vehicle_catalog.dart';
import 'vehicle_image.dart';
import 'vehicle_colour.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    final vehicle = garage.active;
    ref.watch(jobsProvider);
    final active = ref.read(jobsProvider.notifier).active;
    void request(Service service) => active == null
        ? context.push('/request?service=${service.name}')
        : openJob(context, active);
    final nearest = ref
        .watch(mechanicsProvider)
        .all
        .reduce(
          (first, second) => first.distance <= second.distance ? first : second,
        );
    final typography = Theme.of(context).textTheme;
    void showStatus() => showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          title: const Text('Notifications'),
          subtitle: Text(active?.status.label ?? 'You’re all caught up.'),
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, bounds) {
            final insets = MediaQuery.paddingOf(context);
            final dimensions = DashboardDimensions(bounds, insets);
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: insets.top,
                  child: const ColoredBox(color: Mechi.hero),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            VehicleHero(
                              vehicle: vehicle,
                              customer: garage.customer,
                              height: dimensions.heroHeight,
                              hasActiveJob: active != null,
                              onNotifications: showStatus,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: dimensions.infoHeight,
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 54,
                                            child: Panel(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Your vehicle',
                                                    style:
                                                        typography.titleMedium,
                                                  ),
                                                  Text(
                                                    'Registration',
                                                    style: typography.bodySmall,
                                                  ),
                                                  const SizedBox(
                                                    height: Mechi.gap,
                                                  ),
                                                  Text(
                                                    vehicle.plate,
                                                    style:
                                                        typography.titleLarge,
                                                  ),
                                                  const SizedBox(
                                                    height: Mechi.gap,
                                                  ),
                                                  VehicleColourLabel(
                                                    vehicle.colour,
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        context.push('/garage'),
                                                    child: const Text(
                                                      'Manage vehicle',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 46,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: DashboardMetric(
                                                    LucideIcons.shieldCheck,
                                                    active == null
                                                        ? 'Ready to help'
                                                        : 'Job active',
                                                    'Assistance',
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: DashboardMetric(
                                                    LucideIcons.clock,
                                                    '${nearest.eta} min',
                                                    'Nearest · Demo',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DashboardMapCard(
                                    height: dimensions.mapHeight,
                                    mechanic: nearest,
                                    title:
                                        active?.status.label ??
                                        'Find closest mechanics',
                                    actionLabel: active == null
                                        ? 'Request assistance'
                                        : 'Open current job',
                                    onPressed: () => request(Service.roadside),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Quick actions',
                                    style: typography.titleMedium,
                                  ),
                                  const SizedBox(height: Mechi.gap),
                                  IntrinsicHeight(
                                    child: Row(
                                      spacing: 6,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final (label, icon, action)
                                            in <
                                              (String, IconData, VoidCallback)
                                            >[
                                              (
                                                'Breakdown',
                                                LucideIcons.wrench,
                                                () => request(Service.roadside),
                                              ),
                                              (
                                                'Book service',
                                                LucideIcons.clock,
                                                () => request(Service.home),
                                              ),
                                              (
                                                'Track job',
                                                LucideIcons.navigation,
                                                () {
                                                  if (active != null) {
                                                    openJob(context, active);
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'No active job to track.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              (
                                                'History',
                                                LucideIcons.history,
                                                () => context.push('/history'),
                                              ),
                                            ])
                                          Expanded(
                                            child: DashboardActionCard(
                                              label,
                                              height: dimensions.quickHeight,
                                              icon,
                                              action,
                                              primary: label == 'Breakdown',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      DashboardNavigation(
                        availableWidth: bounds.maxWidth - insets.horizontal,
                        onDestination: (destination) =>
                            context.push(switch (destination) {
                              DashboardDestination.vehicles => '/garage',
                              DashboardDestination.history => '/history',
                              DashboardDestination.profile => '/profile',
                            }),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void openJob(BuildContext context, Job job) => context.push(
  job.status == JobStatus.searching ? '/discover/${job.id}' : '/job/${job.id}',
);

Future<VehicleRender?> _openVehicleCatalog(
  BuildContext context,
) => showModalBottomSheet<VehicleRender>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheet) => FractionallySizedBox(
    heightFactor: .75,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(Mechi.pad),
          child: Text('Choose a vehicle model'),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final render in VehicleCatalog.renders)
                ListTile(
                  leading: SizedBox(
                    width: 68,
                    child: VehicleImage(
                      Vehicle(
                        '',
                        render.make,
                        render.model,
                        render.sampleYear,
                        '',
                      ),
                      height: 35,
                    ),
                  ),
                  title: Text('${render.make} ${render.model}'),
                  subtitle: Text(
                    render.generation.isEmpty
                        ? '${render.sampleYear}'
                        : '${render.generation} · Example year ${render.sampleYear}',
                  ),
                  onTap: () => Navigator.pop(sheet, render),
                ),
            ],
          ),
        ),
      ],
    ),
  ),
);

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  Future<void> edit(
    BuildContext context,
    WidgetRef ref, {
    Vehicle? initial,
    VehicleRender? preset,
  }) async {
    final vehicle = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Mechi.scrim,
      builder: (_) => _VehicleForm(initial, preset),
    );
    if (vehicle != null && context.mounted) {
      await ref
          .read(garageProvider.notifier)
          .save(vehicle: vehicle, selected: vehicle.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    return Screen(
      title: 'Your vehicles',
      onBack: context.pop,
      footer: ActionButton('Add vehicle', () => edit(context, ref)),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My garage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${garage.vehicles.length} ${garage.vehicles.length == 1 ? 'vehicle' : 'vehicles'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Panel.grouped(
          child: SettingsRow(
            icon: LucideIcons.car,
            title: 'Browse catalog',
            onTap: () async {
              final preset = await _openVehicleCatalog(context);
              if (preset != null && context.mounted) {
                await edit(context, ref, preset: preset);
              }
            },
          ),
        ),
        const SectionTitle('Registered vehicles'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final (index, vehicle) in garage.vehicles.indexed) ...[
                if (index != 0) const Divider(height: 1, color: Mechi.line),
                RegisteredVehicleRow(
                  vehicle: vehicle,
                  selected: garage.selected == vehicle.id,
                  onSelect: () => ref
                      .read(garageProvider.notifier)
                      .save(selected: vehicle.id),
                  onEdit: () => edit(context, ref, initial: vehicle),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _modelName(VehicleRender render) => render.generation.isEmpty
    ? render.model
    : '${render.model} ${render.generation.split(' / ').first}';

class _VehicleForm extends StatefulWidget {
  const _VehicleForm(this.vehicle, this.preset);
  final Vehicle? vehicle;
  final VehicleRender? preset;
  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final key = GlobalKey<FormState>();
  late final fields = [
    TextEditingController(text: widget.vehicle?.make ?? widget.preset?.make),
    TextEditingController(
      text:
          widget.vehicle?.model ??
          (widget.preset == null ? null : _modelName(widget.preset!)),
    ),
    TextEditingController(
      text:
          widget.vehicle?.year.toString() ??
          widget.preset?.sampleYear.toString(),
    ),
    TextEditingController(text: widget.vehicle?.plate),
    TextEditingController(text: widget.vehicle?.colour),
  ];
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseModel() async {
    FocusScope.of(context).unfocus();
    final selected = await _openVehicleCatalog(context);
    if (!mounted || selected == null) return;
    final editYear = int.tryParse(fields[2].text.trim());
    fields[0].text = selected.make;
    fields[1].text = _modelName(selected);
    if (editYear == null ||
        editYear < selected.firstYear ||
        editYear > selected.lastYear) {
      fields[2].text = selected.sampleYear.toString();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Mechi.pad),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: _chooseModel,
                icon: const Icon(LucideIcons.car, size: 17),
                label: const Text('Choose a vehicle model'),
              ),
              for (final (index, label) in [
                'Make',
                'Model',
                'Year',
                'Registration',
                'Colour (optional)',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: MechiFormField(
                    controller: fields[index],
                    label: label,
                    hint: index == 4 ? 'e.g. Pearl white or #a62032' : null,
                    maxLength: 32,
                    keyboardType: index == 2
                        ? TextInputType.number
                        : TextInputType.text,
                    validator: (value) {
                      if (index == 4) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter ${label.toLowerCase()}';
                      }
                      if (index == 2) {
                        final year = int.tryParse(value.trim());
                        if (year == null || year < 1900 || year > 2030) {
                          return 'Enter a valid year';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: fields[4],
                builder: (context, value, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    children: [
                      for (final entry in VehicleColours.presets.entries)
                        ChoiceChip(
                          label: Text(entry.key),
                          avatar: PaintSwatch(entry.value),
                          showCheckmark: false,
                          selected:
                              value.text.trim().toLowerCase() ==
                              entry.key.toLowerCase(),
                          onSelected: (_) => fields[4].text = entry.key,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ActionButton('Save vehicle', () {
                if (!key.currentState!.validate()) return;
                final id =
                    widget.vehicle?.id ??
                    'vehicle-${DateTime.now().microsecondsSinceEpoch}';
                Navigator.pop(
                  context,
                  Vehicle(
                    id,
                    fields[0].text.trim(),
                    fields[1].text.trim(),
                    int.parse(fields[2].text.trim()),
                    fields[3].text.trim().toUpperCase(),
                    colour: fields[4].text.trim().isEmpty
                        ? null
                        : fields[4].text.trim(),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    ),
  );
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final jobs = ref
        .watch(jobsProvider)
        .where(
          (job) =>
              filter == 0 ||
              (filter == 1 && job.status.settled) ||
              (filter == 2 && !job.status.settled),
        )
        .toList();
    return Screen(
      title: 'Job history',
      onBack: context.pop,
      children: [
        SegmentPicker<int>(
          options: const [
            (value: 0, label: 'All', icon: null),
            (value: 1, label: 'Paid', icon: null),
            (value: 2, label: 'Other', icon: null),
          ],
          value: filter,
          onChanged: (value) => setState(() => filter = value),
        ),
        const SectionTitle('Past services'),
        if (jobs.isEmpty)
          const Panel(child: Text('No jobs match this filter.')),
        for (final job in jobs)
          JobHistoryCard(
            job: job,
            onDetails: () => openJob(context, job),
            onReceipt: () => context.push('/receipt/${job.id}'),
          ),
      ],
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final contact = TextEditingController(
    text: ref.read(garageProvider).emergency,
  );

  @override
  void dispose() {
    contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final garage = ref.watch(garageProvider);
    final editor = ref.read(garageProvider.notifier);
    return Screen(
      title: 'Profile',
      onBack: context.pop,
      footer: ActionButton('Done', () async {
        await editor.save(emergency: contact.text);
        if (context.mounted) context.pop();
      }),
      children: [
        ProfileHeader(
          name: garage.customer,
          subtitle: 'Harare · Fictional demo account',
        ),
        const SectionTitle('Account'),
        Panel.grouped(
          child: Column(
            children: [
              SelectionField<String>(
                icon: LucideIcons.user,
                title: 'Demo account',
                options: const ['Tadiwa M.', 'Ropa N.', 'Kuda S.'],
                value: garage.customer,
                labelFor: (name) => name,
                onChanged: (name) => editor.save(customer: name),
              ),
              const Divider(height: 1, color: Mechi.line),
              SettingsRow(
                icon: LucideIcons.car,
                title: 'Vehicles',
                subtitle: 'Manage your garage',
                onTap: () => context.push('/garage'),
              ),
              const Divider(height: 1, color: Mechi.line),
              SettingsRow(
                icon: LucideIcons.history,
                title: 'Job history',
                subtitle: 'View past services',
                onTap: () => context.push('/history'),
              ),
            ],
          ),
        ),
        const SectionTitle('Preferences'),
        Panel.grouped(
          child: Column(
            children: [
              SettingsRow(
                icon: LucideIcons.wifi,
                title: 'Low-data mode',
                subtitle: 'Offline demo maps and assets',
                trailing: Semantics(
                  label: 'Low-data mode',
                  child: Switch(
                    value: garage.lowData,
                    onChanged: (value) => editor.save(lowData: value),
                    activeThumbColor: Mechi.white,
                    activeTrackColor: Mechi.navy,
                    inactiveTrackColor: Mechi.canvas,
                  ),
                ),
              ),
              const Divider(height: 1, color: Mechi.line),
              SelectionField<PaymentMethod>(
                icon: LucideIcons.creditCard,
                title: 'Preferred payment method',
                options: PaymentMethod.values,
                value: garage.payment,
                labelFor: (method) => method.label,
                onChanged: (method) => editor.save(payment: method),
              ),
            ],
          ),
        ),
        const SectionTitle('Emergency contact'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: IconBubble(LucideIcons.phone),
              ),
              const SizedBox(width: Mechi.gap),
              Expanded(
                child: MechiFormField(
                  controller: contact,
                  keyboardType: TextInputType.phone,
                  maxLength: 30,
                  label: 'Contact phone number',
                  helper: 'Saved locally. Tap Done to save.',
                  helperMaxLines: 2,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) => editor.save(emergency: value),
                ),
              ),
            ],
          ),
        ),
        if (kDebugMode)
          Panel(
            child: Column(
              children: [
                const Text('Development'),
                ActionButton(
                  'Component gallery',
                  () => context.push('/gallery'),
                  secondary: true,
                ),
                ActionButton('Reset demo data', () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('Reset demo data?'),
                      content: const Text(
                        'This clears jobs, vehicle changes and preferences on this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  final prefs = ref.read(preferencesProvider);
                  await prefs.remove(LocalJobs.key);
                  await prefs.remove(LocalVehicles.key);
                  if (!context.mounted) return;
                  ref.invalidate(jobsProvider);
                  ref.invalidate(garageProvider);
                  context.go('/');
                }, secondary: true),
              ],
            ),
          ),
      ],
    );
  }
}
