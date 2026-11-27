import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../assets.dart';
import '../foundations/mechi.dart';
import '../layouts/dashboard_dimensions.dart';
import '../lucide_icons.dart';

enum DashboardDestination { vehicles, history, profile }

/// Floating dashboard pill with the home tab selected.
class DashboardNavigation extends StatelessWidget {
  const DashboardNavigation({
    super.key,
    required this.availableWidth,
    required ValueChanged<DashboardDestination> this.onDestination,
  }) : selectedIndex = 0,
       mechanicActions = null;

  const DashboardNavigation.mechanic({
    super.key,
    required this.availableWidth,
    required this.selectedIndex,
    required VoidCallback onHome,
    required VoidCallback onJobs,
    required VoidCallback onEarnings,
    required VoidCallback onProfile,
  }) : onDestination = null,
       mechanicActions = (onHome, onJobs, onEarnings, onProfile);

  final double availableWidth;
  final ValueChanged<DashboardDestination>? onDestination;
  final int selectedIndex;
  final (VoidCallback, VoidCallback, VoidCallback, VoidCallback)?
  mechanicActions;

  List<(String, IconData, VoidCallback?)> get items {
    if (mechanicActions case final actions?) {
      return [
        ('Home', LucideIcons.car, actions.$1),
        ('Jobs', LucideIcons.history, actions.$2),
        ('Earnings', LucideIcons.banknote, actions.$3),
        ('Profile', LucideIcons.user, actions.$4),
      ];
    }
    final navigate = onDestination!;
    return [
      ('Home', LucideIcons.car, null),
      (
        'Vehicles',
        LucideIcons.wrench,
        () => navigate(DashboardDestination.vehicles),
      ),
      (
        'Job history',
        LucideIcons.history,
        () => navigate(DashboardDestination.history),
      ),
      (
        'Profile',
        LucideIcons.user,
        () => navigate(DashboardDestination.profile),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DashboardDimensions.navGap),
    child: SizedBox(
      width: math.min(256, availableWidth),
      height: DashboardDimensions.navHeight,
      child: Material(
        color: Mechi.ink,
        borderRadius: BorderRadius.circular(Mechi.pillRadius),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final (index, (label, icon, action)) in items.indexed)
              Expanded(
                child: IconButton(
                  tooltip: label,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Mechi.controlHeight),
                  ),
                  isSelected: index == selectedIndex,
                  onPressed: () {
                    action?.call();
                  },
                  icon: index == 0
                      ? SvgPicture.asset(
                          MechiAssets.frontCar,
                          width: 20,
                          height: 20,
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color: Mechi.paper.withValues(alpha: .65),
                        ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
