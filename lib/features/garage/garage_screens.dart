import 'package:flutter/foundation.dart';
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
              children: [
                Panel(
                  color: Mechi.hero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            child: MechiLogo(height: 18, symbolOnly: true),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Mechi',
                            style: TextStyle(
                              color: Mechi.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          const ChipLabel(
                            'Harare · Demo',
                            icon: LucideIcons.mapPin,
                            background: Mechi.ink,
                            ink: Mechi.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Hello, ${garage.customer}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Mechi.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle.name} · ${vehicle.year}',
                        style: const TextStyle(
                          color: Mechi.paper,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: VehicleImage(vehicle),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.car,
                              size: 18,
                              color: Mechi.blue,
                            ),
                            const SizedBox(height: 8),
                            const Text('Your vehicle'),
                            Text(
                              vehicle.plate,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.activity,
                              size: 18,
                              color: Mechi.blue,
                            ),
                            const SizedBox(height: 8),
                            const Text('Assistance'),
                            Text(
                              active == null ? 'Ready to help' : 'Job active',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active == null
                                    ? 'Find a nearby\nmechanic'
                                    : active.status.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ActionButton(
                                active == null
                                    ? 'Request assistance'
                                    : 'Open current job',
                                () => request(Service.roadside),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(Mechi.radius),
                          ),
                          child: SizedBox(height: 112, child: DemoMap()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Service options',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ServiceTile(
                        'Roadside breakdown',
                        LucideIcons.alertTriangle,
                        () => request(Service.roadside),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ServiceTile(
                        'Home service',
                        LucideIcons.home,
                        () => request(Service.home),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Mechi.ink,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (label, icon, route) in [
                        ('Home', LucideIcons.home, '/'),
                        ('Vehicles', LucideIcons.car, '/garage'),
                        ('Job history', LucideIcons.history, '/history'),
                        ('Profile', LucideIcons.user, '/profile'),
                      ])
                        IconButton(
                          tooltip: label,
                          onPressed: route == '/'
                              ? () {}
                              : () => context.push(route),
                          icon: Icon(
                            icon,
                            size: 20,
                            color: route == '/'
                                ? Mechi.white
                                : Mechi.paper.withValues(alpha: .65),
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

void openJob(BuildContext context, Job job) => context.push(
  job.status == JobStatus.searching ? '/discover/${job.id}' : '/job/${job.id}',
);

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.label, this.icon, this.action);
  final String label;
  final IconData icon;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Material(
    color: Mechi.white,
    borderRadius: BorderRadius.circular(Mechi.radius),
    child: InkWell(
      borderRadius: BorderRadius.circular(Mechi.radius),
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Mechi.blue),
            const SizedBox(height: 6),
            Text(label),
          ],
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
