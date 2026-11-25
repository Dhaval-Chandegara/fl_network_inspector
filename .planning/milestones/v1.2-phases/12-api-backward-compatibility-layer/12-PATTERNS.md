# Phase 12: API & Backward Compatibility Layer - Pattern Map

**Mapped:** 2026-11-21  
**Files analyzed:** 10  
**Analogs found:** 9 / 10  

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/src/ui/utils/share_exporter.dart` | utility | presentation / request-response | `lib/src/ui/utils/share_exporter.dart` | exact |
| `lib/src/shake/shake_detector.dart` | service / listener | event-driven | `lib/src/shake/shake_detector.dart` | exact |
| `lib/src/storage/platform/ffi_init_io.dart` | config / adapter | initialization / request-response | `lib/src/storage/platform/ffi_init_io.dart` | exact |
| `pubspec.yaml` | config | static / declarative | `pubspec.yaml` | exact |
| `lib/src/ui/components/filter_bottom_sheet.dart` | component / UI | presentation / user interaction | `lib/src/ui/components/filter_bottom_sheet.dart` | exact |
| `tool/verify_lowest_bounds.sh` | utility / DevOps script | batch / CLI pipeline | *(None — see No Analog Found)* | none |
| `test/ui/share_exporter_test.dart` | test | verification / widget testing | `test/ui/share_exporter_test.dart` | exact |
| `test/shake/shake_detector_test.dart` | test | verification / stream testing | `test/shake/shake_detector_test.dart` | exact |
| `test/storage/database_schema_test.dart` | test | verification / DB query | `test/storage/database_schema_test.dart` | exact |
| `test/storage/database_harness_test.dart` | test | verification / DB query | `test/storage/database_harness_test.dart` | exact |

---

## Pattern Assignments

### `lib/src/ui/utils/share_exporter.dart` (utility, presentation / request-response)

**Analog:** `lib/src/ui/utils/share_exporter.dart`  
**Git Tracked:** Yes (`lib/src/ui/utils/share_exporter.dart`)

**Imports Pattern** (lines 1-7):
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/network_record.dart';
import 'curl_generator.dart';
```

**Guard / Sanitization Pattern (D-03)**:
```dart
/// Safely sanitizes [origin] to ensure it has finite, positive dimensions (D-03).
///
/// If invalid or unmounted, expands to a safe 1x1 point rect at the screen center.
static Rect sanitizeOrigin(Rect? origin, BuildContext context) {
  if (origin != null &&
      origin.isFinite &&
      !origin.isEmpty &&
      origin.width > 0 &&
      origin.height > 0) {
    return origin;
  }

  try {
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(800, 600);
    return size.center(Offset.zero) & const Size(1, 1);
  } catch (_) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
}
```

**Core Share Dispatch & Anchor Pattern** (lines 38-56, 165-207):
```dart
static Rect calculateAnchor(BuildContext context) {
  try {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.attached) {
      final origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      return sanitizeOrigin(origin, context);
    }
  } catch (_) {
    // Fallback to screen center
  }

  return sanitizeOrigin(null, context);
}

static Future<void> shareRecord({
  required BuildContext context,
  required NetworkRecord record,
  required ShareFormat format,
  bool excludeHeaders = false,
  Rect? sharePositionOrigin,
}) async {
  final String text = switch (format) {
    ShareFormat.markdown => formatMarkdown(record, excludeHeaders: excludeHeaders),
    ShareFormat.curl => formatCurl(record, excludeHeaders: excludeHeaders),
    ShareFormat.json => formatJson(record, excludeHeaders: excludeHeaders),
  };

  final origin = sanitizeOrigin(
    sharePositionOrigin ?? calculateAnchor(context),
    context,
  );
  final statusStr = record.responseStatusCode != null
      ? '${record.responseStatusCode}'
      : 'In-Flight';
  final subject = '${record.method} ${record.path} ($statusStr)';

  try {
    if (mockShareDelegate != null) {
      await mockShareDelegate!(
        text,
        subject: subject,
        sharePositionOrigin: origin,
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  } catch (error) {
    // D-02: Native platform failure fallback to Clipboard
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Sharing unavailable. Report copied to clipboard instead.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
```

**Error Handling & Fallback Pattern (D-02)**:
- Catch all platform exceptions (`PlatformException`, `MissingPluginException`, desktop environment handler missing).
- Execute `await Clipboard.setData(ClipboardData(text: text));`.
- Guard UI feedback with `if (context.mounted)` and use `ScaffoldMessenger.maybeOf(context)?.showSnackBar(...)`.

