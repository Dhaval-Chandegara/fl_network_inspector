# Phase 04: Inspector UI - Pattern Map

**Mapped:** 2026-11-01  
**Files analyzed:** 33  
**Analogs found:** 21 / 33 (12 UI widgets have no prior in-repo widget analogs and map directly to RESEARCH.md patterns)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `pubspec.yaml` | config | transform | `pubspec.yaml` | exact |
| `lib/src/config/network_inspector_config.dart` | config | request-response | `lib/src/config/network_inspector_config.dart` | exact |
| `lib/src/core/network_inspector.dart` | controller | request-response | `lib/src/core/network_inspector.dart` | exact |
| `lib/flutter_network_inspector.dart` | utility | transform | `lib/flutter_network_inspector.dart` | exact |
| `lib/src/ui/utils/curl_generator.dart` | utility | transform | `lib/src/utils/payload_truncator.dart` | exact |
| `lib/src/ui/utils/json_format_isolate.dart` | utility | isolate / transform | `lib/src/storage/platform/ffi_init_io.dart` | exact |
| `lib/src/ui/utils/share_exporter.dart` | utility / service | event-driven | `lib/src/logging/manual_logger.dart` | exact |
| `lib/src/ui/controllers/inspector_view_model.dart` | controller | CRUD / request-response | `lib/src/repository/write_buffer_queue.dart` | role-match |
| `lib/src/ui/controllers/theme_controller.dart` | controller / provider | event-driven | `lib/src/interceptor/io/http_overrides_manager.dart` | role-match |
| `lib/src/ui/network_inspector_screen.dart` | component / route | CRUD | `lib/src/core/network_inspector.dart` | none (RESEARCH.md) |
| `lib/src/ui/network_inspector_detail_screen.dart` | component / route | request-response | `lib/src/models/network_record.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/request_tile.dart` | component | request-response | `lib/src/models/network_record.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/search_bar_view.dart` | component | event-driven | `lib/src/repository/write_buffer_queue.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/filter_chips_bar.dart` | component | event-driven | `lib/src/models/record_filter.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/filter_bottom_sheet.dart` | component | request-response | `lib/src/models/record_filter.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/sort_menu_button.dart` | component | event-driven | `lib/src/models/record_sort.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/clear_all_dialog.dart` | component | request-response | `lib/src/repository/network_inspector_repository.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/status_badge.dart` | component | transform | `lib/src/models/network_status.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/copy_button.dart` | component | event-driven | `lib/src/logging/manual_logger.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/export_action_sheet.dart` | component | event-driven | `lib/src/logging/manual_logger.dart` | none (RESEARCH.md) |
| `lib/src/ui/components/json_viewer.dart` | component | transform | `lib/src/utils/payload_truncator.dart` | none (RESEARCH.md) |
| `test/ui/helpers/test_record_fixtures.dart` | test / utility | transform | `test/models/network_record_test.dart` | exact |
| `test/ui/curl_generator_test.dart` | test | transform | `test/utils/payload_truncator_test.dart` | exact |
| `test/ui/share_exporter_test.dart` | test | event-driven | `test/logging/manual_logging_test.dart` | role-match |
| `test/ui/json_viewer_test.dart` | test | transform | `test/utils/payload_truncator_test.dart` | role-match |
| `test/ui/network_inspector_screen_test.dart` | test | request-response | `test/logging/manual_logging_test.dart` | role-match |
| `test/ui/pagination_test.dart` | test | CRUD / batch | `test/repository/sqlite_repository_test.dart` | role-match |
| `test/ui/search_test.dart` | test | event-driven | `test/repository/sqlite_repository_test.dart` | role-match |
| `test/ui/filter_test.dart` | test | event-driven | `test/repository/sqlite_repository_test.dart` | role-match |
| `test/ui/sorting_test.dart` | test | request-response | `test/repository/sqlite_repository_test.dart` | role-match |
| `test/ui/clear_all_test.dart` | test | request-response | `test/repository/sqlite_repository_test.dart` | role-match |
| `test/ui/network_inspector_detail_screen_test.dart` | test | request-response | `test/logging/manual_logging_test.dart` | role-match |
| `test/ui/clipboard_copy_test.dart` | test | event-driven | `test/logging/manual_logging_test.dart` | role-match |

---

## Pattern Assignments

