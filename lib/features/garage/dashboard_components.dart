import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import '../assistance/domain.dart';
import '../assistance/demo_map.dart';
import 'vehicle_image.dart';

/// Labelled information tile in the home dashboard.
class DashboardMetric extends StatelessWidget {
  const DashboardMetric(this.icon, this.value, this.label, {super.key});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
}

/// Dashboard Quick Actions card, with the approved emphasized variant.
class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard(
    this.label,
    this.icon,
    this.action, {
    super.key,
    this.primary = false,
    required this.height,
  });
  final double height;
  final bool primary;
  final String label;
  final IconData icon;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Material(
    color: primary ? Mechi.navy : Mechi.white,
    borderRadius: BorderRadius.circular(Mechi.radius),
    child: InkWell(
      borderRadius: BorderRadius.circular(Mechi.radius),
      onTap: action,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                textAlign: TextAlign.center,
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

/// Live map preview with the dashboard's white gradient and primary action.
class DashboardMapCard extends StatelessWidget {
  const DashboardMapCard({
    super.key,
    required this.height,
    required this.mechanic,
    required this.title,
    required this.actionLabel,
    required this.onPressed,
  });

  final double height;
  final Mechanic? mechanic;
  final String title;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Mechi.radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: DemoMap(
              mechanics: [?mechanic],
              selected: mechanic?.id ?? 0,
              preview: true,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Mechi.white, Mechi.white, Color(0x00ffffff)],
                  stops: [0, .40, .75],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: .56,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 148),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: onPressed,
                      child: Text(actionLabel, textAlign: TextAlign.center),
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

/// Existing dashboard greeting, notifications and resolved vehicle render.
class VehicleHero extends StatelessWidget {
  const VehicleHero({
    super.key,
    required this.vehicle,
    required this.customer,
    required this.height,
    required this.hasActiveJob,
    required this.onNotifications,
  });

  final Vehicle? vehicle;
  final String customer;
  final double height;
  final bool hasActiveJob;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final vehicle = this.vehicle;
    final typography = Theme.of(context).textTheme;
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 38,
          child: ColoredBox(color: Mechi.hero),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MechiLogo(height: 18, symbolOnly: true),
                          const SizedBox(height: 4),
                          Text(
                            'Hello, $customer',
                            style: typography.headlineMedium?.copyWith(
                              color: Mechi.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            vehicle == null
                                ? 'No registered vehicle'
                                : '${vehicle.name} · ${vehicle.year}',
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
                          icon: const Icon(LucideIcons.bell, size: 19),
                          onPressed: onNotifications,
                        ),
                        if (hasActiveJob)
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
                if (vehicle != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: VehicleImage(
                      vehicle,
                      height: (height - 77).clamp(98.0, 150.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
