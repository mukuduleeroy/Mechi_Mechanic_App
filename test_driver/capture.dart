import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, image, [args]) async {
    final folder = Directory('docs/screenshots/refinement');
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(image);
    return true;
  },
);
