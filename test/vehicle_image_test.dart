import 'package:flutter_test/flutter_test.dart';
import 'package:mechi/features/assistance/domain.dart';
import 'package:mechi/features/garage/vehicle_image.dart';

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
}
