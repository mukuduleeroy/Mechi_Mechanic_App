# Design tokens

The project uses the supplied reference video samples to calibrate Mechi’s appearance. The estimates below are semantic choices informed by dominant pixel samples from compressed footage.

| Token | Value | Reference |
| --- | --- | --- |
| Action, route and success | `#1D5CFF` | Video3 Screen03 and Video2 Screen04 |
| Canvas | `#ECECF4` | Video1 Screen01 and Video2 Screen08, near observed `#EDEEF3` |
| Elevated surface | `#FFFFFF` | Video2 Screen08 and Screen15 |
| Ink | `#14141C` | Video1 Screen01 dark regions |
| Vehicle hero | `#22232E` | Video1 Screen01 and Video3 Screen01 |
| Secondary | `#616170` | Darkened relative to the specification estimate for readability |
| Divider | `#E5E5EC` | Specification estimate, also supported by neutral samples in Video2 Screen08 |
| Info and selected background | `#E9EFFF` | Video3 Screen05 progress accents |
| Warning and rating | `#996019` | Tuned from the rating accents in Video1 Screen13 |
| Error | `#B73646` | Tuned from the busy badges in Video1 Screen08 and Screen10 |
| Receipt and paper | `#080B1C`, `#FAF7FB` | Video2 Screen19 |
| Scrim | 60% dark ink | Video2 Screen15 and Video3 Screen05 |
| Map blocks | `#DCDAD6` | Video1 Screen02 through Screen09 |

The 390 × 844 baseline uses 16 px gutters, a 4/8 px spacing rhythm, 20 px cards, 14 px buttons, 28 px sheet corners, and a pill navigation container. Measurements are estimates normalized from the three crop sizes in the supplied data. The home hero, job dashboard and detail layout were composed for Mechi.

Display type is 28 px, screen and section titles are 16 px, and body type is 13 px. Inter and IBM Plex Mono are bundled for offline use, along with the Lucide icon font. Their license notices are in `assets/fonts`.

Route, sheet, and ring animation use a 300 ms baseline and receipt printing uses 900 ms. These are implementation estimates. Reduced-motion settings suppress custom route, ring, sheet, and receipt animations. The debug gallery is accessible through Profile.
