import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver untuk `flutter drive`.
///
/// Menyimpan setiap screenshot yang diminta test (`binding.takeScreenshot`)
/// ke folder `screenshots/` di host.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
