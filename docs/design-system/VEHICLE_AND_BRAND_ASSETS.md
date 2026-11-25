# Vehicle and brand assets

The dashboard resolves bundled renders by make, model, year and colour. If the requested colour is unavailable, it uses the bundled colour for the same make, model and year. An image-unavailable label covers other vehicles and image decode errors. It keeps the selected vehicle’s identity visible through the surrounding dashboard or job details. The image widget uses Flutter's decoded image cache.

The four transparent PNGs in [assets/vehicles](../../assets/vehicles/) were created with built-in image generation after the supplied Canva media link could not be resolved. They are generated representations of the corresponding vehicles.

| Asset | Generation brief |
| --- | --- |
| Toyota Corolla | Photorealistic studio product render, isolated transparent background, silver 2018 Toyota Corolla sedan, front three-quarter view facing left with full vehicle visible. Low camera, crisp studio lighting, premium dealership photography, tight horizontal crop, no text or props. |
| Honda Fit | Photorealistic studio product render, isolated transparent background, white 2017 Honda Fit hatchback, front three-quarter view facing left with full vehicle visible. Low camera, crisp studio lighting, premium dealership photography, tight horizontal crop, no text or props. |
| Ford Ranger | Photorealistic studio product render, isolated transparent background, graphite grey 2021 Ford Ranger double cab pickup, front three-quarter view facing left with full vehicle visible. Low camera, crisp studio lighting, premium dealership photography, tight horizontal crop, no text or props. |
| Map car | Photorealistic miniature silver sedan for a map marker, exact orthographic top-down view, nose pointing straight toward the top of the image, studio lighting, dark glazing and realistic body highlights. One whole car isolated tightly on genuinely transparent background, no props or text. |

The [official Mechi lockup and transparent symbol](../../assets/branding/) are crops of the original orange-and-navy artwork embedded on the cover of the supplied investor pitch. The same symbol is used for the launcher icons and Android 12+ launch splash. The full lockup is used for the iOS launch screen and receipts.

The existing offline tracking simulation moves the mechanic along its original route with heading derived from direction of travel. The map also accepts projected position and heading updates through `trackingFix` for a future GPS source.
