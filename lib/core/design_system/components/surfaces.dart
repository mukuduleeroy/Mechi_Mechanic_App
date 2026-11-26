import 'package:material_ui/material_ui.dart';
import '../foundations/mechi.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Mechi.white,
    this.padding = const EdgeInsets.all(Mechi.pad),
  });

  /// Compact grouped surface for settings, selectors and registered vehicles.
  const Panel.grouped({super.key, required this.child})
    : color = Mechi.white,
      padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4);

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(Mechi.radius),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: bold ? Mechi.ink : Mechi.muted),
          ),
        ),
        const SizedBox(width: Mechi.gap),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
