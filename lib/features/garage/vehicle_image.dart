import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../assistance/domain.dart';

class VehicleImage extends StatelessWidget {
  const VehicleImage(this.vehicle, {super.key, this.height = 120});

  final Vehicle vehicle;
  final double height;

  static const _renders = [
    ('toyota', 'corolla', 2018, 'silver'),
    ('honda', 'fit', 2017, 'white'),
    ('ford', 'ranger', 2021, 'graphite'),
  ];

  static String? assetFor(Vehicle vehicle) {
    String normalize(String value) => value.trim().toLowerCase();
    final make = normalize(vehicle.make);
    final model = normalize(vehicle.model);
    final colour = normalize(vehicle.colour ?? '');
    final matches = _renders.where(
      (r) => r.$1 == make && r.$2 == model && r.$3 == vehicle.year,
    );
    for (final render in matches) {
      if (render.$4 == colour) return _path(render);
    }
    return matches.isEmpty ? null : _path(matches.first);
  }

  static String _path((String, String, int, String) render) =>
      'assets/vehicles/${render.$1}-${render.$2}-${render.$3}-${render.$4}.png';

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(vehicle);
    Widget fallback() => SvgPicture.asset(
      'assets/vehicles/silver.svg',
      height: height,
      semanticsLabel: 'Generic vehicle illustration',
    );
    if (asset == null) return fallback();

    // Image.asset reuses Flutter's decoded ImageCache. Limit decoded size to
    // the required screen density while keeping the full-resolution source.
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
      semanticLabel: '${vehicle.year} ${vehicle.name}',
      errorBuilder: (_, error, stack) => fallback(),
    );
  }
}
