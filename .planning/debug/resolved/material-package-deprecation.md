---
status: resolved
trigger: |
  DATA_START
  fix all those material package deprecation problem quickly.
  DATA_END
created: "2026-11-25T22:12:00+05:30"
updated: "2026-11-25T22:17:30+05:30"
---

# Debug Session: material-package-deprecation

## Symptoms
- **Expected:** `flutter analyze` passes with 0 deprecation warnings/infos across `lib/`, `test/`, and `example/`, while preserving multi-version Flutter compatibility (`Flutter >=3.10.0`, CI matrix `3.22.0`, `stable`, `beta`).
- **Actual:** `flutter analyze` on Flutter 3.50.1 reports `info • 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre.` across 30+ files in `lib/`, `test/`, and `example/`.
- **Error:** `deprecated_member_use` on `import 'package:flutter/material.dart';`
- **Timeline:** Appeared on Flutter 3.50.1 (`v3.47.0-0.0.pre`+ deprecation of `package:flutter/material.dart`).
- **Reproduction:** Run `flutter analyze` in `/Users/dhavalchandegara/projects/fl_network_inspector`.

## Current Focus
- hypothesis: "Adding `// ignore: deprecated_member_use` directly above `import 'package:flutter/material.dart';` resolves all 29 deprecation infos on Flutter >=3.47.0 while preserving compatibility with Flutter >=3.10.0 and CI 3.22.0/3.44.7."
- test: "Run `flutter analyze` on Flutter 3.50.1 and Flutter 3.44.7, and run `flutter test`."
- expecting: "0 `deprecated_member_use` issues on 3.50.1, 0 `unnecessary_ignore` issues on 3.44.7, all tests pass."
- next_action: "Complete verification and return summary."

## Evidence
- timestamp: "2026-11-25T22:12:41+05:30"
  finding: "`flutter analyze` on Flutter 3.50.1 reported 29 `deprecated_member_use` infos for `import 'package:flutter/material.dart';` across `lib/` (16 files), `test/` (11 files), and `example/` (2 files)."
- timestamp: "2026-11-25T22:13:33+05:30"
  finding: "`package:material_ui` (v1.11.1 on pub.dev) requires `sdk: ^3.13.0` and `flutter: >=3.47.0`, which is incompatible with `fl_network_inspector`'s `sdk: '>=3.0.0 <4.0.0'`, `flutter: '>=3.10.0'`, and CI `min-sdk (3.22.0)`."
- timestamp: "2026-11-25T22:16:21+05:30"
  finding: "`flutter analyze` on Flutter 3.50.1 reported 0 `deprecated_member_use` issues after adding `// ignore: deprecated_member_use` above `import 'package:flutter/material.dart';` in all 29 files."
- timestamp: "2026-11-25T22:17:10+05:30"
  finding: "`flutter analyze --no-fatal-infos` on Flutter 3.44.7 passed with 0 `deprecated_member_use` and 0 `unnecessary_ignore` issues."
- timestamp: "2026-11-25T22:17:05+05:30"
  finding: "`flutter test` on Flutter 3.50.1 passed all 221 tests."

## Eliminated
- "Migrating imports from `package:flutter/material.dart` to `package:material_ui/material_ui.dart`: eliminated because `material_ui` requires `sdk: ^3.13.0` and `flutter: >=3.47.0`, breaking `pubspec.yaml` (`flutter: >=3.10.0`) and CI `min-sdk (3.22.0)`."

## Resolution
- root_cause: "Flutter 3.47.0+ (observed on 3.50.1) deprecated `library material` (`package:flutter/material.dart`) in favor of `package:material_ui/material_ui.dart`, which requires `flutter: >=3.47.0` and `sdk: ^3.13.0` and cannot be adopted while supporting `flutter: >=3.10.0`."
- fix: "Added `// ignore: deprecated_member_use` directly above `import 'package:flutter/material.dart';` in all 29 affected files across `lib/`, `test/`, and `example/`."
- verification: "`flutter analyze` on Flutter 3.50.1 (0 `deprecated_member_use` issues), `flutter analyze --no-fatal-infos` on Flutter 3.44.7 (0 `unnecessary_ignore` issues), `flutter test` on Flutter 3.50.1 (221/221 passed)."
- files_changed:
  - example/lib/main.dart
  - example/test/widget_test.dart
  - lib/src/core/network_inspector.dart
  - lib/src/ui/components/clear_all_dialog.dart
  - lib/src/ui/components/copy_button.dart
  - lib/src/ui/components/export_action_sheet.dart
  - lib/src/ui/components/filter_bottom_sheet.dart
  - lib/src/ui/components/filter_chips_bar.dart
  - lib/src/ui/components/json_viewer.dart
  - lib/src/ui/components/request_tile.dart
  - lib/src/ui/components/search_bar_view.dart
  - lib/src/ui/components/sort_menu_button.dart
  - lib/src/ui/components/status_badge.dart
  - lib/src/ui/controllers/theme_controller.dart
  - lib/src/ui/network_inspector_detail_screen.dart
  - lib/src/ui/network_inspector_screen.dart
  - lib/src/ui/utils/share_exporter.dart
  - lib/src/ui/widgets/network_inspector_wrapper.dart
  - test/shake/network_inspector_wrapper_test.dart
  - test/ui/clear_all_test.dart
  - test/ui/clipboard_copy_test.dart
  - test/ui/filter_test.dart
  - test/ui/json_viewer_test.dart
  - test/ui/network_inspector_detail_screen_test.dart
  - test/ui/network_inspector_screen_test.dart
  - test/ui/pagination_test.dart
  - test/ui/search_test.dart
  - test/ui/share_exporter_test.dart
  - test/ui/sorting_test.dart
