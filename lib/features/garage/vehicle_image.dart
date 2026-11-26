import 'package:material_ui/material_ui.dart';
import '../assistance/domain.dart';
import 'vehicle_catalog.dart';

class VehicleImage extends StatelessWidget {
  const VehicleImage(
    this.vehicle, {
    super.key,
    this.height = 120,
    this.placeholder,
  });

  final Vehicle vehicle;
  final double height;
  final Widget? placeholder;

  static String? assetFor(Vehicle vehicle) {
    final render = VehicleCatalog.resolve(vehicle);
    return render == null ? null : VehicleCatalog.assetPath(render);
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(vehicle);
    Widget fallback() =>
        placeholder ??
        SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Vehicle image unavailable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
