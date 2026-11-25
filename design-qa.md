# Mechi visual refinement

Final result: passed

Compared the supplied Mechi PNG and HTML with the iPhone 18 Pro simulator captures. The dashboard, discovery map, mechanic overview and reviews, summary, and receipt were also compared with the corresponding original frame crops. The Canva media link could not be resolved, so the local visual references guided this pass.

| Screen | iPhone simulator capture |
| --- | --- |
| Home dashboard | [Home](docs/screenshots/refinement/home.png) |
| Gradient discovery card | [Card detail](docs/screenshots/refinement/gradient-discovery-card.png) |
| Nearest mechanic map | [Discovery](docs/screenshots/refinement/discovery.png) |
| Mechanic overview | [Overview](docs/screenshots/refinement/overview.png) |
| Mechanic reviews | [Reviews](docs/screenshots/refinement/mechanic-reviews.png) |
| Review mechanic | [Write a review](docs/screenshots/refinement/write-review.png) |
| Service completion and payment | [Completion](docs/screenshots/refinement/completion.png) · [Payment](docs/screenshots/refinement/payment.png) |
| Receipt | [Receipt](docs/screenshots/refinement/receipt.png) |
| Official launch branding | [iOS splash](docs/screenshots/refinement/branding.png) |

The travel badge, marker positions, and route remain part of the rendered demo map. The discovery card uses one rounded clip and a white-to-transparent fade. The selected vehicle spans the dark-to-light boundary. Review averages, counts, and distribution come from stored reviews, so the number of cards differs from the concept. The demo uses bundled vehicle renders, schematic map geometry, initials where photographs are unavailable, and Inter typography. Registration and job status fill the dashboard metrics using available data.

The Flutter formatter and analyzer passed, six local tests passed, and the iPhone simulator completed the request-to-paid-receipt and review journey. The app has no authentication screens. The existing native launch assets already use the pitch logo.
