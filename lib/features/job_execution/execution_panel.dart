import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import '../marketplace/marketplace_data.dart';
import '../marketplace/driver_marketplace_screens.dart' show confirmMarketplace;
import 'native_job_actions.dart';
import 'tracking_map.dart';
import '../mechanic/mechanic_data.dart';

String operationalStatus(Object? status) => switch (status) {
  'CONFIRMED' => 'Confirmed assignment',
  'EN_ROUTE' => 'En route',
  'ARRIVED' => 'Arrived',
  'DIAGNOSING' => 'Diagnosis underway',
  'AWAITING_APPROVAL' => 'Awaiting approval',
  'IN_PROGRESS' => 'Service in progress',
  'COMPLETION_SUBMITTED' => 'Completion submitted',
  'COMPLETED' => 'Service completed',
  'CANCELLED' => 'Cancelled',
  'UNSUCCESSFUL' => 'Service unsuccessful',
  _ => 'Assignment',
};

class JobExecutionPanel extends ConsumerStatefulWidget {
  const JobExecutionPanel({
    super.key,
    required this.id,
    required this.mechanic,
    required this.job,
    required this.refreshJob,
  });
  final String id;
  final bool mechanic;
  final Json job;
  final Future<void> Function() refreshJob;

  @override
  ConsumerState<JobExecutionPanel> createState() => _JobExecutionPanelState();
}

