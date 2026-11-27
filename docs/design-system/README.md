# Mechi Design System

Use the public [Flutter entry point](../../lib/core/design_system/design_system.dart) for shared UI. Feature-specific views live beside their domain types. Screens connect these widgets to routing, controller state and real application data. The approved Flutter implementation and checked-in goldens are the visual reference. The pitch, frame samples and secondary screen references document design provenance.

## Foundations

| Foundation | Public API | Usage |
| --- | --- | --- |
| [Tokens and theme](../../lib/core/design_system/foundations/mechi.dart) | `Mechi.theme`, `MechiTypography.textTheme`, `Mechi` | Use the theme's semantic type roles for greetings, headings, body, captions and labels. Use the bundled Inter and IBM Plex Mono families, approved palette, gutters, control heights and radii. Use `Mechi.animate(context)` and `Mechi.curve` for custom motion. Receipt printing uses `Mechi.printMotion`. |
| [Icons](../../lib/core/design_system/lucide_icons.dart) and [assets](../../lib/core/design_system/assets.dart) | `LucideIcons`, `MechiIcons`, `MechiAssets`, `MechiLogo(height:, symbolOnly:)` | Use the bundled Lucide glyphs, original rating stars, front-facing SVG, realistic tracking car, full pitch lockup or standalone symbol. The native launcher and splash continue to use their existing bundled artwork. |
| [Responsive dimensions](../../lib/core/design_system/layouts/dashboard_dimensions.dart) | `DashboardDimensions(bounds, insets)` | Dashboard height budgets and navigation geometry adapt to safe-area constraints. Sections can grow and scroll when text wraps. |
| [Vehicle assets](../../lib/features/garage/vehicle_catalog.dart) | `VehicleCatalog.resolve`, `VehicleImage(vehicle, height:, placeholder:)` | Resolve the make, model, generation, year and paint with existing fallbacks. Vehicle paint colors represent user data. |

See [token values and provenance](DESIGN_TOKENS.md), the [reference mapping](REFERENCE_MAPPING.md), and [vehicle and brand assets](VEHICLE_AND_BRAND_ASSETS.md).

## Shared components

| Component and source | API and approved states | Current consumers |
| --- | --- | --- |
| [Page layout](../../lib/core/design_system/layouts/screen.dart) | `Screen(title:, onBack:, children:, footer:, backgroundColor:)` provides a safe-area, scrollable, keyboard-aware body and optional pinned actions. | Garage, Profile, History, Assistance, Job, Payment, Review and gallery. |
| [Page chrome](../../lib/core/design_system/components/page_chrome.dart) | `PageHeader(title:, onBack:)` and `BottomActionBar(child:)`. Header can omit the back action. | Standard page layout. |
| [Action button](../../lib/core/design_system/components/actions.dart) | `ActionButton(label, callback, secondary:, compact:)`. Null callback disables it. Compact uses the approved secondary style. | Standard footers, job history, vehicle and service forms. |
| [Surfaces and information](../../lib/core/design_system/components/surfaces.dart) | `Panel(child:, color:, padding:)`, `Panel.grouped(child:)`, `InfoRow(label, value, bold:)`. Grouped uses the compact selector and settings inset. | Garage, Profile, Assistance, review, job, payment and receipt. |
| [Form field](../../lib/core/design_system/components/form_field.dart) | `MechiFormField(controller:, label:, …)` supports validated single-line input and keyboard options. `MechiFormField.description` is the existing canvas multiline issue field. | Add/Edit Vehicle, Profile and Assistance. |
| Scheduling pickers | Use standard themed Material `showDatePicker` and `showTimePicker` from an approved settings row. Keep availability selection in `SelectionField`. | Home service date and Mechanic working-window boundaries. |
| [Secondary controls](../../lib/core/design_system/secondary_controls.dart) | `SectionTitle`, `IconBubble`, `SettingsRow(title:, icon:, subtitle:, trailing:, onTap:)`, `SegmentPicker<T>(options:, value:, onChanged:)`, `SelectionField<T>(options:, labelFor:, value:, onChanged:, validator:, …)`, `InformationNotice`. | Profile, History, Assistance and job screens. |
| [Feedback](../../lib/core/design_system/components/feedback.dart) | `ChipLabel(label, icon:, background:, ink:)`, `ProgressRing(progress, caption:)`. | Status and metadata throughout the app. Ring preview in gallery. |
| [Dashboard navigation](../../lib/core/design_system/components/dashboard_navigation.dart) | `DashboardNavigation(availableWidth:, onDestination:)` dispatches typed garage, history and profile destinations. Home stays selected on this approved dashboard variant. | Home. |