---

### `lib/src/shake/shake_detector.dart` (service / listener, event-driven)

**Analog:** `lib/src/shake/shake_detector.dart`  
**Git Tracked:** Yes (`lib/src/shake/shake_detector.dart`)

**Imports Pattern** (lines 1-7):
```dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/constants.dart';
```

**Constructor & Properties Pattern (D-06, D-07)** (lines 10-44):
```dart
class ShakeDetector with WidgetsBindingObserver {
  final VoidCallback onShake;
  final double threshold;
  final int debounceMs;
  final Duration? samplingPeriod;
  final void Function(Object error)? onSensorError;
  final Stream<UserAccelerometerEvent>? _customStream;
  final DateTime Function() _clock;

  @visibleForTesting
  static Stream<UserAccelerometerEvent>? mockStream;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  int _lastShakeTimestamp = 0;
  bool _isStarted = false;
  bool _isPaused = false;
  bool _hasReportedError = false;
  bool _isSensorAvailable = true;

  ShakeDetector({
    required this.onShake,
    this.threshold = NetworkInspectorConstants.defaultShakeThreshold,
    this.debounceMs = NetworkInspectorConstants.defaultShakeDebounceMs,
    this.samplingPeriod,
    this.onSensorError,
    Stream<UserAccelerometerEvent>? customStream,
    DateTime Function()? clock,
  })  : _customStream = customStream,
        _clock = clock ?? DateTime.now;

  bool get isListening => _isStarted && !_isPaused && _subscription != null;
  bool get isStarted => _isStarted;
  bool get isPaused => _isPaused;
  bool get isSensorAvailable => _isSensorAvailable;
```

**Stream Subscription & Error Callback Pattern (D-06, D-07)** (lines 74-110):
```dart
  void _subscribe() {
    if (_subscription != null) return;
    if (_binding == null && _customStream == null && mockStream == null) {
      return;
    }

    try {
      final stream = _customStream ??
          mockStream ??
          (samplingPeriod != null
              ? userAccelerometerEventStream(samplingPeriod: samplingPeriod!)
              : userAccelerometerEventStream());

      _subscription = stream.listen(
        _handleEvent,
        onError: (Object error) {
          _isSensorAvailable = false;
          onSensorError?.call(error);
          if (!_hasReportedError) {
            _hasReportedError = true;
            if (kDebugMode) {
              debugPrint(
                '[NetworkInspector] Accelerometer sensor unavailable. Shake detection disabled: $error',
              );
            }
          }
          _unsubscribe();
        },
        cancelOnError: true,
      );
    } catch (error) {
      _isSensorAvailable = false;
      onSensorError?.call(error);
      if (!_hasReportedError) {
        _hasReportedError = true;
        if (kDebugMode) {
          debugPrint(
            '[NetworkInspector] Failed to initialize accelerometer stream: $error',
          );
        }
      }
    }
  }
```

**Vector Finite Guard & Magnitude Calculation Pattern (D-05)** (lines 112-126):
```dart
  void _handleEvent(UserAccelerometerEvent event) {
    if (!_isStarted || _isPaused) return;

    // D-05: Guard against NaN and Infinite sensor readings
    if (!event.x.isFinite || !event.y.isFinite || !event.z.isFinite) {
      return;
    }

    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude >= threshold) {
      final now = _clock().millisecondsSinceEpoch;
      if (now - _lastShakeTimestamp >= debounceMs) {
        _lastShakeTimestamp = now;
        onShake();
      }
    }
  }
```

---

### `lib/src/storage/platform/ffi_init_io.dart` (config / adapter, initialization)

**Analog:** `lib/src/storage/platform/ffi_init_io.dart`  
**Git Tracked:** Yes (`lib/src/storage/platform/ffi_init_io.dart`)

**Imports Pattern with Top-Level SQLite Setter Support (API-04)** (lines 1-4):
```dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
```

**Core Pattern** (lines 5-12):
```dart
/// Initializes the desktop SQLite FFI database factory on Windows and Linux (D-31).
void initDesktopFfiIfRequired() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
```

---

### `pubspec.yaml` (config, static / declarative)

**Analog:** `pubspec.yaml`  
**Git Tracked:** Yes (`pubspec.yaml`)

