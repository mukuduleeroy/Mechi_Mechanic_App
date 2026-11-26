import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';

/// Customer identity surface, with initials derived from the supplied name.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Panel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Mechi.pale,
            foregroundColor: Mechi.navy,
            child: Text(
              initials,
              style: type.titleMedium?.copyWith(color: Mechi.navy),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: type.titleLarge),
                Text(subtitle, style: type.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