## Domain components

| Source | API and approved states | Current consumers |
| --- | --- | --- |
| [Dashboard](../../lib/features/garage/dashboard_components.dart) | `VehicleHero(vehicle:, customer:, height:, hasActiveJob:, onNotifications:)`, `DashboardMetric(icon, value, label)`, `DashboardActionCard(label, icon, action, primary:, height:)`, `DashboardMapCard(height:, mechanic:, title:, actionLabel:, onPressed:)`. | Home. |
| [Garage](../../lib/features/garage/vehicle_components.dart) | `RegisteredVehicleRow(vehicle:, selected:, onSelect:, onEdit:)`, composed with [VehicleImage](../../lib/features/garage/vehicle_image.dart), [VehicleColourLabel and PaintSwatch](../../lib/features/garage/vehicle_colour.dart). | Your Vehicles and shared vehicle rendering. |
| [Profile](../../lib/features/garage/profile_components.dart) | `ProfileHeader(name:, subtitle:)` derives initials from the supplied name. | Profile. |
| [Map](../../lib/features/assistance/demo_map.dart) | `DemoMap` accepts mechanics, selection, zoom, optional tracking fix and map context. `MapControls(onZoomIn:, onZoomOut:, onRecenter:)` disables unavailable zoom directions. Markers and route interpolation live with the map renderer. | Home preview, Nearest Mechanic, Mechanic Details, Service Tracking. |
| [Mechanic](../../lib/features/assistance/mechanic_components.dart) | `MechanicIdentity(mechanic)`, `MechanicPricingBar(callout:, onPressed:)`. Null callback disables quote action. | Discovery, Details, job completion and review. |
| [Reviews](../../lib/features/assistance/mechanic_reviews.dart) | `MechanicReviews(specialty:, records:, now:)`, `ReviewStars(rating)`, `RatingPicker(rating:, onChanged:)`. History and distributions come from supplied job records. Null callback disables editing. | Mechanic Details and Review. |
| [Job history and completion](../../lib/features/assistance/job_components.dart) | `JobHistoryCard(job:, onDetails:, onReceipt:)`, `serviceCompletionSections(context, job, mechanic)` for quoted, completed service data. | History and job completion. |
| [Payments and receipt](../../lib/features/assistance/payment_components.dart) | `CostPanel(quote)`, `PaymentMethodPicker(method:, onChanged:)`, `PaymentResultDialog(process:, amount:, method:, onReceipt:)`, `ServiceReceipt(job:, mechanicName:, date:, printCount:)`. Null callback disables selection. Dialog derives processing, failure and success from its future. Receipt needs a paid job with a method and quote. | Job, Payment and Receipt. |

## Usage

```dart
import 'package:mechi/core/design_system/design_system.dart';

Screen(
  title: 'Job history',
  onBack: onBack,
  footer: ActionButton('Done', onDone),
  children: [
    const SectionTitle('Past services'),
    const Panel(child: Text('No jobs match this filter.')),
  ],
);
```

Keep domain callbacks on the screen and pass them into the widget. Look for an approved role or component before adding styles. Feature-specific proportions and dynamic values belong with the component that renders them.

## Debug showcase

Open **Profile → Component gallery** in a debug build. The gallery opens manually and uses in-memory examples. The four sections preview common states, foundations, dashboard and vehicle components, and services. The payment dialog previews loading and result states. The service section allows rating, payment selection and zoom interaction. The gallery uses the same responsive layout and production widgets. It is excluded from production routes and menus.

## Changes and verification

Follow the [repository policy](../../AGENTS.md). Run `flutter analyze` and `flutter test`. Use existing golden references for visual regression checks. The integration suite covers the customer journey and vehicle catalog.

The [style guard](../../test/design_system_policy_test.dart) runs with `flutter test`. It flags growth in raw color, icon, typography, decoration, radius and spacing patterns in feature screen files. The [allowances](../../test/design_system_style_allowances.json) record existing screen-specific geometry and styling, including map overlays, receipt chrome and inline dialog layout. It is a source check scoped to screen files and does not validate rendered output. Prefer existing tokens and components. When removing an allowance, reduce its count. Add an allowance only for an approved exception and document why the existing system cannot represent it.
