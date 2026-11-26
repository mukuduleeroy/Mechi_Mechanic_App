# Mechi repository instructions

## Design system first

Before implementing or changing UI, read the [Mechi Design System README and component catalogue](docs/design-system/README.md). Search the [shared Flutter library](lib/core/design_system/design_system.dart) and the domain components listed in the catalogue before writing a widget.

1. Identify the approved components, layout patterns and semantic tokens that cover the requested screen.
2. Compose the screen from those components. Keep routing, persistence and service calls in the feature layer.
3. Preserve approved responsive behavior, typography, icons, spacing, imagery, colors, transitions and interaction states. The latest approved Mechi implementation takes priority over older references.
4. Verify consistency at supported viewport sizes, with scaled text and a visible keyboard where applicable. Run analysis, existing tests and relevant goldens.

Get explicit approval from the user before adding or changing a visual component, variant, token, style or layout pattern. Explain the missing capability, why existing components cannot cover it, and the smallest proposed extension. This applies to card and button styles, inputs, typography, colors, icon styles, spacing, radii, shadows, gradients and navigation. Never redesign an existing screen unless instructed.

Private feature composition widgets may arrange approved components without adding styling. Business logic and controllers can be introduced for requested features, with presentation built from the approved system. Keep the component catalogue current and use the debug-only gallery to verify states. Changes to the style allowances require an approved, documented exception.
