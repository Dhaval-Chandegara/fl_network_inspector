# Phase 11: Dependency Bounds Widening - Pattern Map

**Mapped:** 2026-11-21  
**Files analyzed:** 10  
**Analogs found:** 10 / 10  

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `pubspec.yaml` | config | static | `pubspec.yaml` | exact |
| `lib/src/ui/utils/share_exporter.dart` | utility / export | presentation / request-response | `lib/src/ui/utils/share_exporter.dart` | exact |
| `test/ui/share_exporter_test.dart` | test | verification | `test/ui/share_exporter_test.dart` | exact |
| `lib/src/shake/shake_detector.dart` | utility / hardware | event-driven | `lib/src/shake/shake_detector.dart` | exact |
| `lib/src/utils/uuid_generator.dart` | utility / core | transform | `lib/src/utils/uuid_generator.dart` | exact |
| `lib/src/ui/components/request_tile.dart` | component / UI | presentation | `lib/src/ui/components/request_tile.dart` | exact |
| `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart` | interceptor / adapter | request-response | `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart` | exact |
| `lib/src/interceptor/http/network_inspector_http_client.dart` | interceptor / adapter | streaming | `lib/src/interceptor/http/network_inspector_http_client.dart` | exact |
| `test/shake/shake_detector_test.dart` | test | verification | `test/shake/shake_detector_test.dart` | exact |
| `test/repository/sqlite_repository_test.dart` | test | verification | `test/repository/sqlite_repository_test.dart` | exact |

---

## Pattern Assignments

### `pubspec.yaml` (config, static)

**Analog:** `pubspec.yaml`  
**Git Tracked:** Yes (`pubspec.yaml`)

**Current Dependencies Declaration** (lines 29-45):
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.6.0
  sqflite: ^2.4.5
  sqflite_common_ffi: ^2.4.5
  path: ^1.9.1
  dio: ">=5.2.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
  intl: ^0.20.3
  share_plus: ^13.3.1
  sensors_plus: ^7.1.1
```

**Widened Target Declaration Pattern** (satisfying D-01 through D-11, BOUND-01..05):
```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.0.0
  sqflite: ">=2.2.0 <3.0.0"
  sqflite_common_ffi: ">=2.2.0 <3.0.0"
  path: ">=1.8.0 <2.0.0"
  dio: ">=5.0.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
  intl: ">=0.18.0 <0.21.0"
  share_plus: ">=10.0.0 <14.0.0"
  sensors_plus: ">=6.0.0 <8.0.0"
```

**Dev Dependencies Pattern** (retained as-is per D-14, lines 46-51):
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  test: ^1.25.0
  http_parser: ^4.0.2
```

---

### `lib/src/ui/utils/share_exporter.dart` (utility / export, presentation)

**Analog:** `lib/src/ui/utils/share_exporter.dart`  
**Git Tracked:** Yes (`lib/src/ui/utils/share_exporter.dart`)

**Imports Pattern** (lines 1-8):
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/network_record.dart';
import '../../models/payload_data.dart';
import 'curl_generator.dart';
```

**iPadOS Popover Anchor Calculation with Fallback Pattern** (D-04, lines 35-56):
```dart
/// Safely calculates a [Rect] anchor origin from [context] to prevent iPadOS/macOS popover crashes (D-64).
///
/// Falls back to the center of the screen if the widget's [RenderBox] is not attached or has no size.
static Rect calculateAnchor(BuildContext context) {
  try {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.attached) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
  } catch (_) {
    // Fallback to screen center
  }

  try {
    final size = MediaQuery.sizeOf(context);
    return size.center(Offset.zero) & const Size(1, 1);
  } catch (_) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
}
```

**Share Dispatch Pattern with Test Delegate Guard** (lines 185-207):
```dart
final origin = sharePositionOrigin ?? calculateAnchor(context);
final statusStr = record.responseStatusCode != null
    ? '${record.responseStatusCode}'
    : 'In-Flight';
final subject = '${record.method} ${record.path} ($statusStr)';

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
```

---

### `test/ui/share_exporter_test.dart` (test, verification)

**Analog:** `test/ui/share_exporter_test.dart`  
**Git Tracked:** Yes (`test/ui/share_exporter_test.dart`)

**Imports Pattern** (lines 1-7):
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:fl_network_inspector/src/ui/components/export_action_sheet.dart';
import 'package:fl_network_inspector/src/ui/utils/share_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
```

