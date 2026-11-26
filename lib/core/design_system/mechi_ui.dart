import 'package:material_ui/material_ui.dart';
import 'lucide_icons.dart';

abstract final class Mechi {
  static const canvas = Color(0xffececf4);
  static const white = Colors.white;
  static const ink = Color(0xff14141c);
  static const muted = Color(0xff616170);
  static const line = Color(0xffe5e5ec);
  static const pale = Color(0xffe7edf3);
  static const navy = Color(0xff113155);
  static const paper = Color(0xfffaf7fb);
  static const error = Color(0xffb73646);
  static const star = Color(0xff996019);
  static const scrim = Color(0x9914141c);
  static const hero = Color(0xff22232e);
  static const grid = Color(0xffdcdad6);
  static const park = Color(0xffd3e0cb);
  static const arterial = Color(0xfff4ddb0);
  static const gap = 8.0;
  static const pad = 16.0;
  static const radius = 20.0;
  static const sheetRadius = 28.0;
  static const motion = Duration(milliseconds: 300);
  static const printMotion = Duration(milliseconds: 900);
  static const curve = Curves.easeOutCubic;
  static const sans = 'Inter';
  static const mono = 'IBM Plex Mono';
  static Duration animate(BuildContext context, [Duration duration = motion]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: navy, surface: white).copyWith(
      primary: navy,
      onPrimary: white,
      primaryContainer: pale,
      onPrimaryContainer: navy,
      onSurface: ink,
      error: error,
    ),
    scaffoldBackgroundColor: canvas,
    fontFamily: sans,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.12,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 13, height: 1.35),
      bodySmall: TextStyle(fontSize: 11, color: muted),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ).apply(fontFamily: sans, bodyColor: ink, displayColor: ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Mechi.white,
    this.padding = const EdgeInsets.all(Mechi.pad),
  });
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

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label,
    this.onPressed, {
    super.key,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: secondary
          ? FilledButton.styleFrom(
              backgroundColor: Mechi.canvas,
              foregroundColor: Mechi.ink,
            )
          : null,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

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
      borderRadius: BorderRadius.circular(100),
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

class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.title,
    required this.children,
    this.footer,
    this.onBack,
    this.backgroundColor,
  });
  final String title;
  final List<Widget> children;
  final Widget? footer;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: backgroundColor,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Mechi.pad),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton.filledTonal(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(LucideIcons.arrowLeft, size: 19),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Mechi.pad,
                Mechi.gap,
                Mechi.pad,
                Mechi.pad,
              ),
              children: [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Mechi.pad,
                Mechi.gap,
                Mechi.pad,
                Mechi.gap,
              ),
              child: footer,
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
