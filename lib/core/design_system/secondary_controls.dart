import 'package:material_ui/material_ui.dart';

import 'components/surfaces.dart';
import 'lucide_icons.dart';
import 'foundations/mechi.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class IconBubble extends StatelessWidget {
  const IconBubble(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 18,
    backgroundColor: Mechi.pale,
    foregroundColor: Mechi.navy,
    child: Icon(icon, size: 18),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              IconBubble(icon),
              const SizedBox(width: Mechi.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: type.labelLarge),
                    if (subtitle != null)
                      Text(subtitle!, style: type.bodySmall),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(
                  LucideIcons.chevronRight,
                  size: 17,
                  color: Mechi.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SegmentPicker<T> extends StatelessWidget {
  const SegmentPicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<({T value, String label, IconData? icon})> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(4),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final vertical =
            bounds.maxWidth < 380 &&
            MediaQuery.textScalerOf(context).scale(14) > 20 &&
            options.any((option) => option.icon != null);
        return Flex(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: vertical
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          spacing: 4,
          children: [
            for (final option in options)
              if (vertical)
                _button(option)
              else
                Expanded(child: _button(option)),
          ],
        );
      },
    ),
  );

  Widget _button(({T value, String label, IconData? icon}) option) {
    final selected = value == option.value;
    return Semantics(
      selected: selected,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          foregroundColor: selected ? Mechi.white : Mechi.muted,
          backgroundColor: selected ? Mechi.navy : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          if (!selected) onChanged(option.value);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: 17),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(option.label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class SelectionField<T> extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.title,
    required this.icon,
    required this.options,
    required this.labelFor,
    required this.onChanged,
    this.value,
    this.prompt,
    this.validator,
  });

  final String title;
  final IconData icon;
  final List<T> options;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;
  final T? value;
  final String? prompt;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => FormField<T>(
    initialValue: value,
    validator: validator,
    builder: (field) {
      final selected = field.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsRow(
            icon: icon,
            title: title,
            subtitle: selected != null ? labelFor(selected) : prompt,
            onTap: () async {
              FocusScope.of(context).unfocus();
              final next = await showModalBottomSheet<T>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (sheet) => SafeArea(
                  top: false,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(Mechi.pad),
                    children: [
                      SectionTitle(title),
                      const SizedBox(height: Mechi.gap),
                      for (final option in options)
                        SettingsRow(
                          icon: selected == option ? LucideIcons.check : icon,
                          title: labelFor(option),
                          onTap: () => Navigator.pop(sheet, option),
                        ),
                    ],
                  ),
                ),
              );
              if (next != null && field.mounted) {
                field.didChange(next);
                onChanged(next);
              }
            },
          ),
          if (field.errorText case final error?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(error, style: const TextStyle(color: Mechi.error)),
            ),
        ],
      );
    },
  );
}

class InformationNotice extends StatelessWidget {
  const InformationNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Panel(
    color: Mechi.pale,
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.alertCircle, size: 17, color: Mechi.navy),
        const SizedBox(width: Mechi.gap),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}