### `pubspec.yaml` (config, transform)

**Analog:** `pubspec.yaml`

**Dependencies pattern** (lines 10-25):
```yaml
dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.6.0
  sqflite: ^2.4.5
  sqflite_common_ffi: ^2.4.5
  path: ^1.9.1
  dio: ">=5.0.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
  share_plus: ^13.3.1
  intl: ^0.20.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  test: ^1.25.0
```

---

### `lib/src/config/network_inspector_config.dart` (config, request-response)

**Analog:** `lib/src/config/network_inspector_config.dart`

**Imports pattern** (lines 1-3):
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/constants.dart';
```

**Immutable config & field definition pattern** (lines 5-54):
```dart
@immutable
class NetworkInspectorConfig {
  final bool? _enabled;
  final int maxRecords;
  final int maxBodyBytes;
  final bool enableAutoCapture;
  final bool enableShakeDetection;
  final bool enableDatabase;
  final bool includeMultipartFilePaths;
  final List<String> customRedactionKeys;
  final List<String> ignoredHosts;
  final List<String> ignoredUrls;
  final GlobalKey<NavigatorState>? navigatorKey;

  const NetworkInspectorConfig({
    bool? enabled,
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
    this.maxBodyBytes = NetworkInspectorConstants.defaultMaxBodyBytes,
    this.enableAutoCapture = true,
    this.enableShakeDetection = true,
    this.enableDatabase = true,
    this.includeMultipartFilePaths = false,
    this.customRedactionKeys = const [],
    this.ignoredHosts = const [],
    this.ignoredUrls = const [],
    this.navigatorKey,
  }) : _enabled = enabled;
```

**Value semantics & equality pattern** (lines 66-121):
```dart
  NetworkInspectorConfig copyWith({
    bool? enabled,
    int? maxRecords,
    int? maxBodyBytes,
    bool? enableAutoCapture,
    bool? enableShakeDetection,
    bool? enableDatabase,
    bool? includeMultipartFilePaths,
    List<String>? customRedactionKeys,
    List<String>? ignoredHosts,
    List<String>? ignoredUrls,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return NetworkInspectorConfig(
      enabled: enabled ?? _enabled,
      maxRecords: maxRecords ?? this.maxRecords,
      maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
      enableAutoCapture: enableAutoCapture ?? this.enableAutoCapture,
      enableShakeDetection: enableShakeDetection ?? this.enableShakeDetection,
      enableDatabase: enableDatabase ?? this.enableDatabase,
      includeMultipartFilePaths:
          includeMultipartFilePaths ?? this.includeMultipartFilePaths,
      customRedactionKeys: customRedactionKeys ?? this.customRedactionKeys,
      ignoredHosts: ignoredHosts ?? this.ignoredHosts,
      ignoredUrls: ignoredUrls ?? this.ignoredUrls,
      navigatorKey: navigatorKey ?? this.navigatorKey,
    );
  }
```

---

### `lib/src/core/network_inspector.dart` (controller, request-response)

**Analog:** `lib/src/core/network_inspector.dart`

**Imports pattern** (lines 1-13):
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/network_inspector_config.dart';
import '../interceptor/platform/http_capture_platform.dart';
import '../logging/manual_logger.dart';
import '../logging/network_request_tracker.dart';
import '../logging/no_op_network_request_tracker.dart';
import '../models/http_error_details.dart';
import '../repository/in_memory_network_inspector_repository.dart';
import '../repository/network_inspector_repository.dart';
import '../repository/sqlite_network_inspector_repository.dart';
import '../storage/platform/ffi_init.dart';
import '../ui/network_inspector_screen.dart';
```

**Navigation & deduplication guard pattern** (copy into lines 18-21 and 55-65):
```dart
final class NetworkInspector {
  NetworkInspector._();

  static NetworkInspectorConfig _currentConfig = const NetworkInspectorConfig();
  static bool _isInitialized = false;
  static NetworkInspectorRepository? _repository;
  static bool _isOpen = false;

  /// Programmatically opens the inspector UI screen (D-49, D-51, D-52).
  static Future<void> open(BuildContext context) async {
    if (!isEnabled || _isOpen) return;

    _isOpen = true;
    try {
      final navigatorState = _currentConfig.navigatorKey?.currentState ??
          Navigator.of(context, rootNavigator: true);
      await navigatorState.push(
        MaterialPageRoute<void>(
          builder: (context) => const NetworkInspectorScreen(),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _isOpen = false;
    }
  }
```

**Guard check pattern** (lines 87, 112, 137):
```dart
if (!isEnabled || _repository == null) return;
```

---

### `lib/flutter_network_inspector.dart` (utility, transform)

**Analog:** `lib/flutter_network_inspector.dart`

**Export barrel pattern** (lines 1-44):
```dart
library flutter_network_inspector;

// Configuration
export 'src/config/network_inspector_config.dart';

// Core Facade & Constants
export 'src/core/constants.dart';
export 'src/core/network_inspector.dart';

// Repository & Storage
export 'src/repository/in_memory_network_inspector_repository.dart';
export 'src/repository/network_inspector_repository.dart';
export 'src/repository/sqlite_network_inspector_repository.dart';

// Domain Models
export 'src/models/body_type.dart';
export 'src/models/http_error_details.dart';
export 'src/models/multipart_entry.dart';
export 'src/models/network_record.dart';
export 'src/models/network_status.dart';
export 'src/models/payload_data.dart';
export 'src/models/record_filter.dart';
export 'src/models/record_sort.dart';

// Utilities
export 'src/utils/body_type_detector.dart';
export 'src/utils/payload_truncator.dart';
export 'src/utils/redaction_engine.dart';
export 'src/utils/uuid_generator.dart';

// Client Adapters
export 'src/interceptor/dio/network_inspector_dio_interceptor.dart';
export 'src/interceptor/http/network_inspector_http_client.dart';

// Manual Logging & Request Tracking
export 'src/logging/network_request_tracker.dart';
export 'src/logging/no_op_network_request_tracker.dart';

// UI Presentation & Screens (UI-01, UI-07, D-49)
export 'src/ui/network_inspector_screen.dart';
export 'src/ui/network_inspector_detail_screen.dart';
```

---

### `lib/src/ui/utils/curl_generator.dart` (utility, transform)

**Analog:** `lib/src/utils/payload_truncator.dart`

**Imports pattern** (lines 1-5):
```dart
import '../../models/network_record.dart';
```

**Utility class structure** (lines 11-13 in `payload_truncator.dart`):
```dart
abstract final class CurlGenerator {
  const CurlGenerator._();

  /// Generates a copyable, terminal-executable cURL command from a [NetworkRecord] (UI-10, D-61).
  static String fromRecord(NetworkRecord record) {
    final buffer = StringBuffer();
    buffer.write('curl -X ${record.method.toUpperCase()} \\\n');
    buffer.write("  '${_escapeBash(record.url)}'");

    for (final entry in record.requestHeaders.entries) {
      if (entry.key.startsWith(':')) continue;
      final key = _escapeBash(entry.key);
      final value = _escapeBash(entry.value.toString());
      buffer.write(' \\\n');
      buffer.write("  -H '$key: $value'");
    }

    final body = record.requestBody?.body;
    if (body != null && body.isNotEmpty) {
      buffer.write(' \\\n');
      buffer.write("  --data-raw '${_escapeBash(body)}'");
    }

    return buffer.toString();
  }

  /// Escapes single quotes for bash single-quoted strings: ' -> '\''
  static String _escapeBash(String input) {
    return input.replaceAll("'", r"'\''");
  }
}
```

---

### `lib/src/ui/utils/json_format_isolate.dart` (utility, isolate / transform)

**Analog:** `lib/src/storage/platform/ffi_init_io.dart`

**Imports pattern** (lines 1-3):
```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
```

**Isolate invocation pattern** (`04-RESEARCH.md:432-449`):
```dart
/// Top-level isolate entrypoint for JSON string formatting (D-59).
String formatJsonIsolate(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return rawJson;
  }
}

/// Formats [rawJson] using background compute() if size > 50KB.
Future<String> formatJsonBody(String rawJson) async {
  if (rawJson.length > 50 * 1024) {
    return compute(formatJsonIsolate, rawJson);
  } else {
    return formatJsonIsolate(rawJson);
  }
}
```

---

### `lib/src/ui/utils/share_exporter.dart` (utility / service, event-driven)

**Analog:** `lib/src/logging/manual_logger.dart`

**Imports pattern** (lines 1-19 in `manual_logger.dart`):
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/network_record.dart';
import 'curl_generator.dart';
```

**Dispatching & iPadOS anchor protection pattern** (`04-RESEARCH.md:667-738`):
```dart
abstract final class ShareExporter {
  const ShareExporter._();

  static Future<void> shareRecord({
    required BuildContext context,
    required NetworkRecord record,
    required ShareFormat format,
    bool excludeHeaders = false,
  }) async {
    final text = switch (format) {
      ShareFormat.markdown => _toMarkdown(record, excludeHeaders),
      ShareFormat.curl => CurlGenerator.fromRecord(record),
      ShareFormat.json => _toJsonSummary(record, excludeHeaders),
    };

    final origin = _getOriginRect(context);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: '${record.method} ${record.path} (${record.responseStatusCode ?? "In-Flight"})',
        sharePositionOrigin: origin,
      ),
    );
  }

