import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import 'domain.dart';

class MechanicIdentity extends StatelessWidget {
  const MechanicIdentity(this.mechanic, {super.key});
  final Mechanic mechanic;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Mechi.pale,
        foregroundColor: Mechi.navy,
        child: Text(mechanic.initials),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mechanic.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              mechanic.specialty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Call-out estimate and the existing quote action. A null callback disables it.
class MechanicPricingBar extends StatelessWidget {
  const MechanicPricingBar({
    super.key,
    required this.callout,
    required this.onPressed,
  });

  final int callout;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usd(callout), style: type.titleLarge),
                Text('Call-out estimate', style: type.bodySmall),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            onPressed: onPressed,
            icon: const Icon(LucideIcons.navigation, size: 15),
            label: const Text('Get quote'),
          ),
        ],
      ),
    );
  }
}