**Anchor Rect Testing Pattern** (lines 113-144):
```dart
group('ShareExporter calculateAnchor', () {
  testWidgets('calculates valid anchor rect from attached widget context',
      (tester) async {
    late Rect anchor;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    anchor = ShareExporter.calculateAnchor(context);
                  },
                  child: const Text('Test Anchor'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Test Anchor'));
    await tester.pump();

    expect(anchor, isNotNull);
    expect(anchor.width, greaterThan(0));
    expect(anchor.height, greaterThan(0));
  });
});
```

**Detached Context Fallback Test Pattern** (to verify D-04 screen-center/default Rect fallback):
```dart
testWidgets('falls back to screen center or default rect when context renderObject is unattached',
    (tester) async {
  late BuildContext savedContext;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            savedContext = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );

  // Unmount widget tree to detach RenderBox
  await tester.pumpWidget(const SizedBox());

  final fallbackAnchor = ShareExporter.calculateAnchor(savedContext);
  expect(fallbackAnchor, isNotNull);
  expect(fallbackAnchor.width, equals(1));
  expect(fallbackAnchor.height, equals(1));
});
```

---

### `lib/src/shake/shake_detector.dart` (utility / hardware, event-driven)

**Analog:** `lib/src/shake/shake_detector.dart`  
**Git Tracked:** Yes (`lib/src/shake/shake_detector.dart`)

**Imports Pattern** (lines 1-6):
```dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
```

**Stream Subscription & Safe Error Handling Pattern** (BOUND-02, lines 74-110):
```dart
void _subscribe() {
  if (_subscription != null) return;

  // In headless Dart VM tests without Flutter bindings, native sensor platform channels are unavailable.
  if (_binding == null && _customStream == null && mockStream == null) {
    return;
  }

  try {
    final stream =
        _customStream ?? mockStream ?? userAccelerometerEventStream();
    _subscription = stream.listen(
      _handleEvent,
      onError: (Object error) {
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

---

### `lib/src/utils/uuid_generator.dart` (utility / core, transform)

**Analog:** `lib/src/utils/uuid_generator.dart`  
**Git Tracked:** Yes (`lib/src/utils/uuid_generator.dart`)

**Const Constructor & V4 Generation Pattern** (BOUND-04, lines 1-11):
```dart
import 'package:uuid/uuid.dart';

/// RFC 4122 v4 UUID generator utility for unique request IDs and transaction correlation.
abstract final class UuidGenerator {
  const UuidGenerator._();

  static const Uuid _uuid = Uuid();

  /// Generates a cryptographically random RFC 4122 v4 UUID string.
  static String v4() => _uuid.v4();
}
```

---

### `lib/src/ui/components/request_tile.dart` (component / UI, presentation)

**Analog:** `lib/src/ui/components/request_tile.dart`  
**Git Tracked:** Yes (`lib/src/ui/components/request_tile.dart`)

**`intl` DateFormat Initialization Pattern** (BOUND-03, lines 1-3, 16-17):
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/network_record.dart';
import '../../models/network_status.dart';
import 'status_badge.dart';

class RequestTile extends StatelessWidget {
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');
```

---

### `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart` (interceptor / adapter, request-response)

**Analog:** `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart`  
**Git Tracked:** Yes (`lib/src/interceptor/dio/network_inspector_dio_interceptor.dart`)

**Dio 5.x Interceptor & Error Handling Pattern** (BOUND-05, lines 3, 23, 296-302):
```dart
import 'package:dio/dio.dart';

class NetworkInspectorDioInterceptor extends Interceptor {
  const NetworkInspectorDioInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(options);
    }
    // ...
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(err);
    }
    // ...
  }
}
```

---

### `lib/src/interceptor/http/network_inspector_http_client.dart` (interceptor / adapter, streaming)

**Analog:** `lib/src/interceptor/http/network_inspector_http_client.dart`  
**Git Tracked:** Yes (`lib/src/interceptor/http/network_inspector_http_client.dart`)

