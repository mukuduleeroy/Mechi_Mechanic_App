import '../assistance/domain.dart';

typedef VehicleRender = ({
  String make,
  String model,
  String generation,
  int firstYear,
  int lastYear,
  int sampleYear,
  String file,
});

abstract final class VehicleCatalog {
  static const renders = <VehicleRender>[
    (
      make: 'Mazda',
      model: 'Demio',
      generation: 'DE',
      firstYear: 2007,
      lastYear: 2014,
      sampleYear: 2009,
      file: 'demio-de',
    ),
    (
      make: 'Mazda',
      model: 'Demio',
      generation: 'DJ',
      firstYear: 2014,
      lastYear: 2030,
      sampleYear: 2016,
      file: 'demio-dj',
    ),
    (
      make: 'Mazda',
      model: 'Axela',
      generation: 'BL',
      firstYear: 2009,
      lastYear: 2013,
      sampleYear: 2011,
      file: 'axela-bl',
    ),
    (
      make: 'Mazda',
      model: 'Axela',
      generation: 'BM / BN',
      firstYear: 2013,
      lastYear: 2019,
      sampleYear: 2016,
      file: 'axela-bm',
    ),
    (
      make: 'Mazda',
      model: 'CX-3',
      generation: 'DK',
      firstYear: 2015,
      lastYear: 2030,
      sampleYear: 2018,
      file: 'cx3',
    ),
    (
      make: 'Mazda',
      model: 'CX-4',
      generation: '',
      firstYear: 2016,
      lastYear: 2030,
      sampleYear: 2018,
      file: 'cx4',
    ),
    (
      make: 'Mazda',
      model: 'CX-5',
      generation: 'KE',
      firstYear: 2012,
      lastYear: 2017,
      sampleYear: 2014,
      file: 'cx5-ke',
    ),
    (
      make: 'Mazda',
      model: 'CX-5',
      generation: 'KF',
      firstYear: 2017,
      lastYear: 2025,
      sampleYear: 2020,
      file: 'cx5-kf',
    ),
    (
      make: 'Honda',
      model: 'Fit',
      generation: 'GD',
      firstYear: 2001,
      lastYear: 2007,
      sampleYear: 2005,
      file: 'fit-gd',
    ),
    (
      make: 'Honda',
      model: 'Fit',
      generation: 'GE / GP1',
      firstYear: 2007,
      lastYear: 2013,
      sampleYear: 2010,
      file: 'fit-ge',
    ),
    (
      make: 'Honda',
      model: 'Fit',
      generation: 'GK / GP5',
      firstYear: 2013,
      lastYear: 2020,
      sampleYear: 2017,
      file: 'honda-fit-2017-white',
    ),
    (
      make: 'Honda',
      model: 'Fit',
      generation: 'GR / GS',
      firstYear: 2020,
      lastYear: 2030,
      sampleYear: 2021,
      file: 'fit-gr',
    ),
    (
      make: 'Honda',
      model: 'Vezel',
      generation: 'RU',
      firstYear: 2013,
      lastYear: 2021,
      sampleYear: 2016,
      file: 'vezel-ru',
    ),
    (
      make: 'Honda',
      model: 'Vezel',
      generation: 'RV',
      firstYear: 2021,
      lastYear: 2030,
      sampleYear: 2022,
      file: 'vezel-rv',
    ),
    (
      make: 'Nissan',
      model: 'Caravan',
      generation: 'E25',
      firstYear: 2001,
      lastYear: 2012,
      sampleYear: 2007,
      file: 'caravan-e25',
    ),
    (
      make: 'Nissan',
      model: 'Caravan',
      generation: 'E26',
      firstYear: 2012,
      lastYear: 2030,
      sampleYear: 2018,
      file: 'caravan-e26',
    ),
    (
      make: 'Toyota',
      model: 'Aqua',
      generation: 'NHP10',
      firstYear: 2011,
      lastYear: 2021,
      sampleYear: 2015,
      file: 'aqua-nhp10',
    ),
    (
      make: 'Toyota',
      model: 'Aqua',
      generation: 'MXPK',
      firstYear: 2021,
      lastYear: 2030,
      sampleYear: 2022,
      file: 'aqua-mxpk',
    ),
    (
      make: 'Nissan',
      model: 'Dayz',
      generation: 'B21W',
      firstYear: 2013,
      lastYear: 2019,
      sampleYear: 2015,
      file: 'dayz-b21w',
    ),
    (
      make: 'Nissan',
      model: 'Dayz',
      generation: 'B4',
      firstYear: 2019,
      lastYear: 2030,
      sampleYear: 2021,
      file: 'dayz-b4',
    ),
    (
      make: 'Toyota',
      model: 'Corolla',
      generation: '',
      firstYear: 2018,
      lastYear: 2018,
      sampleYear: 2018,
      file: 'toyota-corolla-2018-silver',
    ),
    (
      make: 'Ford',
      model: 'Ranger',
      generation: '',
      firstYear: 2021,
      lastYear: 2021,
      sampleYear: 2021,
      file: 'ford-ranger-2021-graphite',
    ),
  ];

  static final _chassisSuffix = RegExp(r'^[0-9]+[a-z]?$');

  static String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static VehicleRender? resolve(Vehicle vehicle) {
    final make = normalize(vehicle.make);
    var model = normalize(vehicle.model);
    if (make.isNotEmpty && model.startsWith(make)) {
      model = model.substring(make.length);
    }
    model = switch ((make, model)) {
      ('mazda', 'mazda2' || '2') => 'demio',
      ('mazda', 'mazda3' || '3') => 'axela',
      ('mazda', 'x3') => 'cx3',
      ('mazda', 'x4') => 'cx4',
      ('mazda', 'x5') => 'cx5',
      ('honda', 'jazz' || 'fithybrid' || 'jazzhybrid') => 'fit',
      ('honda', 'hrv' || 'vezelhybrid' || 'vezelehev') => 'vezel',
      ('nissan', 'nv350' || 'nv350caravan' || 'urvan' || 'nv350urvan') =>
        'caravan',
      ('toyota', 'priusc') => 'aqua',
      ('nissan', 'days' || 'dayzhighwaystar' || 'dayshighwaystar') => 'dayz',
      _ => model,
    };
    VehicleRender? match;
    for (final render in renders) {
      if (normalize(render.make) != make) continue;
      final base = normalize(render.model);
      final generations = render.generation.split('/').map(normalize);
      if (generations.any((code) {
        if (code.isEmpty) return false;
        final prefix = '$base$code';
        return model == prefix ||
            (model.startsWith(prefix) &&
                _chassisSuffix.hasMatch(model.substring(prefix.length)));
      })) {
        return render;
      }
      if (model != base ||
          vehicle.year < render.firstYear ||
          vehicle.year > render.lastYear) {
        continue;
      }
      if (match == null || render.firstYear > match.firstYear) match = render;
    }
    return match;
  }

  static String assetPath(VehicleRender render) =>
      'assets/vehicles/${render.file}.png';
}
