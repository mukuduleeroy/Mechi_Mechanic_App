import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../assistance/demo_map.dart';

Offset? jobCoordinate(Object? input) {
  if (input is! Map) return null;
  final lat = input['latitude'], lng = input['longitude'];
  if (lat is! num ||
      lng is! num ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180) {
    return null;
  }
  return Offset(lng.toDouble(), lat.toDouble());
}

List<Offset> decodeJobRoute(Object? encoded) {
  if (encoded is! String || encoded.length > 100000) return const [];
  var index = 0;
  int readDelta() {
    var value = 0;
    for (var shift = 0; shift < 30; shift += 5) {
      if (index == encoded.length) throw const FormatException();
      final part = encoded.codeUnitAt(index++) - 63;
      if (part < 0 || part > 63) throw const FormatException();
      value |= (part & 31) << shift;
      if (part < 32) return value.isOdd ? ~(value >> 1) : value >> 1;
    }
    throw const FormatException();
  }

  var latitude = 0, longitude = 0;
  final points = <Offset>[];
  try {
    while (index < encoded.length) {
      latitude += readDelta();
      longitude += readDelta();
      if (latitude.abs() > 9000000 || longitude.abs() > 18000000) {
        return const [];
      }
      points.add(Offset(longitude / 1e5, latitude / 1e5));
    }
  } on FormatException {
    return const [];
  }
  return points.length < 2 ? const [] : points;
}

class JobTrackingMap extends StatefulWidget {
  const JobTrackingMap({
    super.key,
    required this.destination,
    this.fix,
    this.route,
  });
  final Offset destination;
  final Json? fix;
  final Json? route;

  @override
  State<JobTrackingMap> createState() => _JobTrackingMapState();
}

class _JobTrackingMapState extends State<JobTrackingMap> {
  final transform = TransformationController();

  void zoom(double factor) {
    final next = (transform.value.getMaxScaleOnAxis() * factor).clamp(1.0, 4.0);
    transform.value = Matrix4.identity()..scaleByDouble(next, next, 1, 1);
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = jobCoordinate(widget.fix);
    final route = widget.route?['status'] == 'AVAILABLE'
        ? decodeJobRoute(widget.route?['polyline'])
        : const <Offset>[];
    final centre = widget.destination;
    double wrap(double value) => (value + 180) % 360 - 180;
    final flatten = math.max(.01, math.cos(centre.dy * math.pi / 180));
    Offset relative(Offset p) =>
        Offset(wrap(p.dx - centre.dx) * flatten, centre.dy - p.dy);
    final fit = [
      Offset.zero,
      if (point != null) relative(point),
      ...route.map(relative),
    ];
    final left = fit.map((p) => p.dx).reduce(math.min);
    final right = fit.map((p) => p.dx).reduce(math.max);
    final top = fit.map((p) => p.dy).reduce(math.min);
    final bottom = fit.map((p) => p.dy).reduce(math.max);
    final middle = Offset((left + right) / 2, (top + bottom) / 2);
    final heading = widget.fix?['heading'];
    return Column(
      children: [
        InfoRow(
          'Map',
          widget.route?['provider'] == 'FIXTURE' && route.isNotEmpty
              ? 'Local schematic · synthetic test route'
              : 'Local schematic',
        ),
        AspectRatio(
          aspectRatio: 1.5,
          child: LayoutBuilder(
            builder: (_, constraints) {
              final width = constraints.maxWidth,
                  height = constraints.maxHeight;
              final scale =
                  .65 *
                  math.min(
                    width / math.max(.0001, right - left),
                    height / math.max(.0001, bottom - top),
                  );
              Offset project(Offset value) {
                final p = (relative(value) - middle) * scale;
                return Offset(.5 + p.dx / width, .5 + p.dy / height);
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    transformationController: transform,
                    maxScale: 4,
                    child: DemoMap(
                      jobOverlay: (
                        destination: project(centre),
                        route: route.map(project).toList(),
                      ),
                      trackingFix: point == null
                          ? null
                          : (
                              position: project(point),
                              heading: heading is num && heading.isFinite
                                  ? heading.toDouble()
                                  : 0,
                            ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: MapControls(
                      onZoomIn: () => zoom(1.25),
                      onZoomOut: () => zoom(.8),
                      onRecenter: () => transform.value = Matrix4.identity(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
