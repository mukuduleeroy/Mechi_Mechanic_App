import 'package:material_ui/material_ui.dart';
import '../foundations/mechi.dart';

class ChipLabel extends StatelessWidget {
  const ChipLabel(
    this.label, {
    super.key,
    this.icon,
    this.background = Mechi.pale,
    this.ink = Mechi.navy,
  });
  final String label;
  final IconData? icon;
  final Color background;
  final Color ink;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(Mechi.pillRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProgressRing extends StatelessWidget {
  const ProgressRing(this.progress, {super.key, required this.caption});
  final double progress;
  final String caption;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: progress),
    duration: Mechi.animate(context),
    curve: Mechi.curve,
    builder: (context, value, _) => Semantics(
      label: '${(value * 100).round()} percent, $caption',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 208,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 184,
                height: 184,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Mechi.white, Mechi.white, Mechi.pale],
                    stops: [0, .55, 1],
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 184,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Mechi.pale,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
