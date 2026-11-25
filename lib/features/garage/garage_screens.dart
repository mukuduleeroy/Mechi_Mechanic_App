import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/lucide_icons.dart';
import '../../core/design_system/mechi_ui.dart';
import '../../core/design_system/mechi_logo.dart';
import '../assistance/demo_map.dart';
import '../assistance/domain.dart';
import '../assistance/job_state.dart';
import '../assistance/repositories.dart';
import 'garage_state.dart';
import 'vehicle_image.dart';

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
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 72,
              child: ColoredBox(color: Mechi.hero),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 86),
                children: [
                  Stack(
                    children: [
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 46,
                        child: ColoredBox(color: Mechi.hero),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const MechiLogo(
                                        height: 22,
                                        symbolOnly: true,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Hello, ${garage.customer}',
                                        style: typography.headlineMedium
                                            ?.copyWith(color: Mechi.white),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${vehicle.name} · ${vehicle.year}',
                                        style: typography.bodySmall?.copyWith(
                                          color: Mechi.paper,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton.filled(
                                      tooltip: 'Notifications',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Mechi.ink,
                                        foregroundColor: Mechi.white,
                                      ),
                                      icon: const Icon(
                                        LucideIcons.bell,
                                        size: 19,
                                      ),
                                      onPressed: showStatus,
                                    ),
                                    if (active != null)
                                      const Positioned(
                                        top: 1,
                                        right: 1,
                                        child: IgnorePointer(
                                          child: CircleAvatar(
                                            radius: 9,
                                            backgroundColor: Mechi.error,
                                            child: Text(
                                              '1',
                                              style: TextStyle(
                                                color: Mechi.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: VehicleImage(vehicle, height: 140),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: Panel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your vehicle',
                                      style: typography.titleMedium,
                                    ),
                                    Text(
                                      'Registration',
                                      style: typography.bodySmall,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      vehicle.plate,
                                      style: typography.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () => context.push('/garage'),
                                      child: const Text('Manage vehicle'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 9,
                              child: Column(
                                children: [
                                  _dashboardMetric(
                                    LucideIcons.shieldCheck,
                                    active == null
                                        ? 'Ready to help'
                                        : 'Job active',
                                    'Assistance',
                                  ),
                                  const SizedBox(height: 8),
                                  _dashboardMetric(
                                    LucideIcons.clock,
                                    '${nearest.eta} min',
                                    'Nearest mechanic · Demo',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Mechi.radius),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DemoMap(
                                    mechanics: [nearest],
                                    selected: nearest.id,
                                    preview: true,
                                  ),
                                ),
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Mechi.white,
                                          Mechi.white,
                                          Color(0x00ffffff),
                                        ],
                                        stops: [0, .40, .75],
                                      ),
                                    ),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: .56,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          active?.status.label ??
                                              'Find closest mechanics',
                                          style: typography.titleMedium,
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                          ),
                                          onPressed: () =>
                                              request(Service.roadside),
                                          child: Text(
                                            active == null
                                                ? 'Request assistance'
                                                : 'Open current job',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Quick actions', style: typography.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (label, icon, action)
                                in <(String, IconData, VoidCallback)>[
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
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _ServiceTile(
                                    label,
                                    icon,
                                    action,
                                    primary: label == 'Breakdown',
                                  ),
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
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Mechi.ink,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (label, icon, route) in [
                        ('Home', LucideIcons.car, '/'),
                        ('Vehicles', LucideIcons.wrench, '/garage'),
                        ('Job history', LucideIcons.history, '/history'),
                        ('Profile', LucideIcons.user, '/profile'),
                      ])
                        IconButton(
                          tooltip: label,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(54, 46),
                          ),
                          isSelected: route == '/',
                          onPressed: () {
                            if (route != '/') context.push(route);
                          },
                          icon: route == '/'
                              ? SvgPicture.asset(
                                  'assets/icons/car-front.svg',
                                  width: 20,
                                  height: 20,
                                )
                              : Icon(
                                  icon,
                                  size: 20,
                                  color: Mechi.paper.withValues(alpha: .65),
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
    );
  }
}

Widget _dashboardMetric(IconData icon, String value, String label) => SizedBox(
  width: double.infinity,
  child: Panel(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Mechi.muted, fontSize: 11)),
      ],
    ),
  ),
);

void openJob(BuildContext context, Job job) => context.push(
  job.status == JobStatus.searching ? '/discover/${job.id}' : '/job/${job.id}',
);

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(
    this.label,
    this.icon,
    this.action, {
    this.primary = false,
  });
  final bool primary;
  final String label;
  final IconData icon;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Material(
    color: primary ? Mechi.blue : Mechi.white,
    borderRadius: BorderRadius.circular(Mechi.radius),
    child: InkWell(
      borderRadius: BorderRadius.circular(Mechi.radius),
      onTap: action,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: primary
                    ? Mechi.white.withValues(alpha: .20)
                    : Mechi.pale,
                child: Icon(
                  icon,
                  size: 17,
                  color: primary ? Mechi.white : Mechi.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Mechi.white : Mechi.ink,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  Future<void> edit(
    BuildContext context,
    WidgetRef ref, [
    Vehicle? initial,
  ]) async {
    final vehicle = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Mechi.scrim,
      builder: (_) => _VehicleForm(initial),
    );
    if (vehicle != null) {
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
        for (final vehicle in garage.vehicles)
          Panel(
            child: Row(
              children: [
                const Icon(LucideIcons.car, color: Mechi.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => ref
                        .read(garageProvider.notifier)
                        .save(selected: vehicle.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${vehicle.year} · ${vehicle.plate}'),
                        if (garage.selected == vehicle.id)
                          const ChipLabel('Current vehicle'),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit ${vehicle.name}',
                  onPressed: () => edit(context, ref, vehicle),
                  icon: const Icon(LucideIcons.pencil, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VehicleForm extends StatefulWidget {
  const _VehicleForm(this.vehicle);
  final Vehicle? vehicle;
  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final key = GlobalKey<FormState>();
  late final fields = [
    TextEditingController(text: widget.vehicle?.make),
    TextEditingController(text: widget.vehicle?.model),
    TextEditingController(text: widget.vehicle?.year.toString()),
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle',
                style: Theme.of(context).textTheme.titleLarge,
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
                  child: TextFormField(
                    controller: fields[index],
                    decoration: InputDecoration(labelText: label),
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
                        final year = int.tryParse(value);
                        if (year == null || year < 1900 || year > 2030) {
                          return 'Enter a valid year';
                        }
                      }
                      return null;
                    },
                  ),
                ),
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
                    int.parse(fields[2].text),
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
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('All')),
            ButtonSegment(value: 1, label: Text('Paid')),
            ButtonSegment(value: 2, label: Text('Other')),
          ],
          selected: {filter},
          onSelectionChanged: (v) => setState(() => filter = v.first),
        ),
        if (jobs.isEmpty)
          const Panel(child: Text('No jobs match this filter.')),
        for (final job in jobs)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.request.problem,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                InfoRow(
                  job.request.vehicle.name,
                  job.quote == null ? job.id : usd(job.quote!.total),
                ),
                ChipLabel(job.status.label),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => openJob(context, job),
                      child: const Text('Details'),
                    ),
                    if (job.status.settled)
                      TextButton(
                        onPressed: () => context.push('/receipt/${job.id}'),
                        child: const Text('Receipt'),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    final editor = ref.read(garageProvider.notifier);
    return Screen(
      title: 'Profile',
      onBack: context.pop,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                garage.customer,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Harare · Fictional demo account'),
              DropdownButton<String>(
                value: garage.customer,
                items: [
                  for (final name in ['Tadiwa M.', 'Ropa N.', 'Kuda S.'])
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (name) => editor.save(customer: name),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.car),
                title: const Text('Vehicles'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push('/garage'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.history),
                title: const Text('Job history'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push('/history'),
              ),
              SwitchListTile(
                title: const Text('Low-data mode'),
                subtitle: const Text(
                  'Demo maps and assets are available offline.',
                ),
                value: garage.lowData,
                onChanged: (value) => editor.save(lowData: value),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            children: [
              DropdownButtonFormField<PaymentMethod>(
                initialValue: garage.payment,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Preferred payment method',
                ),
                items: [
                  for (final method in PaymentMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                onChanged: (v) => editor.save(payment: v),
              ),
              TextFormField(
                initialValue: garage.emergency,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact',
                  helperText: 'Saved locally. Tap Done to save.',
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (v) => editor.save(emergency: v),
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

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext context) => Screen(
    title: 'Component gallery',
    onBack: context.pop,
    children: [
      ActionButton('Primary action', () {}),
      ActionButton('Secondary action', () {}, secondary: true),
      const ActionButton('Disabled', null),
      const Panel(
        child: Column(
          children: [
            ChipLabel('Verified · Demo', icon: LucideIcons.badgeCheck),
            InfoRow('Total', '\$36.00', bold: true),
            ProgressRing(.5, caption: 'Repair progress'),
          ],
        ),
      ),
    ],
  );
}
