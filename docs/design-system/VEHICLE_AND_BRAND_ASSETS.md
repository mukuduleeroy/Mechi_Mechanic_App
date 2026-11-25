# Vehicle and brand assets

The dashboard resolves bundled renders by make, model, generation and year. An image-unavailable label covers other vehicles and image decode errors. It keeps the selected vehicle’s identity visible through the surrounding dashboard or job details. The image widget uses Flutter's decoded image cache.

The four transparent PNGs in [assets/vehicles](../../assets/vehicles/) were created with built-in image generation after the supplied Canva media link could not be resolved. They are generated representations of the corresponding vehicles.

| Asset | Generation brief |
| --- | --- |
| Toyota Corolla | Photorealistic studio product render, isolated transparent background, silver 2018 Toyota Corolla sedan, front three-quarter view facing left with full vehicle visible. Low camera, crisp studio lighting, premium dealership photography, tight horizontal crop, no text or props. |
| Honda Fit | Photorealistic studio product render, isolated transparent background, white 2017 Honda Fit hatchback, front three-quarter view facing left with full vehicle visible. Low camera, crisp studio lighting, premium dealership photography, tight horizontal crop, no text or props. |
| Ford Ranger | Photorealistic studio product render, isolated transparent background, graphite grey 2021 Ford Ranger double cab pickup, front three-quarter view facing left with full vehicle visible. Low camera, crisp studio lighting, premium dealership photography, tight horizontal crop, no text or props. |
| Map car | Photorealistic miniature silver sedan for a map marker, exact orthographic top-down view, nose pointing straight toward the top of the image, studio lighting, dark glazing and realistic body highlights. One whole car isolated tightly on genuinely transparent background, no props or text. |

## Expanded garage catalog

Choose **Vehicles → Browse catalog** to add a model from the gallery. In Add or Edit vehicle, **Choose a vehicle model** can fill in the make, model, and year, or you can enter them manually. The catalog recognizes familiar import names such as Mazda2/Demio, Mazda3/Axela, Jazz/Fit, HR-V/Vezel, NV350/Caravan, Prius c/Aqua, and Days/Dayz. Generation code and year distinguish body styles. The same generation render can represent multiple model years and trims. [Catalog contact sheet](../screenshots/vehicle-catalog.jpg)

| Model | Rendered generations |
| --- | --- |
| Mazda Demio and Axela | Demio DE and DJ, Axela BL and BM/BN |
| Mazda CX-3, CX-4 and CX-5 | CX-3 DK, CX-4, CX-5 KE and KF |
| Honda Fit and Vezel | Fit GD, GE/GP1, GK/GP5 and GR/GS, Vezel RU and RV |
| Nissan Caravan and Dayz | Caravan E25 and E26, Dayz B21W and B4 |
| Toyota Aqua | NHP10 and MXPK |

The new transparent PNGs in [assets/vehicles](../../assets/vehicles/) were made with the built-in image generation tool and cropped to fit the app. Each prompt used the respective model and example year from the catalog, with a pearl-white paint finish and this shared direction.

> Photorealistic dealership studio automotive render of one pearl white [model and generation]. Match the year and generation’s body design accurately. Full vehicle including wheels, low front three-quarter view showing front and side, nose toward left. Tight horizontal composition, clean edges, transparent alpha background, no ground or cast shadow, no captions, people, props or watermark.

The dashboard and Vehicles cards show the saved paint name and a bordered paint swatch. Pick from 12 presets or enter a custom name or six-digit hex colour. The paint swatch is an approximation. Vehicle renders use representative paint to identify body styles consistently. [Red paint dashboard example](../../test/goldens/vehicle-paint.png)

Manufacturer references informed the import names and model groupings. [Mazda lineup](https://www.mazda.com/content/dam/mazda/corporate/mazda-com/en/pdf/investors/library/integrated-report/backnumber/mazdaar17_e.pdf) · [Honda Fit and Vezel history](https://global.honda/en/about/history-digest/75years-history/chapter3/section2_7/) · [Nissan model history](https://www.nissan-global.com/EN/COMPANY/PROFILE/HERITAGE/2010/) · [Toyota Aqua launch](https://global.toyota/en/newsroom/toyota/35584064.html)

The [official Mechi lockup and transparent symbol](../../assets/branding/) are crops of the original orange-and-navy artwork embedded on the cover of the supplied investor pitch. The same symbol is used for the launcher icons and Android 12+ launch splash. The full lockup is used for the iOS launch screen and receipts.

The existing offline tracking simulation moves the mechanic along its original route with heading derived from direction of travel. The map also accepts projected position and heading updates through `trackingFix` for a future GPS source.
