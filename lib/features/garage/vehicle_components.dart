import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../assistance/domain.dart';
import 'vehicle_image.dart';
import 'vehicle_colour.dart';

class RegisteredVehicleRow extends StatelessWidget {
  const RegisteredVehicleRow({
    super.key,
    required this.vehicle,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            selected: selected,
            child: InkWell(
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: VehicleImage(
                        vehicle,
                        height: 35,
                        placeholder: Center(
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Mechi.pale,
                            child: SvgPicture.asset(
                              MechiAssets.frontCar,
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                Mechi.navy,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Mechi.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicle.name, style: type.labelLarge),
                          Text(
                            '${vehicle.year} · ${vehicle.plate}',
                            style: type.bodySmall,
                          ),
                          const SizedBox(height: 3),
                          VehicleColourLabel(vehicle.colour),
                          if (selected) const ChipLabel('Current vehicle'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Edit ${vehicle.name}',
          onPressed: onEdit,
          icon: const Icon(LucideIcons.pencil, size: 17),
        ),
      ],
    );
  }
}
