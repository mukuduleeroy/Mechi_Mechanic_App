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
    this.zoom = 1,
    this.location = 'Harare',
  });
  final List<Mechanic> mechanics;
  final int selected;
  final ValueChanged<int>? onSelect;
  final double? movement;
  final double zoom;
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

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Demonstration map of $location',
    child: ClipRect(
      child: ColoredBox(
        color: Mechi.grid,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final routePoints = route(selected);
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
            final travel = movement ?? 0;
            final enRoute = travel < .5
                ? Offset.lerp(routePoints.last, routePoints[1], travel * 2)!
                : Offset.lerp(routePoints[1], origin, (travel - .5) * 2)!;
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
                    origin,
                    const _MapPin(icon: LucideIcons.car, color: Mechi.ink),
                  ),
                  if (movement != null)
                    TweenAnimationBuilder<Offset>(
                      tween: Tween(end: enRoute),
                      duration: Mechi.animate(context),
                      builder: (_, value, _) => marker(
                        value,
                        const _MapPin(
                          icon: LucideIcons.wrench,
                          color: Mechi.blue,
                        ),
                      ),
                    )
                  else
                    for (final mechanic in mechanics)
                      marker(
                        points[mechanic.id],
                        IconButton(
                          tooltip: mechanic.name,
                          onPressed: () => onSelect?.call(mechanic.id),
                          icon: _MapPin(
                            icon: LucideIcons.wrench,
                            color: mechanic.id == selected
                                ? Mechi.blue
                                : Mechi.muted,
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

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 33,
      height: 33,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Mechi.white, width: 2),
      ),
      child: Icon(icon, color: Mechi.white, size: 15),
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
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .23, size.width * .21, size.height * .25),
      Paint()..color = Mechi.park,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .75,
        size.height * .55,
        size.width * .25,
        size.height * .3,
      ),
      Paint()..color = Mechi.park,
    );
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
        Offset(0, y + 25),
        Offset(size.width, y - 25),
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