  static Rect _getOriginRect(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return size.center(Offset.zero) & const Size(1, 1);
  }
}

enum ShareFormat { markdown, curl, json }
```

---

### `lib/src/ui/controllers/inspector_view_model.dart` (controller, CRUD / request-response)

**Analog:** `lib/src/repository/write_buffer_queue.dart`

**Imports pattern** (lines 1-4 in `write_buffer_queue.dart`):
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/network_record.dart';
import '../../models/record_filter.dart';
import '../../models/record_sort.dart';
import '../../repository/network_inspector_repository.dart';
```

**Timer debounce, pagination, and state controller pattern** (lines 26-37, 57-60, 88-115 in `write_buffer_queue.dart`):
```dart
class InspectorViewModel extends ChangeNotifier {
  final NetworkInspectorRepository _repository;
  
  static const int pageSize = 50;
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  List<NetworkRecord> _records = [];
  int _totalCount = 0;
  RecordFilter _filter = RecordFilter.empty;
  RecordSort _sort = RecordSort.newestFirst;
  Timer? _searchDebounceTimer;
  bool _isDisposed = false;

  InspectorViewModel({required NetworkInspectorRepository repository})
      : _repository = repository;

  List<NetworkRecord> get records => _records;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  RecordFilter get filter => _filter;
  RecordSort get sort => _sort;

  void onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final trimmed = query.trim();
      setFilter(_filter.copyWith(searchQuery: trimmed.isEmpty ? null : trimmed));
    });
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _isDisposed) return;
    _isLoading = true;
    notifyListeners();

    try {
      final newRecords = await _repository.getRecords(
        filter: _filter,
        sort: _sort,
        limit: pageSize,
        offset: _offset,
      );
      if (_isDisposed) return;
      _offset += newRecords.length;
      _records.addAll(newRecords);
      _hasMore = newRecords.length == pageSize;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    super.dispose();
  }
}
```