**`package:http` `BaseClient` Wrapping Pattern** (BOUND-05, lines 3, 24-35):
```dart
import 'package:http/http.dart' as http;

class NetworkInspectorHttpClient extends http.BaseClient {
  final http.Client _inner;

  NetworkInspectorHttpClient([http.Client? inner])
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!NetworkInspector.isEnabled) {
      return _inner.send(request);
    }
    // Non-destructive stream tap and recording...
  }
}
```

---

### `test/shake/shake_detector_test.dart` (test, verification)

**Analog:** `test/shake/shake_detector_test.dart`  
**Git Tracked:** Yes (`test/shake/shake_detector_test.dart`)

**Mock Stream Injection Test Pattern** (lines 11-29):
```dart
group('ShakeDetector', () {
  late StreamController<UserAccelerometerEvent> controller;
  late List<DateTime> shakeEvents;
  late ShakeDetector detector;

  setUp(() {
    controller = StreamController<UserAccelerometerEvent>.broadcast();
    shakeEvents = [];
    detector = ShakeDetector(
      onShake: () => shakeEvents.add(DateTime.now()),
      threshold: 15.0,
      debounceMs: 500, // shorter debounce for testing
      customStream: controller.stream,
    );
  });

  tearDown(() async {
    detector.dispose();
    await controller.close();
  });
```

---

### `test/repository/sqlite_repository_test.dart` (test, verification)

**Analog:** `test/repository/sqlite_repository_test.dart`  
**Git Tracked:** Yes (`test/repository/sqlite_repository_test.dart`)

**In-Memory FFI SQLite Harness Pattern** (lines 10-28):
```dart
void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteNetworkInspectorRepository', () {
    late SqliteNetworkInspectorRepository repository;

    setUp(() async {
      repository = SqliteNetworkInspectorRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      await repository.initialize();
    });

    tearDown(() async {
      await repository.dispose();
    });
```

---

## Shared Patterns

### 1. Permissive Semantic Version Range Declaration
**Source:** `pubspec.yaml` lines 33-45  
**Apply to:** All dependency constraints declared in `pubspec.yaml`  
```yaml
dependencies:
  uuid: ^4.0.0
  sqflite: ">=2.2.0 <3.0.0"
  sqflite_common_ffi: ">=2.2.0 <3.0.0"
  path: ">=1.8.0 <2.0.0"
  dio: ">=5.0.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
  intl: ">=0.18.0 <0.21.0"
  share_plus: ">=10.0.0 <14.0.0"
  sensors_plus: ">=6.0.0 <8.0.0"
```
*Rationale:* Enforces a stable lower bound compatible with Dart 3 / Flutter 3.10 while enforcing strict upper bounds (`<next_major`) to satisfy pub.dev scoring and prevent breaking runtime changes.

### 2. Resilient Platform & Hardware Fallback
**Source:** `lib/src/ui/utils/share_exporter.dart` lines 39-56, `lib/src/shake/shake_detector.dart` lines 82-109  
**Apply to:** Third-party plugin call sites (`share_plus`, `sensors_plus`)  
```dart
try {
  // Primary hardware / platform call
} catch (error) {
  // Graceful fallback: return safe default geometry or log debug warning and disable feature
}
```

### 3. Dependency Isolation via Utility Facades
**Source:** `lib/src/utils/uuid_generator.dart`, `lib/src/ui/utils/share_exporter.dart`, `lib/src/shake/shake_detector.dart`  
**Apply to:** All third-party library integrations  
*Rationale:* Core domain models and presentation screens never import `uuid`, `share_plus`, or `sensors_plus` directly. Instead, they interact via isolated wrapper classes that can be mocked, swapped, or verified independently.

### 4. Zero-Device Headless Test Isolation
**Source:** `test/repository/sqlite_repository_test.dart` lines 10-24, `test/shake/shake_detector_test.dart` lines 15-24  
**Apply to:** All unit and widget test suites  
*Rationale:* All database and hardware tests run in standard headless Dart VM / CI runners using `databaseFactoryFfi` + `inMemoryDatabasePath` or broadcast stream injection (`customStream`), guaranteeing 100% test reliability without emulator dependencies.

---

## No Analog Found

None. All files and dependencies modified or verified in Phase 11 have exact, git-tracked analogs in the current codebase.

---

## Metadata

**Analog search scope:** `pubspec.yaml`, `lib/src/`, `test/`  
**Files scanned:** 15  
**Pattern extraction date:** 2026-11-21  
