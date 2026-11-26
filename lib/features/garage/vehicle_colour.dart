import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';

abstract final class VehicleColours {
  static const presets = {
    'White': Color(0xfff7f7f5),
    'Silver': Color(0xffb0b8c2),
    'Grey': Color(0xff727781),
    'Black': Color(0xff25262b),
    'Blue': Color(0xff245bac),
    'Red': Color(0xffa62032),
    'Green': Color(0xff326849),
    'Gold': Color(0xffb89a61),
    'Brown': Color(0xff78523c),
    'Orange': Color(0xffd76626),
    'Yellow': Color(0xffe2b923),
    'Purple': Color(0xff714e9f),
  };

  static Color? swatch(String? name) {
    final value = name?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('#') && value.length == 7) {
      final rgb = int.tryParse(value.substring(1), radix: 16);
      if (rgb != null) return Color(0xff000000 | rgb);
    }
    final words = value.split(RegExp(r'[^a-z]+'));
    if (words.any({'graphite', 'charcoal', 'gray'}.contains)) {
      return presets['Grey'];
    }
    if (words.any({'beige', 'champagne', 'bronze'}.contains)) {
      return presets['Gold'];
    }
    if (words.contains('navy')) return const Color(0xff243653);
    if (words.contains('maroon') || words.contains('burgundy')) {
      return const Color(0xff76283b);
    }
    for (final entry in presets.entries) {
      if (words.contains(entry.key.toLowerCase())) return entry.value;
    }
    return null;
  }
}

class VehicleColourLabel extends StatelessWidget {
  const VehicleColourLabel(this.colour, {super.key});
  final String? colour;

  @override
  Widget build(BuildContext context) {
    final name = colour?.trim();
    final swatch = VehicleColours.swatch(name);
    return Semantics(
      label: 'Paint colour: ${name == null || name.isEmpty ? 'not set' : name}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (swatch != null) ...[
              PaintSwatch(swatch),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                name == null || name.isEmpty ? 'Colour not set' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaintSwatch extends StatelessWidget {
  const PaintSwatch(this.colour, {super.key});
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: colour,
      shape: BoxShape.circle,
      border: Border.all(color: Mechi.muted.withValues(alpha: .45)),
    ),
  );
}