---

### `lib/src/ui/controllers/theme_controller.dart` (controller / provider, event-driven)

**Analog:** `lib/src/interceptor/io/http_overrides_manager.dart`

**Imports pattern**:
```dart
import 'package:flutter/material.dart';
```

**Theme mode controller pattern**:
```dart
/// Local ThemeMode state holder for the network inspector UI (D-50).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([ThemeMode initialMode = ThemeMode.system]) : super(initialMode);

  void toggleTheme() {
    value = switch (value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }

  void setTheme(ThemeMode mode) {
    if (value != mode) {
      value = mode;
    }
  }
}
```

---

### `test/ui/helpers/test_record_fixtures.dart` (test / utility, transform)

**Analog:** `test/models/network_record_test.dart`

**Imports pattern** (lines 1-10 in `network_record_test.dart`):
```dart
import 'package:flutter_network_inspector/src/models/body_type.dart';
import 'package:flutter_network_inspector/src/models/http_error_details.dart';
import 'package:flutter_network_inspector/src/models/multipart_entry.dart';
import 'package:flutter_network_inspector/src/models/network_record.dart';
import 'package:flutter_network_inspector/src/models/network_status.dart';
import 'package:flutter_network_inspector/src/models/payload_data.dart';
```

**Fixture generation pattern** (lines 33-60 in `network_record_test.dart`):
```dart
class TestRecordFixtures {
  static NetworkRecord createRecord({
    String id = 'test-id-1',
    String method = 'GET',
    String url = 'https://api.example.com/v1/users',
    String path = '/v1/users',
    int? statusCode = 200,
    NetworkStatus status = NetworkStatus.success,
    int? durationMs = 120,
    DateTime? timestamp,
    Map<String, dynamic>? requestHeaders,
    Map<String, dynamic>? responseHeaders,
    String? requestBody,
    String? responseBody,
    HttpErrorDetails? error,
  }) {
    final ts = timestamp ?? DateTime.parse('2026-11-01T12:00:00.000Z');
    return NetworkRecord(
      id: id,
      url: url,
      baseUrl: 'https://api.example.com',
      path: path,
      method: method,
      requestTimestamp: ts,
      responseTimestamp: ts.add(Duration(milliseconds: durationMs ?? 0)),
      durationMs: durationMs,
      responseStatusCode: statusCode,
      status: status,
      requestHeaders: requestHeaders ?? {'Content-Type': 'application/json'},
      responseHeaders: responseHeaders ?? {'Content-Type': 'application/json'},
      requestBody: requestBody != null
          ? PayloadData(body: requestBody, byteSize: requestBody.length, bodyType: BodyType.json)
          : null,
      responseBody: responseBody != null
          ? PayloadData(body: responseBody, byteSize: responseBody.length, bodyType: BodyType.json)
          : null,
      error: error,
    );
  }
}
```

