import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design_system/design_system.dart';
import '../account/backend.dart';
import 'driver_marketplace_screens.dart';
import 'marketplace_data.dart';

class MechanicInvitations extends ConsumerStatefulWidget {
  const MechanicInvitations({super.key});
  @override
  ConsumerState<MechanicInvitations> createState() =>
      _MechanicInvitationsState();
}

class _MechanicInvitationsState extends ConsumerState<MechanicInvitations>
    with WidgetsBindingObserver, ForegroundPoll<MechanicInvitations> {
  List<Json>? invitations;
  Json? selected;
  String? error, mutationError;
  bool busy = false, quoting = false;
  final key = SubmissionKey();

  @override
  String get marketplaceScope => 'mechanic';

  @override
  MarketplaceRepository get marketplaceConnection =>
      ref.read(marketplaceProvider);

  @override
  Future<void> poll() async {
    if (busy) return;
    final repository = ref.read(marketplaceProvider);
    final id = selected?['id'];
    final rows = await repository.get<List<dynamic>>(
      'mechanics/me/incoming-requests',
    );
    final detail = id == null
        ? null
        : await repository.get<Json>('mechanics/me/incoming-requests/$id');
    if (!mounted) return;
    setState(() {
      invitations = rows.cast<Json>();
      if (selected?['id'] == id) selected = detail;
      error = null;
    });
  }

  @override
  void pollError(Object failure) =>
      setState(() => error = marketplaceError(failure));

  Future<void> change(String path, {Json? payload}) async {
    if (busy) return;
    setState(() {
      busy = true;
      mutationError = null;
    });
    try {
      await ref
          .read(marketplaceProvider)
          .post(
            path,
            body: payload,
            key: payload == null
                ? null
                : key.forPayload({'path': path, ...payload}),
          );
      if (!mounted) return;
      key.reset();
      setState(() {
        busy = false;
        quoting = false;
        error = null;
      });
      await refresh();
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        busy = false;
        mutationError = marketplaceError(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(marketplaceProvider);
    final invitation = selected;
    final feedback = mutationError ?? error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Mechi.gap,
      children: [
        if (feedback != null) ...[
          InformationNotice(feedback),
          ActionButton('Refresh', refresh),
        ],
        if (invitation == null) ...[
          if (invitations == null)
            const InformationNotice('Loading incoming requests…'),
          if (invitations?.isEmpty == true)
            const InformationNotice('No incoming requests.'),
          for (final row in invitations ?? const <Json>[])
            Panel.grouped(
              child: SettingsRow(
                title: (row['service'] as Json)['name'] as String,
                subtitle: (row['service'] as Json)['area'] as String,
                icon: LucideIcons.wrench,
                onTap: () => setState(() => selected = row),
              ),
            ),
        ] else ...[
          ActionButton(
            'Back to incoming requests',
            busy
                ? null
                : () => setState(() {
                    selected = null;
                    quoting = false;
                    mutationError = null;
                  }),
            secondary: true,
          ),
          Panel(
            child: Column(
              children: [
                const SectionTitle('Request details'),
                InfoRow(
                  'Vehicle',
                  "${invitation['vehicle']['make']} ${invitation['vehicle']['model']}",
                ),
                InfoRow(
                  'Service area',
                  invitation['service']['area'] as String,
                ),
                if (invitation['distanceMetres'] case final num metres)
                  InfoRow('Geographic distance', "${metres.round()} m"),
                if (invitation['scheduledStart'] case final String start)
                  InfoRow('Appointment starts', start),
                InfoRow(
                  'Respond by',
                  DateTime.parse(
                    invitation['expiresAt'] as String,
                  ).toLocal().toString().split('.').first,
                ),
                InfoRow('Status', statusLabel(invitation['status'])),
                Text(invitation['issue'] as String),
              ],
            ),
          ),
          if (invitation['quotation'] case final Json quote) ...[
            quotePanel(quote),
            if (quote['status'] == 'PENDING')
              ActionButton(
                'Withdraw quotation',
                busy
                    ? null
                    : () => change('quotations/${quote['id']}/withdraw'),
                secondary: true,
              ),
          ],
          if (openRequestStatuses.contains(invitation['requestStatus']) &&
              DateTime.parse(
                invitation['expiresAt'] as String,
              ).isAfter(DateTime.now()) &&
              ['PENDING', 'QUOTED'].contains(invitation['status'])) ...[
            if (quoting)
              _QuotationForm(
                key: ValueKey(invitation['id']),
                busy: busy,
                onSubmit: (value) => change(
                  'service-requests/${invitation['requestId']}/quotations',
                  payload: value,
                ),
              )
            else
              ActionButton(
                invitation['quotation'] == null
                    ? 'Prepare quotation'
                    : 'Replace quotation',
                busy ? null : () => setState(() => quoting = true),
              ),
            if (invitation['status'] == 'PENDING')
              ActionButton(
                'Decline invitation',
                busy
                    ? null
                    : () => change(
                        'mechanics/me/incoming-requests/${invitation['id']}/decline',
                      ),
                secondary: true,
              ),
          ],
        ],
      ],
    );
  }
}

class _QuotationForm extends StatefulWidget {
  const _QuotationForm({super.key, required this.busy, required this.onSubmit});
  final bool busy;
  final ValueChanged<Json> onSubmit;
  @override
  State<_QuotationForm> createState() => _QuotationFormState();
}

class _Charge {
  _Charge();
  final description = TextEditingController();
  final amount = TextEditingController();
  String category = 'CALL_OUT';
  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _QuotationFormState extends State<_QuotationForm> {
  static const categories = {
    'CALL_OUT': 'Call-out',
    'DIAGNOSTIC': 'Diagnostic',
    'LABOUR': 'Labour',
    'PARTS_ESTIMATE': 'Parts estimate',
    'OTHER': 'Other',
  };
  final charges = [_Charge()];
  final currency = TextEditingController();
  final notes = TextEditingController();
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    for (final charge in charges) {
      charge.dispose();
    }
    currency.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Panel(
      child: Column(
        spacing: Mechi.gap,
        children: [
          const SectionTitle('Itemised quotation'),
          MechiFormField(
            controller: currency,
            label: 'Currency code',
            maxLength: 3,
            validator: (value) =>
                RegExp(
                  r'^[A-Z]{3}$',
                ).hasMatch(value?.trim().toUpperCase() ?? '')
                ? null
                : 'Enter a three-letter currency code',
          ),
          for (final charge in charges) ...[
            SelectionField<String>(
              icon: LucideIcons.wrench,
              title: 'Charge category',
              options: categories.keys.toList(),
              value: charge.category,
              labelFor: (value) => categories[value]!,
              onChanged: (value) => charge.category = value,
            ),
            MechiFormField(
              controller: charge.description,
              label: 'Description',
              maxLength: 120,
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : 'Enter a description',
            ),
            MechiFormField(
              controller: charge.amount,
              label: 'Amount in minor units',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  RegExp(r'^[1-9][0-9]{0,8}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a positive whole number',
            ),
          ],
          ActionButton(
            'Add charge',
            widget.busy || charges.length == 12
                ? null
                : () => setState(() => charges.add(_Charge())),
            secondary: true,
          ),
          MechiFormField(
            controller: notes,
            label: 'Quotation notes (optional)',
            maxLength: 500,
          ),
          ActionButton(
            widget.busy ? 'Submitting…' : 'Submit quotation',
            widget.busy
                ? null
                : () {
                    if (!form.currentState!.validate()) return;
                    widget.onSubmit({
                      'currency': currency.text.trim().toUpperCase(),
                      if (notes.text.trim().isNotEmpty)
                        'notes': notes.text.trim(),
                      'items': [
                        for (final charge in charges)
                          {
                            'category': charge.category,
                            'description': charge.description.text.trim(),
                            'amountMinor': charge.amount.text.trim(),
                          },
                      ],
                    });
                  },
          ),
        ],
      ),
    ),
  );
}
