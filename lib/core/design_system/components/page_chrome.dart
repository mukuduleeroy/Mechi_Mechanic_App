import 'package:material_ui/material_ui.dart';
import '../foundations/mechi.dart';
import '../lucide_icons.dart';

/// Centered title and optional back affordance used by standard pages.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Mechi.pad),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: [
          if (onBack != null)
            IconButton.filled(
              tooltip: 'Back',
              style: IconButton.styleFrom(
                backgroundColor: Mechi.white,
                foregroundColor: Mechi.ink,
                minimumSize: const Size.square(36),
              ),
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
  );
}

/// Bordered white surface for fixed page actions.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Mechi.line)),
      color: Mechi.white,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Mechi.pad,
        vertical: Mechi.gap,
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