---

### `test/ui/curl_generator_test.dart` (test, transform)

**Analog:** `test/utils/payload_truncator_test.dart`

**Imports pattern** (lines 1-7 in `payload_truncator_test.dart`):
```dart
import 'package:flutter_network_inspector/src/models/network_record.dart';
import 'package:flutter_network_inspector/src/ui/utils/curl_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_record_fixtures.dart';
```

**Assertion pattern** (lines 9-40 in `payload_truncator_test.dart`):
```dart
void main() {
  group('CurlGenerator (UI-10, D-61)', () {
    test('generates valid multi-line bash command for GET request', () {
      final record = TestRecordFixtures.createRecord(method: 'GET', url: 'https://api.example.com/items');
      final curl = CurlGenerator.fromRecord(record);
      expect(curl, startsWith("curl -X GET \\\n  'https://api.example.com/items'"));
    });

    test('properly escapes single quotes in URLs and bodies', () {
      final record = TestRecordFixtures.createRecord(
        method: 'POST',
        url: "https://api.example.com/o'reilly",
        requestBody: '{"quote": "it\'s working"}',
      );
      final curl = CurlGenerator.fromRecord(record);
      expect(curl, contains(r"o'\''reilly"));
      expect(curl, contains(r"it'\''s working"));
    });
  });
}
```

---

### `test/ui/network_inspector_screen_test.dart` (test, request-response)

**Analog:** `test/logging/manual_logging_test.dart`

**Imports pattern** (lines 1-7 in `manual_logging_test.dart`):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_record_fixtures.dart';
```

**Widget test setup and harness pattern** (lines 12-23 in `manual_logging_test.dart`):
```dart
void main() {
  group('NetworkInspectorScreen (UI-01)', () {
    late InMemoryNetworkInspectorRepository repository;

    setUp(() async {
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true),
        repository: repository,
      );
    });

    tearDown(() {
      NetworkInspector.resetForTesting();
    });

    testWidgets('renders request tiles with method, status, and path badges', (tester) async {
      final record = TestRecordFixtures.createRecord(
        method: 'POST',
        statusCode: 201,
        path: '/api/v1/auth',
      );
      await repository.save(record);

      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkInspectorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('POST'), findsOneWidget);
      expect(find.text('201'), findsOneWidget);
      expect(find.text('/api/v1/auth'), findsOneWidget);
    });
  });
}
```

---

## Shared Patterns

### Production Enablement Guard
**Source:** `lib/src/core/network_inspector.dart:59`, `lib/src/logging/network_request_tracker_impl.dart:18-20`  
**Apply to:** `NetworkInspector.open(context)`, UI launch triggers.
```dart
if (!isEnabled) return;
```

### Async Reentrancy & Deduplication Guard
**Source:** `lib/src/repository/write_buffer_queue.dart:28, 89-99`  
**Apply to:** `NetworkInspector.open(context)` (`_isOpen`), `InspectorViewModel.loadMore()` (`_isLoading`).
```dart
if (_isLoading || !_hasMore) return;
_isLoading = true;
try {
  // Execute async payload fetch or route animation
} finally {
  _isLoading = false;
}
```

### Debounce Timer Pattern with Lifecycle Disposal
**Source:** `lib/src/repository/write_buffer_queue.dart:27, 101-105, 110-112`  
**Apply to:** `SearchBarView`, `InspectorViewModel`.
```dart
Timer? _debounceTimer;

void onInputChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    // Execute query
  });
}

@override
void dispose() {
  _debounceTimer?.cancel();
  _debounceTimer = null;
  super.dispose();
}
```

### Material 3 Surface and Contrast Color Resolution
**Source:** `04-RESEARCH.md:613-619`  
**Apply to:** `RequestTile`, `StatusBadge`, `JsonViewerWidget`.
```dart
final theme = Theme.of(context);
final colorScheme = theme.colorScheme;
final isDark = theme.brightness == Brightness.dark;
```

### In-Memory Test Harness for UI Widget Tests
**Source:** `test/logging/manual_logging_test.dart:12-23`  
**Apply to:** All `test/ui/*_test.dart` files.
```dart
setUp(() async {
  final repo = InMemoryNetworkInspectorRepository(maxRecords: 100);
  await NetworkInspector.initialize(
    config: const NetworkInspectorConfig(enabled: true),
    repository: repo,
  );
});

tearDown(() {
  NetworkInspector.resetForTesting();
});
```

---

## No Analog Found

The following UI widgets are newly introduced in Phase 04 (as the repository previously contained only storage, models, interceptors, and logging). The planner should reference the architectural contracts and implementations established in `04-RESEARCH.md`:

| File | Role | Data Flow | Reason & Guidance |
|------|------|-----------|-------------------|
| `lib/src/ui/network_inspector_screen.dart` | component / route | CRUD | First listing screen in project. Follow `04-RESEARCH.md:378-425` for M3 Scaffold, SearchBar, Infinite Scroll ListView. |
| `lib/src/ui/network_inspector_detail_screen.dart` | component / route | request-response | First tabbed detail screen in project. Follow `04-CONTEXT.md:D-57` for 4-tab DefaultTabController structure. |
| `lib/src/ui/components/request_tile.dart` | component | request-response | First card tile component. Follow `04-CONTEXT.md:D-53` for 2-line Card layout with color-coded badges. |
| `lib/src/ui/components/search_bar_view.dart` | component | event-driven | First search bar component. Follow `04-CONTEXT.md:D-54` for M3 `SearchBar` with clear button. |
| `lib/src/ui/components/filter_chips_bar.dart` | component | event-driven | First filter bar component. Follow `04-CONTEXT.md:D-55` for horizontal `FilterChip` quick bar. |
| `lib/src/ui/components/filter_bottom_sheet.dart` | component | request-response | First bottom sheet. Follow `04-CONTEXT.md:D-55` for multi-parameter modal filter sheet. |
| `lib/src/ui/components/sort_menu_button.dart` | component | event-driven | First sort menu. Follow `04-RESEARCH.md:287-334` binding M3 `PopupMenuButton` to `RecordSort`. |
| `lib/src/ui/components/clear_all_dialog.dart` | component | request-response | First alert dialog. Follow `04-CONTEXT.md:D-28, UI-06` for M3 `AlertDialog` confirming deletion. |
| `lib/src/ui/components/status_badge.dart` | component | transform | First badge component. Follow `04-CONTEXT.md:D-53` method & status color tint styling. |
| `lib/src/ui/components/copy_button.dart` | component | event-driven | First copy button. Follow `04-CONTEXT.md:D-60` for `Clipboard.setData` with confirmation SnackBar. |
| `lib/src/ui/components/export_action_sheet.dart` | component | event-driven | First export picker. Follow `04-CONTEXT.md:D-62, D-63` for modal sheet with formats and exclude headers. |
| `lib/src/ui/components/json_viewer.dart` | component | transform | First formatted viewer. Follow `04-RESEARCH.md:578-658` for regex syntax coloring into `SelectableText.rich`. |

---

## Metadata

**Analog search scope:** `lib/src/`, `test/`  
**Files scanned:** 68 git-tracked files  
**Pattern extraction date:** 2026-11-01  