class _JobExecutionPanelState extends ConsumerState<JobExecutionPanel>
    with WidgetsBindingObserver, ForegroundPoll<JobExecutionPanel> {
  static const _trackingInterval = int.fromEnvironment(
    'MECHI_JOB_TRACKING_SECONDS',
    defaultValue: 8,
  );
  static const _movementMetres = int.fromEnvironment(
    'MECHI_JOB_MOVEMENT_METRES',
    defaultValue: 5,
  );
  Json? lastFix;
  DateTime? lastSent;
  final submission = SubmissionKey();
  final first = TextEditingController(), second = TextEditingController();
  final conversation = GlobalKey();
  final trackingMap = GlobalKey();
  List<Json> events = [], timeline = [];
  Json? location, directions;
  String? pending, problem, unsuccessfulReason;
  static const unsuccessfulReasons = {
    'UNABLE_TO_REPAIR': 'Unable to repair the vehicle',
    'CUSTOMER_UNAVAILABLE': 'Customer unavailable',
    'UNSAFE_CONDITIONS': 'Unsafe service conditions',
    'PARTS_UNAVAILABLE': 'Replacement parts unavailable',
    'WORKSHOP_OR_TOWING': 'Specialised workshop or towing required',
  };
  bool busy = false, sendingLocation = false, socketReady = false;
  bool visible = true;
  int socketEpoch = 0, cursor = 0;
  io.Socket? socket;
  Timer? locationTimer, reconnect, subscriptionDeadline, freshnessDeadline;
  var failures = 0;

  String get status => widget.job['status'] as String;
  int get version => (widget.job['version'] as int?) ?? 0;
  bool get closed =>
      const {'COMPLETED', 'CANCELLED', 'UNSUCCESSFUL'}.contains(status);
  bool get watchJob => !closed || widget.job['interventionRequired'] == true;
  bool get travelling => const {'EN_ROUTE', 'ARRIVED'}.contains(status);
  String get path => 'jobs/${widget.id}';
  @override
  bool get keepPolling => !socketReady && watchJob;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => connect());
  }

  Future<void> connect() async {
    if (!mounted || !visible || !watchJob) return;
    final epoch = ++socketEpoch;
    final repository = ref.read(marketplaceProvider);
    try {
      final token = await repository.api.auth.currentUser?.getIdToken(
        failures > 0,
      );
      if (!mounted || !visible || epoch != socketEpoch || token == null) return;
      final host = Uri.parse(repository.api.dio.options.baseUrl);
      final connection = io.io(
        '${host.origin}/jobs',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .disableReconnection()
            .enableForceNew()
            .setAuth({'token': token})
            .build(),
      );
      socket = connection;
      connection.onConnect((_) {
        if (!mounted || epoch != socketEpoch) return;
        subscriptionDeadline?.cancel();
        subscriptionDeadline = Timer(
          const Duration(seconds: 5),
          () => disconnected(epoch),
        );
        connection.emitWithAck(
          'subscribe',
          {'jobId': widget.id, 'after': cursor},
          ack: (reply) {
            if (!mounted || epoch != socketEpoch) return;
            subscriptionDeadline?.cancel();
            if (reply is! Map || reply['ok'] != true) {
              disconnected(epoch);
              return;
            }
            failures = 0;
            socketReady = true;
            unawaited(refresh());
          },
        );
      });
      connection.onDisconnect((_) => disconnected(epoch));
      connection.onConnectError((_) => disconnected(epoch));
      connection.on('job-events', (packet) {
        if (packet is Map &&
            packet['jobId'] == widget.id &&
            packet['events'] is List &&
            (packet['events'] as List).whereType<Map>().any(
              (event) =>
                  event['version'] is int && (event['version'] as int) > cursor,
            )) {
          unawaited(refresh());
        }
      });
      connection.on('job-location', (packet) {
        if (packet is Map && packet['jobId'] == widget.id) unawaited(refresh());
      });
      connection.connect();
    } catch (_) {
      disconnected(epoch);
    }
  }

  void disconnected(int epoch) {
    if (!mounted || epoch != socketEpoch) return;
    closeSocket();
    unawaited(refresh());
    if (!visible || !watchJob) return;
    failures = (failures + 1).clamp(1, 4);
    reconnect = Timer(Duration(seconds: 1 << failures), connect);
  }

  void closeSocket() {
    socketEpoch++;
    reconnect?.cancel();
    subscriptionDeadline?.cancel();
    socket?.dispose();
    socket = null;
    socketReady = false;
  }

  @override
  void didUpdateWidget(covariant JobExecutionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!travelling) {
      stopLocation();
      freshnessDeadline?.cancel();
      directions = null;
    }
    if (pending == 'cancel' && status == 'CANCELLED') {
      pending = null;
      problem = null;
      submission.reset();
    }
    if (!watchJob) {
      closeSocket();
    } else if (!visible || socket != null) {
      return;
    } else if (oldWidget.job['interventionRequired'] != true &&
        widget.job['interventionRequired'] == true) {
      unawaited(connect());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    visible = state == AppLifecycleState.resumed;
    if (!visible) {
      stopLocation();
      closeSocket();
    } else {
      unawaited(connect());
    }
  }

  @override
  void dispose() {
    stopLocation();
    closeSocket();
    freshnessDeadline?.cancel();
    first.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Future<void> poll() async {
    final backend = ref.read(marketplaceProvider);
    await widget.refreshJob();
    final history = await backend.get<List<dynamic>>('$path/timeline');
    final changes = await backend.get<List<dynamic>>(
      '$path/events',
      query: {'after': cursor},
    );
    final tracking = await backend.get<Json>('$path/tracking');
    if (!mounted) return;
    final observed = observationTime(tracking);
    final previous = observationTime(location);
    final accept =
        observed == null || previous == null || !observed.isBefore(previous);
    if (accept) {
      freshnessDeadline?.cancel();
      if (observed != null && travelling) {
        final remaining = observed
            .add(const Duration(seconds: 20))
            .difference(DateTime.now());
        if (remaining > Duration.zero) {
          freshnessDeadline = Timer(remaining, () {
            if (mounted) setState(() {});
          });
        }
      }
    }
    setState(() {
      timeline = history.cast<Json>();
      events = [...events, ...changes.cast<Json>()];
      if (changes.isNotEmpty) cursor = (changes.last as Json)['version'] as int;
      if (accept) location = tracking;
    });
    if (changes.length == 50) unawaited(refresh());
  }

  @override
  void pollError(Object error) {
    if (mounted) setState(() => problem = marketplaceError(error));
  }

  void stopLocation() {
    locationTimer?.cancel();
    locationTimer = null;
  }

  Future<void> publishLocation({bool permission = false}) async {
    if (!mounted || !visible || !travelling || sendingLocation) return;
    final backend = ref.read(marketplaceProvider);
    final device = ref.read(mechanicDeviceProvider);
    sendingLocation = true;
    try {
      final point = await device.position(requestPermission: permission);
      if (!mounted || !visible || !travelling) return;
      final accuracy = point['accuracyMetres'];
      if (accuracy is! num || accuracy > 1000) {
        setState(() => problem = 'Location accuracy is too low to share.');
        stopLocation();
        return;
      }
      final previous = lastFix;
      if (!permission &&
          previous != null &&
          lastSent != null &&
          DateTime.now().difference(lastSent!).inSeconds < 16 &&
          Geolocator.distanceBetween(
                (previous['latitude'] as num).toDouble(),
                (previous['longitude'] as num).toDouble(),
                (point['latitude'] as num).toDouble(),
                (point['longitude'] as num).toDouble(),
              ) <
              _movementMetres.clamp(0, 100)) {
        return;
      }
      await backend.api.request<Json>(
        'PUT',
        '$path/location',
        body: point,
        ownerUid: backend.owner,
        cancelToken: backend.token,
      );
      lastFix = point;
      lastSent = DateTime.now();
      if (mounted && permission && visible && travelling) {
        setState(
          () => locationTimer = Timer.periodic(
            Duration(seconds: _trackingInterval.clamp(5, 10)),
            (_) => publishLocation(),
          ),
        );
      }
    } catch (error) {
      stopLocation();
      if (mounted) setState(() => problem = marketplaceError(error));
    } finally {
      sendingLocation = false;
    }
  }

  DateTime? observationTime(Json? tracking) {
    final point = tracking?['position'];
    return point is Map && point['observedAt'] is String
        ? DateTime.tryParse(point['observedAt'] as String)
        : null;
  }

  Future<void> externalNavigation(Offset destination) async {
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.dy},${destination.dx}',
      'travelmode': 'driving',
    });
    if (!await openJobDirections(url) && mounted) {
      setState(() => problem = 'Navigation is unavailable on this device.');
    }
  }

  Future<void> callParticipant() async {
    try {
      final contact = await ref
          .read(marketplaceProvider)
          .get<Json>('$path/contact');
      if (!mounted) return;
      final phone = contact['phone'];
      if (phone is! String) {
        setState(() => problem = 'A verified phone number is unavailable.');
      } else if (!await openJobDialler(phone) && mounted) {
        setState(
          () => problem = 'Phone dialling is unavailable on this device.',
        );
      }
    } catch (error) {
      if (mounted) pollError(error);
    }
  }

  Future<void> submitEdit(String edit, Json body) async {
    if (edit == 'cancel' &&
        !await confirmMarketplace(
          context,
          'Cancel assigned job?',
          'The cancellation reason will be saved with the assignment.',
        )) {
      return;
    }
    if (!mounted) return;
    if (edit == 'no-show') {
      await command('disputes', {
        'text': body['reason'],
        'reasonCode': 'MECHANIC_NO_SHOW',
      });
    } else {
      await command(edit, body);
    }
  }

  Future<void> directionsForJob() async {
    try {
      final result = await ref
          .read(marketplaceProvider)
          .get<Json>('$path/route');
      if (!mounted || !travelling) return;
      setState(() => directions = result);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = trackingMap.currentContext;
        if (mounted && target != null && result['status'] == 'AVAILABLE') {
          unawaited(Scrollable.ensureVisible(target, alignment: .25));
        }
      });
    } catch (error) {
      if (mounted) pollError(error);
    }
  }

  Future<void> command(String command, Json body) async {
    if (busy) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      await ref
          .read(marketplaceProvider)
          .post(
            '$path/$command',
            body: body,
            key: submission.forPayload({'command': command, ...body}),
          );
      if (!mounted) return;
      submission.reset();
      first.clear();
      second.clear();
      unsuccessfulReason = null;
      setState(() => pending = null);
      await refresh();
    } catch (error) {
      if (mounted) {
        setState(() => problem = marketplaceError(error));
        if (command == 'cancel' && ApiFailure.of(error).recoverable) {
          unawaited(refresh());
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void select(String command) {
    first.clear();
    second.clear();
    setState(() => pending = command);
  }

  Widget action(
    String title,
    String action, {
    bool needsText = false,
    bool secondary = false,
  }) => ActionButton(
    title,
    busy
        ? null
        : () {
            if (needsText) {
              select(action);
            } else {
              unawaited(command(action, {'version': version}));
            }
          },
    secondary: secondary,
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(marketplaceProvider);
    final gps = location?['position'] as Json?;
    final destination = jobCoordinate(widget.job['location']);
    final observed = observationTime(location);
    final fresh =
        location?['stale'] == false &&
        observed != null &&
        DateTime.now().difference(observed) < const Duration(seconds: 20);
    final disputed = events.any((event) => event['kind'] == 'DISPUTE');
    final cancellation = timeline
        .where(
          (entry) =>
              const {'CANCELLED', 'UNSUCCESSFUL'}.contains(entry['status']),
        )
        .lastOrNull;

    final revision = events
        .where((event) => event['kind'] == 'PRICE_REQUESTED')
        .lastOrNull;
    final edit = pending;
    return Column(
      spacing: Mechi.gap,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problem != null) InformationNotice(problem!),
        const SectionTitle('Service timeline'),
        if (timeline.isNotEmpty)
          Panel(
            child: Column(
              children: [
                for (final row in timeline)
                  InfoRow(
                    operationalStatus(row['status']),
                    row['createdAt'].toString(),
                  ),
              ],
            ),
          ),
        if (travelling) ...[
          const SectionTitle('Tracking'),
          if (destination != null)
            JobTrackingMap(
              key: trackingMap,
              destination: destination,
              fix: gps,
              route: fresh ? directions : null,
            ),
          Panel(
            child: Column(
              children: [
                if (!socketReady)
                  const InfoRow(
                    'Connection',
                    'Reconnecting · checking for updates',
                  ),
                InfoRow(
                  'Location',
                  fresh
                      ? 'Current observation'
                      : 'Location unavailable or stale',
                ),
                if (gps != null) ...[
                  if (observed != null)
                    InfoRow(
                      'Last observation',
                      '${MaterialLocalizations.of(context).formatCompactDate(observed.toLocal())} · '
                          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(observed.toLocal()))}',
                    ),
                  InfoRow(
                    'Coordinates',
                    "${gps['latitude']}, ${gps['longitude']}",
                  ),
                ],
                if (widget.job['location'] case final Json destination
                    when widget.mechanic)
                  InfoRow(
                    'Service destination',
                    "${destination['latitude']}, ${destination['longitude']}",
                  ),
                if (directions?['status'] == 'AVAILABLE' && fresh) ...[
                  if (directions?['provider'] == 'FIXTURE')
                    const ChipLabel('Test route')
                  else ...[
                    InfoRow(
                      'Road distance',
                      "${directions!['roadDistanceMetres']} m",
                    ),
                    InfoRow(
                      'Travel duration',
                      "${directions!['travelSeconds']} seconds",
                    ),
                  ],
                ] else if (directions != null)
                  const InformationNotice('Road routing is unavailable.'),
                ActionButton(
                  'Request directions',
                  directionsForJob,
                  secondary: true,
                ),
              ],
            ),
          ),
          if (widget.mechanic && destination != null)
            ActionButton(
              'Open navigation',
              () => externalNavigation(destination),
              secondary: true,
            ),
          if (widget.mechanic && locationTimer == null)
            ActionButton(
              'Share foreground location',
              () => publishLocation(permission: true),
            ),
        ],
        if (widget.mechanic && !closed) ...[
          if (status == 'CONFIRMED') action('Start journey', 'start-journey'),
          if (status == 'EN_ROUTE')
            action('Confirm arrival', 'arrive', needsText: true),
          if (status == 'ARRIVED') action('Start diagnosis', 'start-diagnosis'),
          if (status == 'DIAGNOSING') ...[
            action('Record diagnosis', 'diagnostics', needsText: true),
            action('Start service', 'start-service'),
          ],
          if (status == 'DIAGNOSING' || status == 'IN_PROGRESS')
            action(
              'Request additional charges',
              'price-revisions',
              needsText: true,
            ),
          if (status == 'IN_PROGRESS')
            action('Submit completion', 'submit-completion', needsText: true),
          if (const {'ARRIVED', 'DIAGNOSING', 'IN_PROGRESS'}.contains(status))
            action(
              'Report unsuccessful service',
              'report-unsuccessful',
              needsText: true,
              secondary: true,
            ),
        ],
        if (!widget.mechanic &&
            status == 'AWAITING_APPROVAL' &&
            revision != null) ...[
          Panel(
            child: Column(
              children: [
                InfoRow('Reason', revision['payload']['reason'] as String),
                InfoRow(
                  'Proposed total',
                  minorLabel(
                    revision['payload']['currency'],
                    revision['payload']['totalMinor'],
                    revision['payload']['minorDigits'],
                  ),
                ),
                for (final item
                    in (revision['payload']['items'] as List).cast<Json>())
                  InfoRow(
                    item['description'] as String,
                    minorLabel(
                      revision['payload']['currency'],
                      item['amountMinor'],
                      revision['payload']['minorDigits'],
                    ),
                  ),
              ],
            ),
          ),
          action(
            'Approve additional charges',
            "price-revisions/${revision['id']}/approve",
          ),
          action(
            'Decline additional charges',
            "price-revisions/${revision['id']}/decline",
            secondary: true,
          ),
        ],
        if (!widget.mechanic &&
            status == 'COMPLETION_SUBMITTED' &&
            widget.job['interventionRequired'] != true)
          action('Confirm completion', 'confirm-completion'),
        if (widget.job['interventionRequired'] != true &&
            const {'CONFIRMED', 'EN_ROUTE', 'ARRIVED'}.contains(status))
          action(
            'Cancel assigned job',
            'cancel',
            needsText: true,
            secondary: true,
          ),
        if (!closed) ...[
          ActionButton(
            'Call service participant',
            callParticipant,
            secondary: true,
          ),
          ActionButton('Open job conversation', () {
            final target = conversation.currentContext;
            if (target != null) unawaited(Scrollable.ensureVisible(target));
          }, secondary: true),
        ],
        if ((!closed || status == 'UNSUCCESSFUL') && !disputed)
          action(
            'Raise a dispute',
            'disputes',
            needsText: true,
            secondary: true,
          ),
        if (!widget.mechanic &&
            !disputed &&
            const {'CONFIRMED', 'EN_ROUTE'}.contains(status))
          action(
            'Report mechanic no-show',
            'no-show',
            needsText: true,
            secondary: true,
          ),
        if (cancellation?['reason'] case final String reason)
          InfoRow('Recorded reason', reason),
        if (disputed)
          InfoRow(
            'Dispute status',
            widget.job['interventionRequired'] == true
                ? 'Awaiting operational review'
                : 'Resolved',
          ),
        if (edit != null)
          Panel(
            child: Column(
              spacing: Mechi.gap,
              children: [
                if (edit == 'report-unsuccessful')
                  SelectionField<String>(
                    title: 'Service outcome',
                    icon: LucideIcons.wrench,
                    options: unsuccessfulReasons.keys.toList(),
                    value: unsuccessfulReason,
                    labelFor: (value) => unsuccessfulReasons[value]!,
                    onChanged: (value) =>
                        setState(() => unsuccessfulReason = value),
                  ),
                MechiFormField(
                  controller: first,
                  label: switch (edit) {
                    'messages' => 'Message',
                    'diagnostics' => 'Findings',
                    'submit-completion' => 'Work performed',
                    _ => 'Reason',
                  },
                  maxLength: edit == 'price-revisions' ? 500 : 1200,
                ),
                if (edit == 'diagnostics' || edit == 'price-revisions')
                  MechiFormField(
                    controller: second,
                    label: edit == 'diagnostics'
                        ? 'Recommended work'
                        : 'Additional amount in minor units',
                  ),
                ActionButton(
                  'Submit',
                  busy
                      ? null
                      : () {
                          final description = first.text.trim();
                          final extra = second.text.trim();
                          if (description.isEmpty ||
                              (edit == 'report-unsuccessful' &&
                                  unsuccessfulReason == null) ||
                              (edit == 'diagnostics' && extra.isEmpty) ||
                              (edit == 'price-revisions' &&
                                  !RegExp(
                                    r'^[1-9][0-9]{0,8}$',
                                  ).hasMatch(extra))) {
                            setState(
                              () => problem =
                                  'Complete the required fields with valid values.',
                            );
                            return;
                          }
                          unawaited(
                            submitEdit(edit, switch (edit) {
                              'diagnostics' => {
                                'findings': description,
                                'recommendedWork': extra,
                              },
                              'price-revisions' => {
                                'version': version,
                                'reason': description,
                                'items': [
                                  {
                                    'description': description,
                                    'amountMinor': extra,
                                  },
                                ],
                              },
                              'messages' || 'disputes' => {'text': description},
                              'report-unsuccessful' => {
                                'version': version,
                                'reason': description,
                                'outcome': unsuccessfulReason,
                              },
                              _ => {'version': version, 'reason': description},
                            }),
                          );
                        },
                ),
              ],
            ),
          ),
        Column(
          key: conversation,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Job conversation'),
            if (!closed) action('Send message', 'messages', needsText: true),
          ],
        ),
        for (final entry in events.reversed)
          if (entry['payload'] case final Json payload)
            if (entry['kind'] == 'MESSAGE' ||
                entry['kind'] == 'DIAGNOSIS' ||
                entry['kind'] == 'COMPLETION')
              Panel(
                child: Column(
                  children: [
                    SectionTitle(switch (entry['kind']) {
                      'MESSAGE' => 'Message',
                      'DIAGNOSIS' => 'Diagnosis',
                      _ => 'Service summary',
                    }),
                    Text(
                      (payload['text'] ??
                              payload['findings'] ??
                              payload['work'])
                          as String,
                    ),
                    if (payload['recommendedWork'] != null)
                      Text(payload['recommendedWork'] as String),
                    if (payload['approvedPrice'] case final Json price)
                      InfoRow(
                        'Approved total',
                        minorLabel(
                          price['currency'],
                          price['totalMinor'],
                          price['minorDigits'],
                        ),
                      ),
                  ],
                ),
              ),
      ],
    );
  }
}
