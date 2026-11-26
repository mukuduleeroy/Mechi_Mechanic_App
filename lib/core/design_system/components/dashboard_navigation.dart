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
    required this.onDestination,
  });

  final double availableWidth;
  final ValueChanged<DashboardDestination> onDestination;

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
            for (final (label, icon, destination) in [
              ('Home', LucideIcons.car, null),
              ('Vehicles', LucideIcons.wrench, DashboardDestination.vehicles),
              (
                'Job history',
                LucideIcons.history,
                DashboardDestination.history,
              ),
              ('Profile', LucideIcons.user, DashboardDestination.profile),
            ])
              Expanded(
                child: IconButton(
                  tooltip: label,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(Mechi.controlHeight),
                  ),
                  isSelected: destination == null,
                  onPressed: () {
                    if (destination != null) onDestination(destination);
                  },
                  icon: destination == null
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
