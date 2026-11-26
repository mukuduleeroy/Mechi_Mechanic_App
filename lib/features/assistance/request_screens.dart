import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/design_system.dart';
import 'mechanic_components.dart';
import '../garage/garage_state.dart';
import '../garage/vehicle_image.dart';
import 'mechanic_reviews.dart';
import 'demo_map.dart';
import 'domain.dart';
import 'job_state.dart';

void backOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key, required this.initial});
  final Service initial;
  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final form = GlobalKey<FormState>();
  final details = TextEditingController();
  late Service service = widget.initial;
  String? problem, location, vehicleId;
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final garage = ref.watch(garageProvider);
    final locations = ref.watch(locationsProvider).locations;
    final categories = switch (service) {
      Service.roadside => [
        'Flat tyre',
        'Battery / starting',
        'Overheating',
        'Other',
      ],
      Service.home => [
        'Routine service',
        'Battery / starting',
        'Overheating',
        'Other',
      ],
    };
    return Form(
      key: form,
      child: Screen(
        title: 'Request assistance',
        onBack: () => backOrHome(context),
        footer: ActionButton('Find mechanics', () {
          if (!form.currentState!.validate()) return;
          final controller = ref.read(jobsProvider.notifier);
          if (controller.active != null) {
            context.pushReplacement('/job/${controller.active!.id}');
            return;
          }
          final vehicle = garage.vehicles.firstWhere(
            (item) => item.id == (vehicleId ?? garage.selected),
          );
          final job = controller.start(
            ServiceRequest(
              service,
              problem!,
              details.text.trim(),
              vehicle,
              location!,
            ),
          );
          context.pushReplacement('/discover/${job.id}');
        }),
        children: [
          Text(
            'What do you need?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            onChanged: (value) => setState(() {
              service = value;
              problem = null;
            }),
          ),
          const SectionTitle('Service details'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectionField<String>(
                  key: ValueKey(service),
                  icon: LucideIcons.wrench,
                  title: 'Problem category',
                  prompt: 'Select a category',
                  options: categories,
                  labelFor: (item) => item,
                  value: problem,
                  onChanged: (value) => problem = value,
                  validator: (value) =>
                      value == null ? 'Select a problem category' : null,
                ),
                const Divider(height: 12, color: Mechi.line),
                MechiFormField.description(
                  controller: details,
                  label: 'Describe the issue (optional)',
                ),
              ],
            ),
          ),
          const SectionTitle('Your vehicle'),
          Panel.grouped(
            child: SelectionField<Vehicle>(
              icon: LucideIcons.car,
              title: 'Vehicle',
              value: garage.vehicles.firstWhere(
                (item) => item.id == (vehicleId ?? garage.selected),
              ),
              options: garage.vehicles,
              labelFor: (item) => '${item.name} · ${item.plate}',
              onChanged: (item) => vehicleId = item.id,
            ),
          ),
          const SectionTitle('Location'),
          Panel.grouped(
            child: SelectionField<String>(
              icon: LucideIcons.mapPin,
              title: 'Service location',
              prompt: 'Choose a Harare location',
              options: locations,
              labelFor: (item) => item,
              value: location,
              onChanged: (value) => location = value,
              validator: (value) =>
                  value == null ? 'Select a service location' : null,
            ),
          ),
          const InformationNotice(
            'Device location is unavailable in this demo. Choose a Harare location to continue.',
          ),
        ],
      ),
    );
  }
}

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final pages = PageController(viewportFraction: .88);
  int selected = 0;
  double zoom = 1;
  bool selectedOnly = false;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider);
    final job = ref.read(jobsProvider.notifier).find(widget.id);
    final mechanics = ref.watch(mechanicsProvider).all;
    if (job == null) {
      return Screen(
        title: 'Nearby mechanics',
        onBack: () => backOrHome(context),
        children: const [Panel(child: Text('Request unavailable.'))],
      );
    }
    if (job.status != JobStatus.searching) {
      return Screen(
        title: 'Service request',
        onBack: () => backOrHome(context),
        children: [
          Panel(child: Text(job.status.label)),
          ActionButton(
            'Open job',
            () => context.pushReplacement('/job/${job.id}'),
          ),
        ],
      );
    }
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical;
    final textGrowth = MediaQuery.textScalerOf(context).scale(16) - 16;
    final cardHeight = (200 + textGrowth * 5).clamp(
      152.0,
      (available * .44).clamp(152.0, 310.0),
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DemoMap(
            mechanics: selectedOnly ? [mechanics[selected]] : mechanics,
            selected: selected,
            zoom: zoom,
            location: job.request.location,
            onSelect: (index) {
              setState(() => selected = index);
              if (Mechi.animate(context) == Duration.zero) {
                pages.jumpToPage(index);
              } else {
                pages.animateToPage(
                  index,
                  duration: Mechi.motion,
                  curve: Mechi.curve,
                );
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Mechi.white,
                            foregroundColor: Mechi.ink,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => backOrHome(context),
                          icon: const Icon(LucideIcons.arrowLeft, size: 16),
                          label: const Text(
                            'Nearby mechanics',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        tooltip: 'Map filters',
                        style: IconButton.styleFrom(
                          backgroundColor: Mechi.white,
                          foregroundColor: Mechi.ink,
                        ),
                        icon: const Icon(
                          LucideIcons.slidersHorizontal,
                          size: 19,
                        ),
                        onPressed: () async {
                          final value = await showModalBottomSheet<bool>(
                            context: context,
                            builder: (sheet) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    title: const Text('Show all mechanics'),
                                    onTap: () => Navigator.pop(sheet, false),
                                  ),
                                  ListTile(
                                    title: const Text(
                                      'Show selected mechanic only',
                                    ),
                                    onTap: () => Navigator.pop(sheet, true),
                                  ),
                                  ListTile(
                                    title: const Text('Manage request'),
                                    onTap: () {
                                      Navigator.pop(sheet);
                                      context.push('/job/${job.id}');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (mounted && value != null) {
                            setState(() => selectedOnly = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: MapControls(
                      onZoomIn: zoom >= 1.5
                          ? null
                          : () => setState(() => zoom += .25),
                      onZoomOut: zoom <= 1
                          ? null
                          : () => setState(() => zoom -= .25),
                      onRecenter: () => setState(() => zoom = 1),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ChipLabel(
                    job.request.location,
                    icon: LucideIcons.mapPin,
                    background: Mechi.ink,
                    ink: Mechi.white,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: cardHeight,
                  child: PageView.builder(
                    controller: pages,
                    itemCount: mechanics.length,
                    onPageChanged: (index) => setState(() => selected = index),
                    itemBuilder: (context, index) {
                      final mechanic = mechanics[index];
                      final average = reviewAverage(
                        reviewsFor(jobs, mechanic.id),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Panel(
                          child: LayoutBuilder(
                            builder: (context, bounds) => SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: bounds.maxHeight,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    MechanicIdentity(mechanic),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Verified mechanic · Available',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Mechi.navy),
                                    ),
                                    Text(
                                      '${average == null ? '' : '★ ${average.toStringAsFixed(1)} · '}${mechanic.eta} min · ${mechanic.distance} km',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const Divider(color: Mechi.line),
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.mapPin,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            mechanic.area,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Flexible(
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              shape: const StadiumBorder(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                            ),
                                            onPressed: () => context.push(
                                              '/mechanic/${job.id}/${mechanic.id}',
                                            ),
                                            child: const Text(
                                              'View profile',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MechanicScreen extends ConsumerStatefulWidget {
  const MechanicScreen({super.key, required this.id, required this.mechanicId});
  final String id;
  final int mechanicId;
  @override
  ConsumerState<MechanicScreen> createState() => _MechanicScreenState();
}

class _MechanicScreenState extends ConsumerState<MechanicScreen> {
  bool reviews = false;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider);
    final mechanics = ref.watch(mechanicsProvider);
    final preferences = ref.watch(preferencesProvider);
    final mechanic = mechanics.all
        .where((item) => item.id == widget.mechanicId)
        .firstOrNull;
    final job = ref.read(jobsProvider.notifier).find(widget.id);
    if (mechanic == null || job == null) {
      return Screen(
        title: 'Mechanic details',
        onBack: () => backOrHome(context),
        children: const [Text('Mechanic unavailable.')],
      );
    }
    final records = reviewsFor(jobs, mechanic.id);
    final average = reviewAverage(records);
    final favouriteKey = 'favourite-mechanic-${mechanic.id}';
    final favourite = preferences.getBool(favouriteKey) ?? false;
    final type = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Mechi.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Stack(
                    children: [
                      if (!reviews)
                        SizedBox(
                          height: 258,
                          child: DemoMap(
                            mechanics: [mechanic],
                            selected: mechanic.id,
                            details: true,
                            location: mechanic.area,
                          ),
                        )
                      else
                        const SizedBox(height: 82),
                      Padding(
                        padding: const EdgeInsets.all(Mechi.pad),
                        child: Row(
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Mechi.white,
                                foregroundColor: Mechi.ink,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                if (reviews) {
                                  setState(() => reviews = false);
                                } else {
                                  backOrHome(context);
                                }
                              },
                              icon: const Icon(LucideIcons.arrowLeft, size: 16),
                              label: const Text('Details'),
                            ),
                            const Spacer(),
                            IconButton.filled(
                              tooltip: favourite
                                  ? 'Remove favourite'
                                  : 'Add favourite',
                              style: IconButton.styleFrom(
                                backgroundColor: Mechi.white,
                                foregroundColor: favourite
                                    ? Mechi.navy
                                    : Mechi.ink,
                              ),
                              icon: const Icon(LucideIcons.heart, size: 19),
                              onPressed: () {
                                preferences.setBool(favouriteKey, !favourite);
                                setState(() {});
                              },
                            ),
                            IconButton.filled(
                              tooltip: 'More options',
                              style: IconButton.styleFrom(
                                backgroundColor: Mechi.white,
                                foregroundColor: Mechi.ink,
                              ),
                              icon: const Icon(
                                LucideIcons.moreHorizontal,
                                size: 19,
                              ),
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                builder: (sheet) => SafeArea(
                                  child: ListTile(
                                    title: Text(mechanic.name),
                                    subtitle: Text(
                                      '${mechanic.area} · Demo mechanic',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!reviews) ...[
                    Stack(
                      children: [
                        Positioned.fill(
                          bottom: 20,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Mechi.ink,
                              borderRadius: BorderRadius.circular(Mechi.radius),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const ChipLabel(
                                    'Verified · Demo',
                                    icon: LucideIcons.shieldCheck,
                                  ),
                                  const SizedBox(width: Mechi.gap),
                                  Expanded(
                                    child: Text(
                                      mechanic.name,
                                      style: type.titleMedium?.copyWith(
                                        color: Mechi.white,
                                      ),
                                    ),
                                  ),
                                  if (average != null)
                                    Text(
                                      '★ ${average.toStringAsFixed(1)}',
                                      style: type.bodySmall?.copyWith(
                                        color: Mechi.white,
                                      ),
                                    ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 5,
                                      children: [
                                        _mechanicFact(
                                          context,
                                          '${mechanic.distance} km',
                                          'Distance',
                                        ),
                                        _mechanicFact(
                                          context,
                                          '${mechanic.eta} min',
                                          'Arrival time',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Flexible(child: SizedBox(height: 100)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                            height: 24,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Mechi.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 6,
                          width: MediaQuery.sizeOf(context).width * .45,
                          child: VehicleImage(job.request.vehicle, height: 100),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overview', style: type.titleLarge),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, size: 22),
                              const SizedBox(width: Mechi.gap),
                              Expanded(
                                child: Text(
                                  mechanic.area,
                                  style: type.titleMedium,
                                ),
                              ),
                              const ChipLabel('Available'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (icon, value, label) in [
                                (
                                  LucideIcons.shieldCheck,
                                  'Verified',
                                  'Mechanic',
                                ),
                                (
                                  LucideIcons.clock,
                                  '${mechanic.eta} min',
                                  'Arrival',
                                ),
                                (
                                  LucideIcons.wrench,
                                  '${mechanic.experience} years',
                                  'Experience',
                                ),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: Panel(
                                      color: Mechi.canvas,
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(icon, size: 17),
                                          const SizedBox(height: 6),
                                          Text(value, style: type.labelLarge),
                                          Text(label, style: type.bodySmall),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Services', style: type.titleMedium),
                          const SizedBox(height: 6),
                          ChipLabel(
                            mechanic.specialty,
                            background: Mechi.canvas,
                            ink: Mechi.ink,
                          ),
                          const SizedBox(height: Mechi.gap),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Reviews', style: type.titleMedium),
                              ),
                              TextButton(
                                onPressed: () => setState(() => reviews = true),
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                          const InfoRow(
                            'Demo qualification',
                            'Motor vehicle trade certificate',
                          ),
                        ],
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.all(Mechi.pad),
                      child: MechanicReviews(
                        specialty: mechanic.specialty,
                        records: records,
                        now: ref.watch(demoClockProvider),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Mechi.line),
            MechanicPricingBar(
              callout: mechanic.callout,
              onPressed: job.status == JobStatus.searching
                  ? () {
                      ref.read(jobsProvider.notifier).quote(job, mechanic);
                      context.pushReplacement('/job/${job.id}');
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mechanicFact(BuildContext context, String value, String label) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Mechi.white),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Mechi.paper),
          ),
        ],
      );
}
