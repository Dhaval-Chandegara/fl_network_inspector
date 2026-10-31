import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform Safety (CORE-03)', () {
    test('enforces zero dart:io imports in lib/src/ foundational layers', () {
      final srcDir = Directory('lib/src');
      if (!srcDir.existsSync()) {
        // If directory doesn't exist yet, there are no violations
        return;
      }

      final dartFiles = srcDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      final forbiddenImportPattern = RegExp(
        r'''^\s*import\s+['"]dart:io['"]''',
        multiLine: true,
      );

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (forbiddenImportPattern.hasMatch(content)) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found forbidden dart:io imports in lib/src/ files: $violations. '
            'Foundational models, config, core, and utils must be pure Dart '
            'to ensure cross-platform compatibility with Flutter Web and Desktop.',
      );
    });
  });
}
