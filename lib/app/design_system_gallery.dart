import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design_system/design_system.dart';
import '../features/assistance/demo_map.dart';
import '../features/assistance/domain.dart';
import '../features/assistance/job_components.dart';
import '../features/assistance/mechanic_components.dart';
import '../features/assistance/mechanic_reviews.dart';
import '../features/assistance/payment_components.dart';
import '../features/garage/dashboard_components.dart';
import '../features/garage/profile_components.dart';
import '../features/garage/vehicle_colour.dart';
import '../features/garage/vehicle_components.dart';

/// Manually opened from Profile in debug builds. Uses local, in-memory examples.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const vehicle = Vehicle(
    'gallery',
    'BMW',
    'i8',
    2018,
    'SAMPLE',
    colour: 'White',
  );
  static const mechanic = Mechanic(
    1,
    'Sample Mechanic',
    'Harare CBD',
    'Roadside assistance',
    4.9,
    3.5,
    12,
    8,
    1500,
  );
  static const quote = Quote(1500, 600, 1500, 'Replaced valve', 'Valve');
  static final example = Job(
    id: 'SAMPLE',
    date: DateTime(2026, 1, 1),
    request: const ServiceRequest(
      Service.roadside,
      'Flat tyre',
      '',
      vehicle,
      'Harare CBD',
    ),
    status: JobStatus.reviewed,
    method: PaymentMethod.cash,
    quote: quote,
    rating: 4,
    review: 'Sample review for the component gallery.',
  );

  final field = TextEditingController();
  final description = TextEditingController();
  var section = 0;
  var rating = 3;
  var payment = PaymentMethod.ecoCash;
  String? colour;
  var zoom = 1.0;

  @override
  void dispose() {
    field.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Screen(
    title: 'Component gallery',
    onBack: context.pop,
    children: [
      SegmentPicker<int>(
        options: const [
          (value: 0, label: 'Common', icon: null),
          (value: 1, label: 'Foundations', icon: null),
          (value: 2, label: 'Garage', icon: null),
          (value: 3, label: 'Services', icon: null),
        ],
        value: section,
        onChanged: (value) => setState(() => section = value),
      ),
      ...switch (section) {
        1 => _foundations(context),
        2 => _garage(),
        3 => _services(),
        _ => _common(),
      },
    ],
  );

  List<Widget> _common() => [
    ActionButton('Primary action', () {}),
    ActionButton('Secondary action', () {}, secondary: true),
    const ActionButton('Disabled', null),
    const Panel(
      child: Column(
        children: [
          ChipLabel('Verified · Demo', icon: LucideIcons.badgeCheck),
          InfoRow('Total', '\$36.00', bold: true),
          ProgressRing(.5, caption: 'Repair progress'),
        ],
      ),
    ),
    ActionButton('Compact secondary', () {}, secondary: true, compact: true),
    const SectionTitle('Forms and feedback'),
    const ProfileHeader(
      name: 'Sample driver',
      subtitle: 'Harare · Fictional demo account',
    ),
    Panel(
      child: Column(
        children: [
          SettingsRow(
            icon: LucideIcons.car,
            title: 'Your vehicles',
            onTap: () {},
          ),
          SelectionField<String>(
            icon: LucideIcons.car,
            title: 'Paint colour',
            options: const ['White', 'Silver', 'Red'],
            labelFor: (value) => value,
            value: colour,
            onChanged: (value) => setState(() => colour = value),
          ),
          MechiFormField(controller: field, label: 'Vehicle model'),
          MechiFormField.description(
            controller: description,
            label: 'Describe the issue',
          ),
        ],
      ),
    ),
    const InformationNotice('Device location is unavailable in this demo.'),
    const Panel(child: Text('No jobs match this filter.')),
    for (final succeeds in [true, false])
      ActionButton(
        succeeds ? 'Payment success preview' : 'Payment error preview',
        () => showDialog<void>(
          context: context,
          barrierColor: Mechi.scrim,
          barrierDismissible: false,
          builder: (_) => PaymentResultDialog(
            process: () async {
              await Future<void>.delayed(Mechi.printMotion);
              return succeeds;
            },
            amount: usd(quote.total),
            method: payment,
            onReceipt: () => setState(() => section = 3),
          ),
        ),
      ),
  ];

  List<Widget> _foundations(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return [
      const SectionTitle('Colour'),
      Panel(
        child: Column(
          children: [
            for (final (label, colour) in const [
              ('Navy', Mechi.navy),
              ('White', Mechi.white),
              ('Canvas', Mechi.canvas),
              ('Ink', Mechi.ink),
              ('Muted', Mechi.muted),
              ('Divider', Mechi.line),
              ('Pale', Mechi.pale),
              ('Paper', Mechi.paper),
              ('Error', Mechi.error),
              ('Rating', Mechi.star),
              ('Hero', Mechi.hero),
              ('Scrim', Mechi.scrim),
              ('Map grid', Mechi.grid),
              ('Map park', Mechi.park),
              ('Map arterial', Mechi.arterial),
            ])
              Row(
                children: [
                  Icon(Icons.square, color: colour, semanticLabel: label),
                  const SizedBox(width: Mechi.gap),
                  Text(label),
                ],
              ),
          ],
        ),
      ),
      const SectionTitle('Typography'),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard greeting', style: type.headlineMedium),
            Text('Page heading', style: type.titleLarge),
            Text('Section heading', style: type.titleMedium),
            Text('Body text', style: type.bodyMedium),
            Text('Caption', style: type.bodySmall),
            Text('Action label', style: type.labelLarge),
          ],
        ),
      ),
      const SectionTitle('Spacing and radius'),
      const Panel(
        child: Column(
          children: [
            InfoRow('Base gap', '${Mechi.gap} dp'),
            InfoRow('Page inset', '${Mechi.pad} dp'),
            InfoRow('Page item gap', '${Mechi.pageItemGap} dp'),
            InfoRow('Card radius', '${Mechi.radius} dp'),
            InfoRow('Control radius', '${Mechi.controlRadius} dp'),
            InfoRow('Sheet radius', '${Mechi.sheetRadius} dp'),
            InfoRow('Pill radius', '${Mechi.pillRadius} dp'),
          ],
        ),
      ),
      const SectionTitle('Icons and branding'),
      const Panel(
        child: Column(
          children: [
            MechiLogo(height: 44),
            MechiLogo(height: 28, symbolOnly: true),
            Wrap(
              spacing: Mechi.gap,
              children: [
                IconBubble(LucideIcons.bell),
                IconBubble(LucideIcons.arrowLeft),
                IconBubble(LucideIcons.chevronRight),
                IconBubble(LucideIcons.pencil),
                IconBubble(LucideIcons.history),
                IconBubble(LucideIcons.mapPin),
                IconBubble(LucideIcons.map),
                IconBubble(LucideIcons.navigation),
                IconBubble(LucideIcons.wrench),
                IconBubble(LucideIcons.batteryCharging),
                IconBubble(LucideIcons.thermometer),
                IconBubble(LucideIcons.shieldCheck),
                IconBubble(LucideIcons.creditCard),
                IconBubble(LucideIcons.printer),
                IconBubble(LucideIcons.user),
                IconBubble(LucideIcons.star),
                IconBubble(LucideIcons.checkCircle2),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _garage() => [
    const SectionTitle('Dashboard and vehicle components'),
    LayoutBuilder(
      builder: (context, bounds) {
        final view = MediaQuery.sizeOf(context);
        final dimensions = DashboardDimensions(
          BoxConstraints.tightFor(width: bounds.maxWidth, height: view.height),
          MediaQuery.paddingOf(context),
        );
        return Column(
          children: [
            VehicleHero(
              vehicle: vehicle,
              customer: 'Sample driver',
              height: dimensions.heroHeight,
              hasActiveJob: true,
              onNotifications: () {},
            ),
            DashboardNavigation(
              availableWidth: bounds.maxWidth,
              onDestination: (_) {},
            ),
            DashboardMapCard(
              height: dimensions.mapHeight,
              mechanic: mechanic,
              title: 'Find closest mechanics',
              actionLabel: 'Request assistance',
              onPressed: () {},
            ),
            const DashboardMetric(
              LucideIcons.clock,
              '12 min',
              'Nearest mechanic',
            ),
            Row(
              spacing: Mechi.gap,
              children: [
                Expanded(
                  child: DashboardActionCard(
                    'Breakdown',
                    LucideIcons.wrench,
                    () {},
                    height: dimensions.quickHeight,
                    primary: true,
                  ),
                ),
                Expanded(
                  child: DashboardActionCard(
                    'Book service',
                    LucideIcons.clock,
                    () {},
                    height: dimensions.quickHeight,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
    Panel(
      child: RegisteredVehicleRow(
        vehicle: vehicle,
        selected: true,
        onSelect: () {},
        onEdit: () {},
      ),
    ),
    const VehicleColourLabel('White'),
  ];

  List<Widget> _services() => [
    const SectionTitle('Mechanics and map'),
    const Panel(child: MechanicIdentity(mechanic)),
    SizedBox(
      height: 200,
      child: DemoMap(
        mechanics: const [mechanic],
        selected: mechanic.id,
        zoom: zoom,
      ),
    ),
    MapControls(
      onZoomIn: zoom < 1.5 ? () => setState(() => zoom += .25) : null,
      onZoomOut: zoom > 1 ? () => setState(() => zoom -= .25) : null,
      onRecenter: () => setState(() => zoom = 1),
    ),
    MechanicPricingBar(callout: mechanic.callout, onPressed: () {}),
    const SectionTitle('Reviews'),
    MechanicReviews(
      specialty: mechanic.specialty,
      records: [example],
      now: example.date,
    ),
    const ReviewStars(4),
    RatingPicker(
      rating: rating,
      onChanged: (value) => setState(() => rating = value),
    ),
    const RatingPicker(rating: 3, onChanged: null),
    const SectionTitle('Jobs and payments'),
    JobHistoryCard(job: example, onDetails: () {}, onReceipt: () {}),
    ...serviceCompletionSections(context, example, mechanic),
    PaymentMethodPicker(
      method: payment,
      onChanged: (value) => setState(() => payment = value),
    ),
    PaymentMethodPicker(method: payment, onChanged: null),
    ServiceReceipt(
      job: example,
      mechanicName: mechanic.name,
      date: '2026-01-01',
      printCount: 0,
    ),
    BottomActionBar(child: ActionButton('Done', () {})),
  ];
}
