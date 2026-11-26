import 'package:material_ui/material_ui.dart';
import '../foundations/mechi.dart';

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label,
    this.onPressed, {
    super.key,
    this.secondary = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: secondary
          ? FilledButton.styleFrom(
              minimumSize: compact
                  ? const Size(0, Mechi.compactControlHeight)
                  : null,
              backgroundColor: Mechi.canvas,
              foregroundColor: Mechi.ink,
            )
          : null,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
