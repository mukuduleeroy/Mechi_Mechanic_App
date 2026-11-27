# Phase 06 connected iPhone simulator captures

The connected journey uses synthetic Firebase identities, a registered vehicle and isolated PostGIS coverage. One simulator runs the Driver and Mechanic workspaces sequentially. A separate authenticated Mechanic REST client supplies the second offer. The approved demo goldens remain the visual regression baseline.

## Driver

- [Assistance request](01-driver-assistance.png)
- [Searching for mechanics](02-driver-searching.png)
- [No mechanic available](03-driver-no-mechanic.png)
- [Available quotations](04-driver-offers.png)
- [Quotation details](05-driver-quotation-details.png)
- [Acceptance confirmation](06-driver-acceptance-confirmation.png)
- [Confirmed assignment](07-driver-assignment.png)

## Mechanic

- [Incoming requests](08-mechanic-incoming.png)
- [Request details](09-mechanic-request-details.png)
- [Itemised quotation](10-mechanic-quote-form.png)
- [Pending quotation](11-mechanic-pending-quote.png)
- [Confirmed assignment](12-mechanic-assignment.png)

The backend's `scripts/test-marketplace-ios.sh` regenerates these captures when `MECHI_SCREENSHOT_DIR` points to this directory.