**Dependencies Boundary Pattern (D-01, D-14, BOUND-01..05)** (lines 33-45):
```yaml
dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.0.0
  sqflite: ">=2.2.0 <3.0.0"
  sqflite_common_ffi: ">=2.2.0 <3.0.0"
  path: ">=1.8.0 <2.0.0"
  dio: ">=5.2.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
  intl: ">=0.18.0 <0.21.0"
  share_plus: ">=11.0.0 <14.0.0"
  sensors_plus: ">=6.0.0 <8.0.0"
```

---

### `lib/src/ui/components/filter_bottom_sheet.dart` (component / UI, presentation)

**Analog:** `lib/src/ui/components/filter_bottom_sheet.dart`  
**Git Tracked:** Yes (`lib/src/ui/components/filter_bottom_sheet.dart`)

**Safe Window Metric Queries Pattern (D-10)** (replacing line 141):
```dart
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

// D-10: Standardize UI window metric queries with fallback guards
final size = MediaQuery.maybeSizeOf(context) ?? const Size(800, 600);
final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
final viewInsets = MediaQuery.maybeViewInsetsOf(context) ?? EdgeInsets.zero;

// Limit bottom sheet height to at most 95% of screen safe area
final safeHeight = size.height - padding.top;
final maxSheetHeight = safeHeight * 0.95;

return ConstrainedBox(
  constraints: BoxConstraints(
    maxHeight: maxSheetHeight,
  ),
  child: Material(
    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: viewInsets.bottom,
        ),
...
```

---

### `test/ui/share_exporter_test.dart` (test, verification / widget testing)

**Analog:** `test/ui/share_exporter_test.dart` & `test/ui/clipboard_copy_test.dart`  
**Git Tracked:** Yes (`test/ui/share_exporter_test.dart`, `test/ui/clipboard_copy_test.dart`)

**Imports Pattern**:
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:fl_network_inspector/src/ui/components/export_action_sheet.dart';
import 'package:fl_network_inspector/src/ui/utils/share_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
```

**Platform Channel Mocking & Clipboard Interception Pattern** (from `test/ui/clipboard_copy_test.dart` lines 17-26):
```dart
String? copiedData;

TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall methodCall) async {
  if (methodCall.method == 'Clipboard.setData') {
    copiedData = (methodCall.arguments as Map<dynamic, dynamic>)['text']
        as String?;
    return null;
  }
  return null;
});
```

**Comprehensive Testing Suite Structure (D-04)**:
```dart
group('ShareExporter Defensive Origin & Fallback (D-02, D-03, D-04)', () {
  testWidgets('sanitizes zero or negative origin dimensions to safe screen center rect', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final context = tester.element(find.byType(SizedBox));

    const zeroOrigin = Rect.fromLTWH(100, 100, 0, 0);
    final sanitized = ShareExporter.sanitizeOrigin(zeroOrigin, context);

    expect(sanitized.isFinite, isTrue);
    expect(sanitized.width, greaterThan(0));
    expect(sanitized.height, greaterThan(0));
  });

  testWidgets('falls back to Clipboard and displays SnackBar when share delegate throws', (tester) async {
    ShareExporter.mockShareDelegate = (text, {subject, sharePositionOrigin}) async {
      throw PlatformException(code: 'SHARE_UNAVAILABLE', message: 'Platform not supported');
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ShareExporter.shareRecord(
                context: context,
                record: sampleRecord,
                format: ShareFormat.markdown,
              ),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(copiedData, contains('# Network Request Inspection'));
    expect(find.text('Sharing unavailable. Report copied to clipboard instead.'), findsOneWidget);
  });
});
```

---

### `test/shake/shake_detector_test.dart` (test, verification / stream testing)

**Analog:** `test/shake/shake_detector_test.dart`  
**Git Tracked:** Yes (`test/shake/shake_detector_test.dart`)

**Imports Pattern** (lines 1-6):
```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:fl_network_inspector/src/shake/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
```

**Multi-Scenario Test Suite Pattern (D-05, D-07, D-08)**:
```dart
test('discards NaN and infinite sensor readings without throwing or firing onShake (D-05)', () async {
  detector.start();

  // Non-finite readings
  controller.add(UserAccelerometerEvent(double.nan, 20.0, 20.0, DateTime.now()));
  controller.add(UserAccelerometerEvent(20.0, double.infinity, 20.0, DateTime.now()));
  controller.add(UserAccelerometerEvent(20.0, 20.0, double.negativeInfinity, DateTime.now()));
  await Future<void>.delayed(const Duration(milliseconds: 20));

  expect(shakeEvents, isEmpty);
});

