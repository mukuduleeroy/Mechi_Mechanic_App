import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import '../garage/profile_components.dart';
import 'backend.dart';
import 'driver_data.dart';
import 'session.dart';

class ConnectedProfile extends ConsumerWidget {
  const ConnectedProfile({super.key, this.onboarding = false});
  final bool onboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final account = session.account;
    if (account == null) return const SizedBox.shrink();
    final provider = driverDataProvider(account.id);
    final result = ref.watch(provider);
    final data = result.value;
    final controller = ref.read(sessionProvider.notifier);
    return Screen(
      title: onboarding ? 'Complete your profile' : 'Profile',
      onBack: onboarding ? null : context.pop,
      children: [
        if (result.hasError)
          InformationNotice(
            data == null
                ? 'Could not load your profile.'
                : 'Showing previously loaded data.',
          ),
        if (result.hasError)
          ActionButton('Retry', () => ref.invalidate(provider)),
        if (data == null && result.isLoading)
          const InformationNotice('Loading your profile…'),
        if (data != null) ...[
          ProfileHeader(
            name: data.profile.name,
            subtitle: data.profile.region ?? 'Driver',
          ),
          const SectionTitle('Account'),
          Panel.grouped(
            child: Column(
              children: [
                if (account.email != null)
                  InfoRow('Verified email', account.email!),
                if (account.phone != null)
                  InfoRow('Verified phone', account.phone!),
                SettingsRow(
                  title: 'Edit personal details',
                  icon: LucideIcons.user,
                  onTap: () => _showProfile(
                    context,
                    ref,
                    data.profile,
                    account.id,
                    onboarding,
                  ),
                ),
                if (!onboarding)
                  SettingsRow(
                    title: 'Vehicles',
                    icon: LucideIcons.car,
                    subtitle: 'Manage your garage',
                    onTap: () => context.push('/garage'),
                  ),
              ],
            ),
          ),
          if (!onboarding) ...[
            const SectionTitle('Preferences'),
            Panel.grouped(
              child: InfoRow(
                'Preferred contact',
                data.profile.contactPreference ?? 'Any verified contact',
              ),
            ),
            const SectionTitle('Emergency contacts'),
            Panel.grouped(
              child: Column(
                children: [
                  for (final contact in data.contacts)
                    SettingsRow(
                      title: contact.name,
                      icon: LucideIcons.phone,
                      subtitle:
                          '${contact.phone} · ${contact.relationship}${contact.isPrimary ? ' · Primary' : ''}',
                      onTap: () =>
                          _showContact(context, ref, account.id, contact),
                    ),
                  SettingsRow(
                    title: 'Add emergency contact',
                    icon: LucideIcons.phone,
                    onTap: () => _showContact(context, ref, account.id, null),
                  ),
                ],
              ),
            ),
          ],
        ],
        Panel.grouped(
          child: Column(
            children: [
              SettingsRow(
                title: 'Choose role',
                icon: LucideIcons.user,
                subtitle: account.roles
                    .where((role) => role != AccountRole.admin)
                    .map((role) => role.name)
                    .join(' · '),
                onTap: controller.chooseRole,
              ),
              if (!onboarding)
                ActionButton(
                  'Sync verified identity',
                  () => _operate(context, controller.sync),
                  secondary: true,
                ),
              ActionButton('Sign out', controller.signOut, secondary: true),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _operate(
  BuildContext context,
  Future<void> Function() operation,
) async {
  try {
    await operation();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiFailure.of(error).message)));
    }
  }
}

void _showProfile(
  BuildContext context,
  WidgetRef ref,
  DriverProfile profile,
  String owner,
  bool onboarding,
) {
  final repository = ref.read(driverRepositoryProvider);
  final session = ref.read(sessionProvider.notifier);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ProfileForm(
      profile: profile,
      save: (first, last, pref) async {
        await repository.updateProfile(first, last, pref);
        if (!context.mounted) return;
        ref.invalidate(driverDataProvider(owner));
      },
      afterClose: onboarding
          ? () => _operate(context, session.completeDriver)
          : null,
    ),
  );
}

void _showContact(
  BuildContext context,
  WidgetRef ref,
  String owner,
  EmergencyContact? contact,
) {
  final repository = ref.read(driverRepositoryProvider);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ContactForm(
      contact: contact,
      save: (values) async {
        await repository.updateContact(contact, values);
        if (context.mounted) ref.invalidate(driverDataProvider(owner));
      },
      remove: contact == null
          ? null
          : () async {
              await repository.deleteContact(contact.id);
              if (context.mounted) ref.invalidate(driverDataProvider(owner));
            },
    ),
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.profile,
    required this.save,
    this.afterClose,
  });
  final DriverProfile profile;
  final Future<void> Function(String, String, String?) save;
  final VoidCallback? afterClose;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final first = TextEditingController(text: widget.profile.firstName);
  late final last = TextEditingController(text: widget.profile.lastName);
  late String preference = widget.profile.contactPreference ?? 'ANY';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    first.dispose();
    last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(
        first.text.trim(),
        last.text.trim(),
        preference == 'ANY' ? null : preference,
      );
      if (!mounted) return;
      final after = widget.afterClose;
      Navigator.pop(context);
      after?.call();
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = ApiFailure.of(failure).message;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
    title: 'Personal details',
    onBack: busy ? null : () => Navigator.pop(context),
    footer: ActionButton('Save profile', busy ? null : _save),
    children: [
      MechiFormField(controller: first, label: 'First name', maxLength: 80),
      MechiFormField(controller: last, label: 'Last name', maxLength: 80),
      Panel.grouped(
        child: SelectionField<String>(
          icon: LucideIcons.phone,
          title: 'Preferred contact',
          options: const ['ANY', 'PHONE', 'EMAIL'],
          value: preference,
          labelFor: (item) => switch (item) {
            'PHONE' => 'Phone',
            'EMAIL' => 'Email',
            _ => 'Any verified contact',
          },
          onChanged: (value) => setState(() => preference = value),
        ),
      ),
      if (error != null) InformationNotice(error!),
    ],
  );
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.contact, required this.save, this.remove});
  final EmergencyContact? contact;
  final Future<void> Function(Json) save;
  final Future<void> Function()? remove;
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final name = TextEditingController(text: widget.contact?.name);
  late final phone = TextEditingController(text: widget.contact?.phone);
  late final relationship = TextEditingController(
    text: widget.contact?.relationship,
  );
  late bool primary = widget.contact?.isPrimary ?? false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    relationship.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = ApiFailure.of(failure).message;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
    title: widget.contact == null
        ? 'Add emergency contact'
        : 'Edit emergency contact',
    onBack: busy ? null : () => Navigator.pop(context),
    footer: ActionButton(
      'Save contact',
      busy
          ? null
          : () => _run(
              () => widget.save({
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'relationship': relationship.text.trim(),
                'isPrimary': primary,
              }),
            ),
    ),
    children: [
      MechiFormField(controller: name, label: 'Name', maxLength: 100),
      MechiFormField(
        controller: phone,
        label: 'Phone',
        maxLength: 32,
        keyboardType: TextInputType.phone,
      ),
      MechiFormField(
        controller: relationship,
        label: 'Relationship',
        maxLength: 80,
      ),
      Panel.grouped(
        child: SettingsRow(
          icon: LucideIcons.phone,
          title: 'Primary contact',
          subtitle: primary ? 'Yes' : 'No',
          onTap: () => setState(() => primary = !primary),
        ),
      ),
      if (widget.remove != null)
        ActionButton(
          'Remove contact',
          busy ? null : () => _run(widget.remove!),
          secondary: true,
        ),
      if (error != null) InformationNotice(error!),
    ],
  );
}
