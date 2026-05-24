import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Kotlin classes use the configured app namespace', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final namespace = RegExp(
      r'namespace\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)?.group(1);

    expect(namespace, isNotNull);

    final kotlinFiles = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'));

    for (final file in kotlinFiles) {
      final source = file.readAsStringSync();
      final declaredPackage = RegExp(
        r'^package\s+([^\s]+)',
        multiLine: true,
      ).firstMatch(source)?.group(1);

      expect(
        declaredPackage,
        namespace,
        reason: '${file.path} must resolve from AndroidManifest relative names',
      );
    }
  });
}
