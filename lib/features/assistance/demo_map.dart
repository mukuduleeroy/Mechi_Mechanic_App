import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/design_system/lucide_icons.dart';
import '../../core/design_system/mechi_ui.dart';
import 'domain.dart';

class DemoMap extends StatelessWidget {
  const DemoMap({
    super.key,
    this.mechanics = const [],
    this.selected = 0,
    this.onSelect,
    this.movement,
    this.trackingFix,
    this.zoom = 1,
    this.preview = false,
    this.details = false,
    this.location = 'Harare',
  });
  final List<Mechanic> mechanics;
  final int selected;
  final ValueChanged<int>? onSelect;
  final double? movement;

  /// Projected GPS position in normalized map coordinates and clockwise
  /// heading in degrees from map north.
  final ({Offset position, double heading})? trackingFix;
  final double zoom;
  final bool preview;
  final bool details;
  final String location;
  static const origin = Offset(.30, .56);
  static const points = [
    Offset(.73, .29),
    Offset(.42, .28),
    Offset(.16, .35),
    Offset(.81, .51),
    Offset(.60, .63),
    Offset(.30, .72),
  ];

  static List<Offset> route(int index) {
    final target = points[index];
    return [origin, Offset(target.dx, origin.dy), target];
  }

  ({Offset position, double heading}) _routeFix(
    List<Offset> route,
    Size size,
    double progress,
  ) {
    final firstLeg = progress < .5;
    final start = firstLeg ? route.last : route[1];
    final end = firstLeg ? route[1] : route.first;
    final vector = end - start;
    final heading = math.atan2(
      vector.dx * size.width,
      -vector.dy * size.height,
    );
    return (
      position: Offset.lerp(
        start,
        end,
        firstLeg ? progress * 2 : progress * 2 - 1,
      )!,
      heading: heading * 180 / math.pi,
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Demonstration map of $location',
    child: ClipRect(
      child: ColoredBox(
        color: Mechi.grid,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final standardRoute = route(selected);
            final detailTarget = Offset(
              standardRoute.last.dx,
              math.max(.46, standardRoute.last.dy),
            );
            final routePoints = preview
                ? const [Offset(.64, .77), Offset(.87, .68), Offset(.87, .38)]
                : details
                ? [origin, Offset(detailTarget.dx, origin.dy), detailTarget]
                : standardRoute;
            final destination = routePoints.last;
            final selectedMechanic = mechanics
                .where((m) => m.id == selected)
                .firstOrNull;
            final List<Offset> projected = routePoints
                .map((p) => Offset(p.dx * size.width, p.dy * size.height))
                .toList();
            Widget marker(Offset p, Widget child) => Positioned(
              left: p.dx * size.width - 23,
              top: p.dy * size.height - 23,
              width: 46,
              height: 46,
              child: child,
            );
            return Transform.scale(
              scale: zoom,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(selected),
                    tween: Tween(begin: 0, end: 1),
                    duration: Mechi.animate(context),
                    builder: (_, value, _) =>
                        CustomPaint(painter: _StreetPainter(projected, value)),
                  ),
                  marker(
                    routePoints.first,
                    const _CarMarker(label: 'Your vehicle', heading: 90),
                  ),
                  if (trackingFix case final fix?)
                    TweenAnimationBuilder<Offset>(
                      tween: Tween(end: fix.position),
                      duration: Mechi.animate(context),
                      curve: Mechi.curve,
                      builder: (_, value, child) => marker(value, child!),
                      child: _CarMarker(
                        label: 'Mechanic vehicle',
                        heading: fix.heading,
                        tracking: true,
                      ),
                    )
                  else if (movement case final progress?)
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: progress.clamp(0.0, 1.0)),
                      duration: Mechi.animate(context),
                      curve: Mechi.curve,
                      builder: (_, value, _) {
                        final fix = _routeFix(routePoints, size, value);
                        return marker(
                          fix.position,
                          _CarMarker(
                            label: 'Mechanic vehicle',
                            heading: fix.heading,
                            tracking: true,
                          ),
                        );
                      },
                    )
                  else
                    for (final mechanic in mechanics)
                      marker(
                        preview || details ? destination : points[mechanic.id],
                        onSelect == null
                            ? _MapPin(selected: mechanic.id == selected)
                            : IconButton(
                                tooltip: mechanic.name,
                                onPressed: () => onSelect!(mechanic.id),
                                icon: _MapPin(
                                  selected: mechanic.id == selected,
                                ),
                              ),
                      ),
                  if (selectedMechanic != null &&
                      movement == null &&
                      trackingFix == null)
                    Positioned(
                      top: math.max(4, destination.dy * size.height - 48),
                      left: (destination.dx * size.width - 60).clamp(
                        0.0,
                        math.max(0, size.width - 120),
                      ),
                      width: 120,
                      child: IgnorePointer(
                        child: Center(
                          child: ChipLabel(
                            '${selectedMechanic.eta} min · ${selectedMechanic.distance} km',
                            background: preview ? Mechi.white : Mechi.ink,
                            ink: preview ? Mechi.ink : Mechi.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _CarMarker extends StatelessWidget {
  const _CarMarker({
    required this.label,
    required this.heading,
    this.tracking = false,
  });

  final String label;
  final double heading;
  final bool tracking;

  @override
  Widget build(BuildContext context) => Center(
    child: TweenAnimationBuilder<double>(
      tween: _HeadingTween(heading),
      duration: Mechi.animate(context),
      curve: Mechi.curve,
      builder: (_, angle, child) =>
          Transform.rotate(angle: angle * math.pi / 180, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tracking ? Mechi.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Image.asset(
          'assets/vehicles/map-car.png',
          height: 33,
          width: 21,
          fit: BoxFit.contain,
          semanticLabel: label,
          errorBuilder: (_, error, stack) =>
              const Icon(LucideIcons.car, color: Mechi.ink, size: 21),
        ),
      ),
    ),
  );
}

class _HeadingTween extends Tween<double> {
  _HeadingTween(double heading) : super(end: heading);

  @override
  double lerp(double t) {
    final delta = (end! - begin! + 180) % 360 - 180;
    return begin! + delta * t;
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Mechi.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Mechi.blue : Mechi.line,
          width: 1.5,
        ),
      ),
      child: Icon(
        LucideIcons.wrench,
        color: selected ? Mechi.ink : Mechi.muted,
        size: 15,
      ),
    ),
  );
}

class _StreetPainter extends CustomPainter {
  _StreetPainter(this.route, this.progress);
  final List<Offset> route;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    final road = Paint()
      ..color = Mechi.white
      ..strokeWidth = 4;
    for (var i = -2; i < 10; i++) {
      final x = i * size.width / 7;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * .16, size.height),
        road,
      );
    }
    for (var i = 0; i < 14; i++) {
      final y = i * size.height / 12;
      canvas.drawLine(
        Offset(0, y + size.width * .08),
        Offset(size.width, y - size.width * .08),
        road..strokeWidth = i % 3 == 0 ? 7 : 3,
      );
    }
    canvas.drawLine(
      Offset(0, size.height * .66),
      Offset(size.width, size.height * .87),
      road
        ..color = Mechi.arterial
        ..strokeWidth = 8,
    );
    final line = Path()..moveTo(route.first.dx, route.first.dy);
    for (final point in route.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final metric = line.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * math.max(.01, progress)),
      Paint()
        ..color = Mechi.blue
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StreetPainter oldDelegate) => true;
}
