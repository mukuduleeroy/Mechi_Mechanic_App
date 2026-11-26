import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

/// Height budgets for the dashboard, with minimums that allow text to wrap.
final class DashboardDimensions {
  DashboardDimensions(BoxConstraints bounds, EdgeInsets insets) {
    final usable = bounds.maxHeight - insets.vertical;
    final width = bounds.maxWidth - insets.horizontal;
    final darkHero = (width * .55).clamp(195.0, 232.0);
    // Share the available height between the content sections. These
    // targets are minimums so wrapped text can grow into the scroll view.
    final baseHero = math.max(171.0, darkHero + 38 - insets.top);
    final delta =
        (usable - navHeight - 2 * navGap - (baseHero + 204 + 138 + 94 + 74))
            .clamp(-56.0, 90.0);
    heroHeight = baseHero + delta * .32;
    infoHeight = (204 + delta * .34).clamp(184.0, 236.0);
    mapHeight = (138 + delta * .20).clamp(126.0, 156.0);
    quickHeight = (94 + delta * .14).clamp(88.0, 108.0);
  }

  static const navHeight = 55.0;
  static const navGap = 8.0;
  late final double heroHeight;
  late final double infoHeight;
  late final double mapHeight;
  late final double quickHeight;
}
