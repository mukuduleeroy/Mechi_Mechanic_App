import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/lucide_icons.dart';
import '../../core/design_system/mechi_ui.dart';
import '../garage/garage_state.dart';
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
          SegmentedButton<Service>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: Service.roadside,
                label: Text('Roadside'),
                icon: Icon(LucideIcons.alertTriangle, size: 17),
              ),
              ButtonSegment(
                value: Service.home,
                label: Text('Home service'),
                icon: Icon(LucideIcons.home, size: 17),
              ),
            ],
            selected: {service},
            onSelectionChanged: (value) => setState(() {
              service = value.first;
              problem = null;
            }),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(service),
            initialValue: problem,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Problem category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) => problem = value,
            validator: (value) =>
                value == null ? 'Select a problem category' : null,
          ),
          TextFormField(
            controller: details,
            decoration: const InputDecoration(
              labelText: 'Describe the issue (optional)',
            ),
            minLines: 2,
            maxLines: 4,
            maxLength: 240,
          ),
          DropdownButtonFormField<String>(
            initialValue: vehicleId ?? garage.selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vehicle'),
            items: [
              for (final vehicle in garage.vehicles)
                DropdownMenuItem(
                  value: vehicle.id,
                  child: Text('${vehicle.name} · ${vehicle.plate}'),
                ),
            ],
            onChanged: (value) => vehicleId = value,
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Service location'),
            items: [
              for (final place in locations)
                DropdownMenuItem(value: place, child: Text(place)),
            ],
            onChanged: (value) => location = value,
            validator: (value) =>
                value == null ? 'Select a service location' : null,
          ),
          const Panel(
            child: Text(
              'Device location is unavailable in this demo. Choose a Harare location to continue.',
            ),
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
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(jobsProvider);
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DemoMap(
            mechanics: mechanics,
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
                      IconButton.filled(
                        tooltip: 'Back',
                        onPressed: () => backOrHome(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Mechi.white,
                          foregroundColor: Mechi.ink,
                        ),
                        icon: const Icon(LucideIcons.arrowLeft, size: 19),
                      ),
                      const SizedBox(width: 8),
                      const ChipLabel(
                        'Nearby mechanics',
                        background: Mechi.white,
                        ink: Mechi.ink,
                      ),
                      const Spacer(),
                      IconButton.filled(
                        tooltip: 'Manage request',
                        style: IconButton.styleFrom(
                          backgroundColor: Mechi.white,
                          foregroundColor: Mechi.ink,
                        ),
                        onPressed: () => context.push('/job/${job.id}'),
                        icon: const Icon(LucideIcons.moreHorizontal, size: 19),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: zoom >= 1.5
                                ? null
                                : () => setState(() => zoom += .25),
                            icon: const Icon(LucideIcons.plus, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Zoom out',
                            onPressed: zoom <= 1
                                ? null
                                : () => setState(() => zoom -= .25),
                            icon: const Icon(LucideIcons.minus, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Recenter map',
                            onPressed: () => setState(() => zoom = 1),
                            icon: const Icon(LucideIcons.locateFixed, size: 18),
                          ),
                        ],
                      ),
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
                  height: 218,
                  child: PageView.builder(
                    controller: pages,
                    itemCount: mechanics.length,
                    onPageChanged: (index) => setState(() => selected = index),
                    itemBuilder: (context, index) {
                      final mechanic = mechanics[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MechanicIdentity(mechanic),
                              Wrap(
                                spacing: 7,
                                runSpacing: 4,
                                children: [
                                  ChipLabel(
                                    '${mechanic.rating}',
                                    icon: LucideIcons.star,
                                    ink: Mechi.star,
                                    background: Mechi.paper,
                                  ),
                                  ChipLabel(
                                    '${mechanic.distance} km · ${mechanic.eta} min',
                                  ),
                                  const ChipLabel(
                                    'Verified · Demo',
                                    icon: LucideIcons.badgeCheck,
                                  ),
                                  const ChipLabel(
                                    'Available',
                                    ink: Mechi.muted,
                                    background: Mechi.canvas,
                                  ),
                                ],
                              ),
                              ActionButton(
                                'View profile',
                                () => context.push(
                                  '/mechanic/${job.id}/${mechanic.id}',
                                ),
                              ),
                            ],
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

class MechanicIdentity extends StatelessWidget {
  const MechanicIdentity(this.mechanic, {super.key});
  final Mechanic mechanic;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Mechi.pale,
        foregroundColor: Mechi.blue,
        child: Text(mechanic.initials),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mechanic.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              mechanic.specialty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
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
    ref.watch(jobsProvider);
    final mechanics = ref.watch(mechanicsProvider);
    if (!mechanics.all.any((item) => item.id == widget.mechanicId)) {
      return Screen(
        title: 'Mechanic details',
        onBack: () => backOrHome(context),
        children: const [Text('Mechanic unavailable.')],
      );
    }
    final mechanic = mechanics.byId(widget.mechanicId);
    final job = ref.read(jobsProvider.notifier).find(widget.id);
    return Screen(
      title: 'Mechanic details',
      onBack: () => backOrHome(context),
      footer: Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usd(mechanic.callout),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Call-out fee'),
                ],
              ),
            ),
            Expanded(
              child: ActionButton(
                'Get quote',
                job?.status == JobStatus.searching
                    ? () {
                        ref.read(jobsProvider.notifier).quote(job!, mechanic);
                        context.pushReplacement('/job/${job.id}');
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Mechi.radius),
          child: SizedBox(
            height: 180,
            child: DemoMap(
              mechanics: [mechanic],
              selected: mechanic.id,
              location: mechanic.area,
            ),
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MechanicIdentity(mechanic),
              const SizedBox(height: 10),
              const ChipLabel('Verified · Demo', icon: LucideIcons.badgeCheck),
              InfoRow('Customer rating', '${mechanic.rating} / 5'),
              InfoRow('Estimated arrival', '${mechanic.eta} min'),
              InfoRow('Availability', 'Available · ${mechanic.area}'),
            ],
          ),
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Overview')),
            ButtonSegment(value: true, label: Text('Reviews')),
          ],
          selected: {reviews},
          onSelectionChanged: (value) => setState(() => reviews = value.first),
        ),
        if (reviews) ...[
          const Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ropa N. · 5 / 5'),
                Text(
                  'Explained the fault clearly and arrived within the estimate.',
                ),
              ],
            ),
          ),
          const Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kuda S. · 5 / 5'),
                Text('The final bill matched the quote.'),
              ],
            ),
          ),
        ] else
          Panel(
            child: Column(
              children: [
                InfoRow('Experience', '${mechanic.experience} years'),
                const InfoRow(
                  'Qualification',
                  'Motor vehicle trade certificate',
                ),
                InfoRow('Services', mechanic.specialty),
                const InfoRow('Profile', 'Fictional prototype mechanic'),
              ],
            ),
          ),
      ],
    );
  }
}
