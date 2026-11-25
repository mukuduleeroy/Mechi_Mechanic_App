import 'package:flutter_test/flutter_test.dart';
import 'package:mechi/features/assistance/domain.dart';
import 'package:mechi/features/garage/vehicle_image.dart';
import 'package:mechi/features/garage/vehicle_colour.dart';

void main() {
  test('vehicle renders resolve by model, year and available colour', () {
    const exact = Vehicle(
      'a',
      ' TOYOTA ',
      'Corolla',
      2018,
      'A',
      colour: 'Silver',
    );
    const alternateColour = Vehicle(
      'b',
      'Honda',
      'Fit',
      2017,
      'B',
      colour: 'Blue',
    );
    const unknownYear = Vehicle('c', 'Ford', 'Ranger', 1990, 'C');

    expect(
      VehicleImage.assetFor(exact),
      endsWith('toyota-corolla-2018-silver.png'),
    );
    expect(
      VehicleImage.assetFor(alternateColour),
      endsWith('honda-fit-2017-white.png'),
    );
    expect(VehicleImage.assetFor(unknownYear), isNull);
    expect(Vehicle.fromJson(exact.toJson()).colour, 'Silver');
    expect(Vehicle.fromJson(unknownYear.toJson()).colour, isNull);
  });
  test('matches Japanese import names and generation codes', () {
    const matches = [
      ('Mazda', 'Demio', 2009, 'demio-de'),
      ('Mazda', 'Mazda2', 2016, 'demio-dj'),
      ('Mazda', 'Mazda3', 2016, 'axela-bm'),
      ('Mazda', 'X3', 2018, 'cx3'),
      ('Mazda', 'CX-4', 2018, 'cx4'),
      ('Mazda', 'CX-5 KE', 2017, 'cx5-ke'),
      ('Honda', 'Fit GP1', 2013, 'fit-ge'),
      ('Honda', 'Fit GP5', 2017, 'honda-fit-2017-white'),
      ('Honda', 'HR-V', 2022, 'vezel-rv'),
      ('Nissan', 'NV350 Caravan', 2018, 'caravan-e26'),
      ('Toyota', 'Prius c', 2016, 'aqua-nhp10'),
      ('Nissan', 'Days', 2021, 'dayz-b4'),
    ];
    for (final (make, model, year, file) in matches) {
      expect(
        VehicleImage.assetFor(Vehicle('id', make, model, year, 'A')),
        endsWith('/$file.png'),
      );
    }
  });

  test(
    'paint swatches support presets, import colour descriptions and hex',
    () {
      expect(
        VehicleColours.swatch('Platinum Silver'),
        VehicleColours.presets['Silver'],
      );
      expect(
        VehicleColours.swatch(' graphite '),
        VehicleColours.presets['Grey'],
      );
      expect(VehicleColours.swatch('#a62032'), VehicleColours.presets['Red']);
      expect(VehicleColours.swatch('Custom pearl effect'), isNull);
    },
  );
}
