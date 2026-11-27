import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../account/session.dart';
import '../garage/dashboard_components.dart';
import '../garage/profile_components.dart';
import 'mechanic_data.dart';
import '../job_execution/job_notifications.dart';
import '../marketplace/mechanic_marketplace.dart';
import '../marketplace/assignment_screens.dart';

enum _Page {
  home,
  profile,
  personal,
  professional,
  qualifications,
  documents,
  services,
  areas,
  submit,
  jobs,
  earnings,
}

class MechanicScreen extends ConsumerStatefulWidget {
  const MechanicScreen({super.key});
  @override
  ConsumerState<MechanicScreen> createState() => _MechanicScreenState();
}

class _MechanicScreenState extends ConsumerState<MechanicScreen>
    with WidgetsBindingObserver {
  _Page page = _Page.home;
  Timer? foreground;
  MechanicRepository? operationalRepository;
  bool busy = false, sampling = false, foregroundVisible = true;
  int operation = 0;
  String? notice, notificationJob;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    final repository = operationalRepository;
    if (repository != null) unawaited(_offlineInBackground(repository));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      foregroundVisible = true;
      if (mounted) _refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      foregroundVisible = false;
      _stop();
      final repository = operationalRepository;
      if (repository != null) unawaited(_offlineInBackground(repository));
    }
  }

  Future<void> _offlineInBackground(MechanicRepository repository) async {
    try {
      await repository.availability('OFFLINE');
    } catch (_) {
      // The backend expires the effective availability when the last point ages.
    }
  }

  void _stop() {
    operation++;
    foreground?.cancel();
    foreground = null;
  }

  void _refresh() {
    final owner = ref.read(sessionProvider).account?.id;
    if (owner != null) ref.invalidate(mechanicDataProvider(owner));
  }

  void _open(_Page next) => setState(() {
    page = next;
    notice = null;
    notificationJob = null;
  });

  String _error(Object error) =>
      error is MechanicFailure ? error.message : ApiFailure.of(error).message;

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await action();
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) setState(() => notice = _error(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setStatus(MechanicData data, String status) async {
    final repository = ref.read(mechanicRepositoryProvider);
    _stop();
    if (status == 'OFFLINE') {
      await repository.availability(status);
      operationalRepository = null;
      return;
    }
    if (!foregroundVisible) {
      throw const MechanicFailure('Open Mechi to share your current location.');
    }
    final device = ref.read(mechanicDeviceProvider);
    final generation = operation;
    final position = await device.position(requestPermission: true);
    if (!mounted || !foregroundVisible || operation != generation) return;
    await repository.request<Json>('PUT', 'location', body: position);
    if (!mounted || !foregroundVisible || operation != generation) return;
    // Hold the repository before the network call because a lost response can
    // leave the server available even if the client could not confirm it.
    operationalRepository = repository;
    final result = await repository.availability(status);
    if (!mounted || !foregroundVisible || operation != generation) {
      await _offlineInBackground(repository);
      return;
    }
    if (result['status'] != 'AVAILABLE') {
      throw const MechanicFailure('The server could not confirm availability.');
    }
    final maxAge = data.profile.requirements['locationMaxAgeSeconds'] as int;
    foreground = Timer.periodic(Duration(seconds: max(5, maxAge ~/ 3)), (
      _,
    ) async {
      if (!mounted ||
          !foregroundVisible ||
          sampling ||
          operation != generation) {
        return;
      }
      sampling = true;
      try {
        final sample = await device.position(requestPermission: false);
        if (!mounted || !foregroundVisible || operation != generation) return;
        await repository.request<Json>('PUT', 'location', body: sample);
        if (!mounted || !foregroundVisible || operation != generation) return;
        final effective = await repository.request<Json>('GET', 'availability');
        if (effective['status'] != 'AVAILABLE') {
          _stop();
          await repository.availability('OFFLINE');
          operationalRepository = null;
        }
      } catch (_) {
        _stop();
        await _offlineInBackground(repository);
        if (mounted) {
          setState(
            () => notice =
                'Location updates stopped. Checking your availability.',
          );
        }
      } finally {
        sampling = false;
        if (mounted) _refresh();
      }
    });
  }

  Future<void> _leave(bool logout, MechanicProfile? profile) async {
    final session = ref.read(sessionProvider.notifier);
    _stop();
    final repository = operationalRepository;
    if (profile?.approved == true || repository != null) {
      try {
        await (repository ??
                ref.read<MechanicRepository>(mechanicRepositoryProvider))
            .availability('OFFLINE');
        operationalRepository = null;
      } catch (_) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Availability could not be confirmed'),
            content: const Text(
              'Location updates have stopped. Any remaining availability expires when the last location is no longer fresh.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
    }
    if (logout) {
      await session.signOut();
    } else {
      session.chooseRole();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final owner = session.account?.id;
    if (owner == null) return const SizedBox.shrink();
    // Keep the device-bound repository alive for deliberate writes and offline transitions.
    final repository = ref.watch(mechanicRepositoryProvider);
    final result = ref.watch(mechanicDataProvider(owner));
    final data = result.hasError && !ApiFailure.of(result.error!).recoverable
        ? null
        : result.value;
    final profile = data?.profile;
    final pageAllowed =
        profile?.approved == true ||
        (page != _Page.jobs && page != _Page.earnings);
    final currentPage = pageAllowed ? page : _Page.home;
    return Screen(
      title: switch (currentPage) {
        _Page.home =>
          profile?.approved == true
              ? 'Mechanic dashboard'
              : 'Mechanic onboarding',
        _Page.profile => 'Professional profile',
        _Page.personal => 'Personal information',
        _Page.professional => 'Professional information',
        _Page.qualifications => 'Qualifications',
        _Page.documents => 'Verification documents',
        _Page.services => 'Supported services',
        _Page.areas => 'Operating areas',
        _Page.submit => 'Review application',
        _Page.jobs => 'Jobs',
        _Page.earnings => 'Earnings',
      },
      onBack: currentPage == _Page.home || busy
          ? null
          : () => _open(_Page.home),
      footer:
          profile?.approved == true &&
              const [
                _Page.home,
                _Page.profile,
                _Page.jobs,
                _Page.earnings,
              ].contains(currentPage)
          ? LayoutBuilder(
              builder: (context, constraints) => Center(
                child: DashboardNavigation.mechanic(
                  availableWidth: constraints.maxWidth,
                  selectedIndex: switch (currentPage) {
                    _Page.jobs => 1,
                    _Page.earnings => 2,
                    _Page.profile => 3,
                    _ => 0,
                  },
                  onHome: () => _open(_Page.home),
                  onJobs: () => _open(_Page.jobs),
                  onEarnings: () => _open(_Page.earnings),
                  onProfile: () => _open(_Page.profile),
                ),
              ),
            )
          : null,
      children: [
        if (notice != null) InformationNotice(notice!),
        if (result.isLoading && data == null)
          const InformationNotice('Loading your mechanic account…'),
        if (result.hasError)
          InformationNotice(
            data == null
                ? 'Could not load your mechanic account.'
                : 'Showing previously loaded information.',
          ),
        if (result.hasError) ActionButton('Retry', _refresh),
        if (data != null) ..._content(currentPage, data, repository, session),
        if (currentPage == _Page.home || currentPage == _Page.profile) ...[
          Panel.grouped(
            child: Column(
              children: [
                SettingsRow(
                  title: 'Choose role',
                  icon: LucideIcons.user,
                  onTap: busy ? null : () => _run(() => _leave(false, profile)),
                ),
                ActionButton(
                  'Sign out',
                  busy ? null : () => _run(() => _leave(true, profile)),
                  secondary: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _content(
    _Page current,
    MechanicData data,
    MechanicRepository repository,
    Session session,
  ) {
    final profile = data.profile;
    switch (current) {
      case _Page.home:
        if (profile.approved) {
          return [
            ProfileHeader(
              name: 'Hello, ${profile.displayName}',
              subtitle: 'Approved mechanic',
            ),
            DashboardMetric(
              LucideIcons.shieldCheck,
              profile.availability == 'AVAILABLE' ? 'Available' : 'Offline',
              'Availability',
            ),
            ActionButton(
              profile.availability == 'AVAILABLE'
                  ? 'Go offline'
                  : 'Go available',
              busy
                  ? null
                  : () => _run(
                      () => _setStatus(
                        data,
                        profile.availability == 'AVAILABLE'
                            ? 'OFFLINE'
                            : 'AVAILABLE',
                      ),
                    ),
            ),
            Panel.grouped(
              child: Column(
                children: [
                  InfoRow(
                    'Approved services',
                    '${data.services.where((row) => row['approvalStatus'] == 'APPROVED' && (row['category'] as Json)['active'] == true).length}',
                  ),
                  InfoRow(
                    'Active operating areas',
                    '${data.areas.where((row) => row['active'] == true && row['selected'] == true).length}',
                  ),
                ],
              ),
            ),
            const SectionTitle('Quick actions'),
            Panel.grouped(
              child: Column(
                children: [
                  SettingsRow(
                    title: 'Notifications',
                    icon: LucideIcons.bell,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => JobNotifications(
                        openJob: (id) {
                          if (!mounted) return;
                          setState(() {
                            notificationJob = id;
                            page = _Page.jobs;
                            notice = null;
                          });
                        },
                      ),
                    ),
                  ),
                  SettingsRow(
                    title: 'Professional profile',
                    icon: LucideIcons.user,
                    onTap: () => _open(_Page.profile),
                  ),
                  SettingsRow(
                    title: 'Supported services',
                    icon: LucideIcons.wrench,
                    onTap: () => _open(_Page.services),
                  ),
                  SettingsRow(
                    title: 'Operating areas',
                    icon: LucideIcons.mapPin,
                    onTap: () => _open(_Page.areas),
                  ),
                ],
              ),
            ),
            const SectionTitle('Incoming requests'),
            MechanicInvitations(key: ValueKey(session.account?.id)),
            const SectionTitle('Completed jobs'),
            const InformationNotice('Completed jobs are unavailable.'),
            const SectionTitle('Earnings'),
            const InformationNotice('Earnings are unavailable.'),
          ];
        }
        return [
          ProfileHeader(
            name: profile.displayName,
            subtitle: 'Mechanic account',
          ),
          InformationNotice(
            'Mechanic verification: ${profile.status.toLowerCase().replaceAll('_', ' ')}',
          ),
          if (profile.reason != null) InformationNotice(profile.reason!),
          InformationNotice(switch (profile.status) {
            'DRAFT' =>
              'Complete the professional application to request review.',
            'SUBMITTED' => 'Your application has been submitted.',
            'UNDER_REVIEW' => 'Your application is under manual review.',
            'ASSESSMENT_REQUIRED' => 'A practical assessment is required.',
            'CHANGES_REQUIRED' =>
              'Correct the requested information and resubmit.',
            'REJECTED' =>
              'Your application was rejected. Contact Mechi for assistance.',
            _ => 'Mechanic operations are restricted.',
          }),
          ActionButton(
            'Refresh status',
            busy ? null : _refresh,
            secondary: true,
          ),
          _sections(profile),
        ];
      case _Page.profile:
        return [
          ProfileHeader(name: profile.displayName, subtitle: 'Mechanic'),
          Panel.grouped(
            child: Column(
              children: [
                if (session.account?.email case final email?)
                  InfoRow('Verified email', email),
                if (session.account?.phone case final phone?)
                  InfoRow('Verified phone', phone),
                InfoRow('Verification', profile.status.replaceAll('_', ' ')),
                InfoRow(
                  'Experience',
                  profile.experienceYears == null
                      ? 'Unspecified'
                      : '${profile.experienceYears} years',
                ),
              ],
            ),
          ),
          if (profile.bio case final bio?) Panel(child: Text(bio)),
          _sections(profile, includeProfile: false),
          ActionButton(
            'Sync verified identity',
            busy ? null : () => _run(ref.read(sessionProvider.notifier).sync),
            secondary: true,
          ),
        ];
      case _Page.personal:
      case _Page.professional:
        return [
          _ProfessionalForm(
            key: ValueKey((
              current,
              profile.displayName,
              profile.bio,
              profile.experienceYears,
              profile.editable,
            )),
            profile: profile,
            personal: current == _Page.personal,
            busy: busy,
            save: (body) => _run(() async {
              await repository.request<Json>('PATCH', '', body: body);
            }),
          ),
        ];
      case _Page.qualifications:
        return [
          if (data.qualifications.isEmpty)
            const InformationNotice('No qualifications saved.'),
          for (final qualification in data.qualifications)
            Panel.grouped(
              child: SettingsRow(
                title: qualification['title'] as String,
                icon: LucideIcons.check,
                subtitle:
                    '${qualification['institution']} · ${qualification['verificationStatus']}',
                onTap:
                    !busy &&
                        profile.editable &&
                        qualification['verificationStatus'] == 'PENDING'
                    ? () => _editQualification(repository, qualification)
                    : null,
              ),
            ),
          if (profile.editable)
            ActionButton(
              'Add qualification',
              busy ? null : () => _editQualification(repository, null),
            ),
        ];
      case _Page.documents:
        return [
          if (data.documents.isEmpty)
            const InformationNotice('No verification documents saved.'),
          for (final document in data.documents)
            Panel.grouped(
              child: SettingsRow(
                title: '${document['type']}',
                icon: LucideIcons.check,
                subtitle:
                    '${document['reviewStatus']} · ${document['contentType']}',
                onTap:
                    !busy &&
                        profile.editable &&
                        document['reviewStatus'] == 'PENDING'
                    ? () => _removeDocument(repository, document)
                    : null,
              ),
            ),
          if (profile.editable &&
              profile.requirements['localDocumentsEnabled'] == true)
            _UploadForm(
              limit: profile.requirements['maxDocumentBytes'] as int,
              device: ref.read(mechanicDeviceProvider),
              upload: repository.upload,
              qualifications: data.qualifications,
              onSuccess: _refresh,
            ),
          if (profile.requirements['localDocumentsEnabled'] != true)
            const InformationNotice(
              'Private document submission is unavailable in this environment.',
            ),
        ];
      case _Page.services:
        final selected = data.services
            .map((row) => row['categoryId'] as String)
            .toSet();
        return [
          if (profile.editable)
            const InformationNotice(
              'Selected services require review before they count toward operational availability.',
            ),
          _SelectionForm(
            key: ValueKey((selected.toList()..sort()).join(',')),
            rows: data.categories
                .where(
                  (row) => profile.editable || selected.contains(row['id']),
                )
                .toList(),
            selected: selected,
            editable: profile.editable,
            busy: busy,
            icon: LucideIcons.wrench,
            save: (choices) => _run(() async {
              await repository.request<List<dynamic>>(
                'PUT',
                'services',
                body: {'ids': choices},
              );
            }),
          ),
        ];
      case _Page.areas:
        final selected = data.areas
            .where((row) => row['selected'] == true)
            .map((row) => row['id'] as String)
            .toSet();
        return [
          if (!data.areas.any((row) => row['active'] == true))
            const InformationNotice(
              'No active operating areas are available. You can still submit your application.',
            ),
          _SelectionForm(
            key: ValueKey((selected.toList()..sort()).join(',')),
            rows: data.areas
                .where(
                  (row) => profile.editable || selected.contains(row['id']),
                )
                .toList(),
            selected: selected,
            editable: profile.editable,
            busy: busy,
            icon: LucideIcons.mapPin,
            save: (choices) => _run(() async {
              await repository.request<List<dynamic>>(
                'PUT',
                'areas',
                body: {'ids': choices},
              );
            }),
          ),
        ];
      case _Page.submit:
        return [
          Panel.grouped(
            child: Column(
              children: [
                InfoRow(
                  'Qualifications saved',
                  '${data.qualifications.length} · Minimum ${profile.requirements['minQualifications']}',
                ),
                InfoRow(
                  'Documents saved',
                  '${data.documents.length} · Minimum ${profile.requirements['minDocuments']}',
                ),
                InfoRow('Services selected', '${data.services.length}'),
              ],
            ),
          ),
          const InformationNotice(
            'By submitting, you confirm this information is accurate and agree to a manual review.',
          ),
          ActionButton(
            'Confirm and submit',
            busy || !profile.editable
                ? null
                : () => _run(() async {
                    await repository.request<Json>(
                      'POST',
                      'submit-verification',
                      body: {'acknowledged': true},
                    );
                    if (mounted) _open(_Page.home);
                  }),
          ),
        ];
      case _Page.jobs:
        return [
          MarketplaceAssignments(
            mechanic: true,
            id: notificationJob,
            key: ValueKey((session.account?.id, notificationJob)),
          ),
        ];
      case _Page.earnings:
        return [
          const InformationNotice('Earnings and payouts are unavailable.'),
        ];
    }
  }

  Widget _sections(MechanicProfile profile, {bool includeProfile = true}) =>
      Panel.grouped(
        child: Column(
          children: [
            for (final (title, icon, destination) in [
              if (includeProfile)
                ('Professional profile', LucideIcons.user, _Page.profile),
              ('Personal information', LucideIcons.user, _Page.personal),
              (
                'Professional information',
                LucideIcons.wrench,
                _Page.professional,
              ),
              ('Qualifications', LucideIcons.check, _Page.qualifications),
              ('Verification documents', LucideIcons.check, _Page.documents),
              ('Supported services', LucideIcons.wrench, _Page.services),
              ('Operating areas', LucideIcons.mapPin, _Page.areas),
              if (profile.editable)
                ('Review and submit', LucideIcons.shieldCheck, _Page.submit),
            ])
              SettingsRow(
                title: title,
                icon: icon,
                onTap: busy ? null : () => _open(destination),
              ),
          ],
        ),
      );

  Future<void> _editQualification(
    MechanicRepository repository,
    Json? item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _QualificationForm(
        item: item,
        save: (body) => repository.request<Json>(
          item == null ? 'POST' : 'PATCH',
          item == null ? 'qualifications' : 'qualifications/${item['id']}',
          body: body,
        ),
        remove: item == null
            ? null
            : () => repository.request<void>(
                'DELETE',
                'qualifications/${item['id']}',
              ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _removeDocument(
    MechanicRepository repository,
    Json document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove this draft document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => repository.request<void>('DELETE', 'documents/${document['id']}'),
      );
    }
  }
}

class _ProfessionalForm extends StatefulWidget {
  const _ProfessionalForm({
    super.key,
    required this.profile,
    required this.personal,
    required this.busy,
    required this.save,
  });
  final MechanicProfile profile;
  final bool personal, busy;
  final Future<void> Function(Json) save;
  @override
  State<_ProfessionalForm> createState() => _ProfessionalFormState();
}

class _ProfessionalFormState extends State<_ProfessionalForm> {
  late final name = TextEditingController(text: widget.profile.displayName);
  late final bio = TextEditingController(text: widget.profile.bio);
  late final experience = TextEditingController(
    text: widget.profile.experienceYears?.toString(),
  );
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    experience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.editable) {
      return Panel.grouped(
        child: Column(
          children: [
            if (widget.personal)
              InfoRow('Display name', widget.profile.displayName)
            else ...[
              InfoRow(
                'Experience',
                widget.profile.experienceYears?.toString() ?? 'Unspecified',
              ),
              if (widget.profile.bio != null) Text(widget.profile.bio!),
            ],
          ],
        ),
      );
    }
    return Form(
      key: form,
      child: Column(
        children: [
          if (widget.personal)
            MechiFormField(
              controller: name,
              label: 'Display name',
              maxLength: 100,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a display name'
                  : null,
            )
          else ...[
            MechiFormField.description(
              controller: bio,
              label: 'Professional biography',
              maxLength: 1500,
            ),
            MechiFormField(
              controller: experience,
              label: 'Years of experience',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final count = int.tryParse(value.trim());
                return count == null || count < 0 || count > 80
                    ? 'Enter a whole number from 0 to 80'
                    : null;
              },
            ),
          ],
          ActionButton(
            'Save details',
            widget.busy
                ? null
                : () {
                    if (!form.currentState!.validate()) return;
                    widget.save(
                      widget.personal
                          ? {'displayName': name.text.trim()}
                          : {
                              'bio': bio.text.trim().isEmpty
                                  ? null
                                  : bio.text.trim(),
                              'experienceYears': int.tryParse(
                                experience.text.trim(),
                              ),
                            },
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _QualificationForm extends StatefulWidget {
  const _QualificationForm({this.item, required this.save, this.remove});
  final Json? item;
  final Future<void> Function(Json) save;
  final Future<void> Function()? remove;
  @override
  State<_QualificationForm> createState() => _QualificationFormState();
}

class _QualificationFormState extends State<_QualificationForm> {
  late final fields = [
    TextEditingController(text: widget.item?['title'] as String?),
    TextEditingController(text: widget.item?['institution'] as String?),
    for (final key in ['issuedOn', 'expiresOn'])
      TextEditingController(
        text: (widget.item?[key] as String?)?.split('T').first,
      ),
  ];
  bool busy = false;
  String? failure;

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          failure = ApiFailure.of(error).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Screen(
    title: widget.item == null ? 'Add qualification' : 'Edit qualification',
    onBack: busy ? null : () => Navigator.pop(context),
    footer: ActionButton(
      'Save qualification',
      busy
          ? null
          : () => _run(
              () => widget.save({
                'title': fields[0].text.trim(),
                'institution': fields[1].text.trim(),
                'issuedOn': fields[2].text.trim().isEmpty
                    ? null
                    : fields[2].text.trim(),
                'expiresOn': fields[3].text.trim().isEmpty
                    ? null
                    : fields[3].text.trim(),
              }),
            ),
    ),
    children: [
      for (final (index, label) in [
        'Qualification title',
        'Institution',
        'Issued on (YYYY-MM-DD)',
        'Expires on (YYYY-MM-DD)',
      ].indexed)
        MechiFormField(
          controller: fields[index],
          label: label,
          maxLength: index < 2 ? 150 : 10,
        ),
      if (failure != null) InformationNotice(failure!),
      if (widget.remove != null)
        ActionButton(
          'Remove draft qualification',
          busy ? null : () => _run(widget.remove!),
          secondary: true,
        ),
    ],
  );
}

class _SelectionForm extends StatefulWidget {
  const _SelectionForm({
    super.key,
    required this.rows,
    required this.selected,
    required this.editable,
    required this.busy,
    required this.icon,
    required this.save,
  });
  final List<Json> rows;
  final Set<String> selected;
  final bool editable, busy;
  final IconData icon;
  final Future<void> Function(List<String>) save;
  @override
  State<_SelectionForm> createState() => _SelectionFormState();
}

class _SelectionFormState extends State<_SelectionForm> {
  late final choices = {...widget.selected};

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.rows.isEmpty)
        const InformationNotice('No options to display.'),
      for (final row in widget.rows)
        Panel.grouped(
          child: SettingsRow(
            title: row['name'] as String,
            subtitle: [
              if (row['region'] case final String region) region,
              row['active'] == false
                  ? 'Inactive'
                  : choices.contains(row['id'])
                  ? 'Selected'
                  : 'Not selected',
            ].join(' · '),
            icon: choices.contains(row['id']) ? LucideIcons.check : widget.icon,
            onTap:
                !widget.editable ||
                    widget.busy ||
                    (row['active'] == false && !choices.contains(row['id']))
                ? null
                : () {
                    setState(() {
                      final id = row['id'] as String;
                      if (!choices.remove(id)) choices.add(id);
                    });
                  },
          ),
        ),
      if (widget.editable && widget.rows.isNotEmpty)
        ActionButton(
          'Save selection',
          widget.busy ? null : () => widget.save(choices.toList()),
        ),
    ],
  );
}

class _UploadForm extends StatefulWidget {
  const _UploadForm({
    required this.limit,
    required this.device,
    required this.upload,
    required this.qualifications,
    required this.onSuccess,
  });
  final int limit;
  final MechanicDevice device;
  final Future<void> Function(PrivateUpload, String, String?) upload;
  final List<Json> qualifications;
  final VoidCallback onSuccess;
  @override
  State<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends State<_UploadForm> {
  PrivateUpload? pending;
  String type = 'OTHER';
  String qualification = '';
  bool busy = false;
  String? failure;

  Future<void> _act(Future<void> Function() execute) async {
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await execute();
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is MechanicFailure
              ? error.message
              : ApiFailure.of(error).message,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const InformationNotice(
        'Upload fictional or synthetic documents only in this local environment.',
      ),
      Panel.grouped(
        child: SelectionField<String>(
          title: 'Document type',
          icon: LucideIcons.check,
          options: const ['OTHER', 'IDENTITY', 'QUALIFICATION'],
          value: type,
          labelFor: (value) => value,
          onChanged: (value) {
            if (!busy) {
              setState(() {
                if (type != value) pending = null;
                type = value;
              });
            }
          },
        ),
      ),
      if (widget.qualifications.isNotEmpty)
        Panel.grouped(
          child: SelectionField<String>(
            title: 'Linked qualification',
            icon: LucideIcons.check,
            options: [
              '',
              for (final record in widget.qualifications)
                record['id'] as String,
            ],
            value: qualification,
            labelFor: (value) => value.isEmpty
                ? 'No linked qualification'
                : (widget.qualifications
                              .where((record) => record['id'] == value)
                              .firstOrNull?['title']
                          as String? ??
                      'Qualification'),
            onChanged: (value) {
              if (!busy) {
                setState(() {
                  if (qualification != value) pending = null;
                  qualification = value;
                });
              }
            },
          ),
        ),
      ActionButton(
        'Choose private file',
        busy
            ? null
            : () => _act(() async {
                final picked = await widget.device.pickDocument(widget.limit);
                if (picked != null && mounted) setState(() => pending = picked);
              }),
        secondary: true,
      ),
      if (pending case final file?) ...[
        InfoRow('Selected file', file.name),
        ActionButton(
          'Upload document',
          busy
              ? null
              : () => _act(() async {
                  await widget.upload(
                    file,
                    type,
                    qualification.isEmpty ? null : qualification,
                  );
                  if (mounted) {
                    setState(() => pending = null);
                    widget.onSuccess();
                  }
                }),
        ),
      ],
      if (failure != null) InformationNotice(failure!),
    ],
  );
}
