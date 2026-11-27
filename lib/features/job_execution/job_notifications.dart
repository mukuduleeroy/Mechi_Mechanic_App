import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../account/push_registration.dart';
import '../marketplace/marketplace_data.dart';

class JobNotifications extends ConsumerStatefulWidget {
  const JobNotifications({super.key, this.openJob});
  final ValueChanged<String>? openJob;

  @override
  ConsumerState<JobNotifications> createState() => _JobNotificationsState();
}

class _JobNotificationsState extends ConsumerState<JobNotifications> {
  List<Json>? notices;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    if (!mounted) return;
    try {
      final rows = await ref
          .read(marketplaceProvider)
          .get<List<dynamic>>('notifications');
      if (mounted) {
        setState(() {
          notices = rows.cast<Json>();
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = marketplaceError(failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(marketplaceProvider);
    final push = ref.watch(pushRegistrationProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(Mechi.pad),
        children: [
          const SectionTitle('Notifications'),
          if (push.enabled)
            ActionButton('Enable push notifications', () async {
              try {
                await push.register();
                await load();
              } catch (_) {
                if (mounted) {
                  setState(() => error = 'Push registration is unavailable.');
                }
              }
            }, secondary: true),
          if (error != null) InformationNotice(error!),
          if (notices == null && error == null)
            const InformationNotice('Loading notifications…'),
          if (notices?.isEmpty == true)
            const InformationNotice('You’re all caught up.'),
          for (final notice in notices ?? const <Json>[])
            Panel.grouped(
              child: SettingsRow(
                icon: LucideIcons.bell,
                title: notice['title'] as String,
                subtitle: notice['readAt'] == null ? 'Unread' : null,
                onTap: () async {
                  final router = GoRouter.of(context);
                  try {
                    await store.post("notifications/${notice['id']}/read");
                    if (context.mounted) {
                      Navigator.pop(context);
                      final id = notice['event']['jobId'] as String;
                      final open = widget.openJob;
                      if (open == null) {
                        router.push('/assignments/$id');
                      } else {
                        open(id);
                      }
                    }
                  } catch (failure) {
                    if (mounted) {
                      setState(() => error = marketplaceError(failure));
                    }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