test('tracks isSensorAvailable and invokes onSensorError callback on stream error (D-07)', () async {
  Object? capturedError;
  final errorDetector = ShakeDetector(
    onShake: () {},
    customStream: controller.stream,
    onSensorError: (error) => capturedError = error,
  );

  expect(errorDetector.isSensorAvailable, isTrue);
  errorDetector.start();

  final streamError = Exception('Accelerometer hardware disconnected');
  controller.addError(streamError);
  await Future<void>.delayed(const Duration(milliseconds: 20));

  expect(errorDetector.isSensorAvailable, isFalse);
  expect(errorDetector.isListening, isFalse);
  expect(capturedError, equals(streamError));

  errorDetector.dispose();
});
```

---

### `test/storage/database_schema_test.dart` and `test/storage/database_harness_test.dart` (test, verification / DB query)

**Analog:** `test/storage/database_schema_test.dart`  
**Git Tracked:** Yes (`test/storage/database_schema_test.dart`, `test/storage/database_harness_test.dart`)

**Imports Pattern with Explicit SQLite Top-Level Re-Export (API-04, D-15)**:
```dart
import 'package:fl_network_inspector/src/storage/database_constants.dart';
import 'package:fl_network_inspector/src/storage/database_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
```

**Core Fixture Setup Pattern** (lines 7-23):
```dart
void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabaseSchemaTest', () {
    late DatabaseManager dbManager;

    setUp(() {
      dbManager = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: inMemoryDatabasePath,
      );
    });

    tearDown(() async {
      await dbManager.close();
    });
...
```

---

## Shared Patterns

### 1. Vector & Geometry Sanitization
**Source:** `lib/src/shake/shake_detector.dart`, `lib/src/ui/utils/share_exporter.dart`  
**Apply to:** All hardware sensor listeners and popover anchor calculators  
```dart
// Check all components are finite and within valid geometric bounds
if (!vector.x.isFinite || !vector.y.isFinite || !vector.z.isFinite) {
  return;
}

if (rect == null || !rect.isFinite || rect.isEmpty || rect.width <= 0 || rect.height <= 0) {
  return fallbackRect;
}
```

### 2. Defensive Window Metric Queries
**Source:** `lib/src/ui/utils/share_exporter.dart:51`, `lib/src/ui/network_inspector_screen.dart:96,154,371`  
**Apply to:** All UI components querying screen dimensions or insets  
```dart
// Never use unconditional MediaQuery.of(context) which throws in headless widget tests
final size = MediaQuery.maybeSizeOf(context) ?? const Size(800, 600);
final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
final viewInsets = MediaQuery.maybeViewInsetsOf(context) ?? EdgeInsets.zero;
```

### 3. Graceful Platform Channel Fallback
**Source:** `lib/src/ui/utils/share_exporter.dart:185-207`, `test/ui/clipboard_copy_test.dart:17-26`  
**Apply to:** All platform-dependent service invocations  
```dart
try {
  await nativePlatformMethodCall();
} catch (error) {
  // Graceful degradation fallback
  await fallbackHandler();
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(feedbackSnackBar);
  }
}
```

### 4. Top-Level SQLite FFI Re-Exports
**Source:** `lib/src/storage/platform/ffi_init_io.dart`, `test/storage/database_schema_test.dart`  
**Apply to:** All storage files initializing desktop FFI or in-memory test databases  
```dart
// Always include package:sqflite/sqflite.dart alongside sqflite_common_ffi
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
```

---

## No Analog Found

Files with no close match in git-tracked source (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tool/verify_lowest_bounds.sh` | utility / DevOps script | batch / CLI pipeline | No shell scripts exist in git-tracked source yet. Implements Pattern 3 from `12-RESEARCH.md` using portable POSIX bash syntax, signal traps (`trap cleanup EXIT INT TERM`), lockfile backup/restore, targeted `dart pub downgrade`, and `flutter test --no-pub`. |

---

## Metadata

**Analog search scope:** `lib/`, `test/`, `pubspec.yaml`  
**Files scanned:** 64 tracked source and test files  
**Pattern extraction date:** 2026-11-21  
