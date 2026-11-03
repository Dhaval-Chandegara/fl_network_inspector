# Phase 04: Inspector UI - Research

**Researched:** 2026-11-01  
**Domain:** Flutter Material 3 In-App Network Debugging UI & Export Utilities  
**Confidence:** HIGH  

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Navigation & Theme Integration
- **D-49:** Full-screen Material route (`Navigator.push`) for the main inspector screen (`NetworkInspectorScreen`), maximizing screen real estate for browsing records and deep multi-tab inspection with standard AppBar back navigation — **Reversibility:** costly — Defines public navigation signatures and screen scaffolding.
- **D-50:** Theming strategy: Inherit host app's `Theme.of(context)` by default with Material 3 styling, complemented by an in-app theme toggle (System / Light / Dark) in the AppBar for developers who need high-contrast dark inspection in a light host app — **Reversibility:** reversible — Local theme mode state management within the inspector view.
- **D-51:** Route deduplication guard: Track an internal `_isOpen` state flag on `NetworkInspector` or route observer to silently ignore duplicate open calls or rapid device shakes while the inspector is already visible on the screen — **Reversibility:** reversible — Navigation guard implementation.
- **D-52:** Navigation scope & key resolution: Use root navigator (`Navigator.of(context, rootNavigator: true)`) with optional fallback to `NetworkInspectorConfig.navigatorKey` if provided, ensuring the inspector overlays bottom navigation bars, nested shell routes, and modal sheets cleanly — **Reversibility:** costly — Interacts with host app routing setup.

#### Listing Screen Density & Filter UX
- **D-53:** Request tile formatting: Two-line card tile with color-coded badges. Top line: Method badge (colored GET, POST, PUT, DELETE, PATCH) + Status code badge (green 2xx, blue 3xx, orange 4xx, red 5xx) + endpoint path (`/api/v1/users`). Second line: Timestamp (`HH:mm:ss`), duration (`ms`), payload size (`KB`), and trailing status indicator dot — **Reversibility:** reversible — UI widget presentation.
- **D-54:** Search interaction: Persistent SearchBar at top of listing screen with reactive 300ms debounce across URL, method, status code, and payload text, paired with a quick-clear (`x`) button — **Reversibility:** reversible — Reactive search controller and query integration.
- **D-55:** Filter organization: Horizontal quick-filter chips bar directly below search for 1-tap toggling (All, Errors Only, 2xx, 4xx/5xx, POST, GET), plus a "Filters" icon button opening a modal bottom sheet for advanced multi-parameter filtering (custom status code ranges, min/max duration, date range) — **Reversibility:** reversible — Filter UI architecture.
- **D-56:** Pagination strategy: Batch page size of 50 records with threshold-based infinite scrolling (auto-fetching the next 50 records when scrolled to the bottom 20% of list depth), complemented by pull-to-refresh (`RefreshIndicator`) to reload latest records — **Reversibility:** costly — Coordinates with `NetworkInspectorRepository.getRecords(limit: 50, offset: offset)`.

#### Details Inspection & JSON Viewer UX
- **D-57:** Tabbed details screen architecture: 4 main top-level tabs (Overview, Request, Response, Error). Overview shows metadata summary; Request tab houses headers, query params, body, and multipart entries; Response tab houses headers and body; Error tab houses exception and stack trace — **Reversibility:** costly — Screen component structure and data binding.
- **D-58:** JSON Body rendering: Pure Flutter Material 3 formatted viewer with 2-space indentation (`JsonEncoder.withIndent('  ')`), lightweight syntax colorizer (keys, strings, numbers, booleans), a "Raw / Pretty" toggle button, and `SelectableText` for easy text selection without third-party dependencies — **Reversibility:** reversible — JSON viewer widget implementation.
- **D-59:** Large payload processing: Offload JSON formatting and pretty-print indentation to a background isolate using Flutter's `compute()` for bodies > 50KB with a brief loading spinner, while payloads <= 50KB are formatted synchronously on the UI isolate to preserve 60fps responsiveness — **Reversibility:** reversible — Performance optimization.
- **D-60:** Granular clipboard copy & developer feedback: Dedicated copy icon buttons on each section (full URL, request headers, response headers, request body, response body) with a lightweight confirmation `SnackBar` ("Copied [section] to clipboard") — **Reversibility:** reversible — User feedback pattern.

#### cURL & Share Sheet Export Options
- **D-61:** cURL command formatting: Generate multi-line bash-escaped cURL commands with line continuations (`\`), `-X METHOD`, `-H 'header: value'`, and safely quoted `--data-raw '...'` body ready for direct terminal execution — **Reversibility:** reversible — cURL generator utility.
- **D-62:** Multi-format Share Sheet picker: Tapping "Share" in the detail screen presents a quick action sheet offering "Share as Markdown Summary", "Share as cURL", or "Share as Full JSON" — **Reversibility:** reversible — Export flow.
- **D-63:** Sensitive data handling during export: Default to pre-redacted database records (which already have sensitive keys masked as `[REDACTED]` per `D-09`–`D-12`), with an optional "Exclude all headers" checkbox in the export sheet for maximum privacy when sharing with third parties — **Reversibility:** reversible — Export privacy guard.
- **D-64:** iPadOS / macOS Desktop share sheet anchor protection: Centralized `ShareExporter` utility that safely extracts `sharePositionOrigin` (`RenderBox.localToGlobal(Offset.zero) & box.size`) from the triggering widget's `BuildContext` with automatic fallback to screen center if unattached, preventing fatal `NSGenericException` crashes — **Reversibility:** costly — Platform integration safety rule.

### the agent's Discretion
- Visual color palette for HTTP methods (GET: blue/teal, POST: green, PUT: orange, DELETE: red, PATCH: purple).
- Specific typography, spacing, and elevation values adhering to Material 3 tokens.
- Empty states with informative illustrations/icons for "No network requests yet" and "No matching search results".
- Confirmation dialog styling for the "Clear All" action (`UI-06`, `D-28`).

### Deferred Ideas (OUT OF SCOPE)
- None — all discussed decisions directly support Phase 4 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **UI-01** | API listing screen displaying HTTP method badge, endpoint/URL, status code badge, duration, timestamp, size, and visual status indicators (success, failure, error). | Supported by `RequestTile` component combining M3 badge styling, `NetworkRecord` model properties, and discrete in-repo enums `NetworkStatus` (`pending`, `success`, `failed`) [VERIFIED: lib/src/models/network_status.dart:2-10]. |
| **UI-02** | Efficient batch pagination and infinite scrolling on listing screen avoiding full-table memory loads. | Supported by `ScrollController` listener triggering fetch when scroll depth >= 80% with page limit 50 via `NetworkInspectorRepository.getRecords(limit: 50, offset: offset)`. |
| **UI-03** | Multi-parameter search across URL, endpoint, method, status code, and payload text. | Supported by Material 3 `SearchBar` with 300ms reactive debounce mapped to `RecordFilter(searchQuery: query)` [VERIFIED: lib/src/models/record_filter.dart:5-40]. |
| **UI-04** | Robust filters by HTTP method, status code categories (2xx, 3xx, 4xx, 5xx), success/error, date range, and duration. | Supported by horizontal `FilterChip` quick-bar and modal bottom sheet with `RecordFilter(httpMethods, statusCodes, errorOnly, minDurationMs, maxDurationMs, startDate, endDate)`. |
| **UI-05** | Sorting options: newest first, oldest first, fastest, slowest, and status code. | Supported by AppBar sort popup menu mapped to in-repo `RecordSort` presets (`newestFirst`, `oldestFirst`, `fastestFirst`, `slowestFirst`, `RecordSortField.statusCode`) [VERIFIED: lib/src/models/record_sort.dart:63-84]. |
| **UI-06** | Clear-all captured records action with confirmation prompt. | Supported by Material 3 `AlertDialog` confirming deletion and invoking `NetworkInspectorRepository.clearAll()` [VERIFIED: lib/src/repository/network_inspector_repository.dart:28-29]. |
| **UI-07** | API details screen with tabbed sections: Overview, Request Headers, Query Parameters, Request Body, Response Headers, Response Body, Multipart Info, and Error Details. | Supported by 4-tab `NetworkInspectorDetailScreen` (Overview, Request, Response, Error) using `DefaultTabController` and M3 `TabBar`/`TabBarView` bound to `NetworkRecord`. |
| **UI-08** | Formatted JSON visualization with syntax formatting, expandable tree/raw view toggle, and background isolate parsing for large payloads. | Supported by `compute(formatJsonString, payload)` for payloads > 50KB and pure Dart regex tokenization into `SelectableText.rich` for syntax highlighting without third-party dependencies. |
| **UI-09** | Clipboard copy actions for full URL, request headers, response headers, request body, and response body. | Supported by Flutter's built-in `Clipboard.setData(ClipboardData(text: ...))` accompanied by lightweight `ScaffoldMessenger.of(context).showSnackBar`. |
| **UI-10** | cURL command generator producing copyable, properly escaped cURL CLI commands. | Supported by `CurlGenerator` utility parsing `NetworkRecord` into multi-line bash-escaped commands with single-quote escaping (`\'` replaced with `'\''`) and line continuations (`\`). |
| **UI-11** | Native platform share sheet export via `share_plus` generating formatted text reports with options to exclude sensitive data. | Supported by `share_plus: ^13.3.1` with `SharePlus.instance.share(ShareParams(...))` and safe `sharePositionOrigin` calculation to prevent iPadOS/macOS popover crashes. |
</phase_requirements>

## Summary

Phase 04 delivers the complete visual inspection and developer export experience for the Flutter Network Inspector package. Built entirely with Flutter's Material 3 design system and standard widgets, the UI gives developers full transparency into HTTP network traffic captured by Phase 03 interceptors and persisted by Phase 02 SQLite storage.

The user interface is cleanly split into two core destinations: `NetworkInspectorScreen` (a paginated, debounced-search, and filterable listing view) and `NetworkInspectorDetailScreen` (a 4-tab deep inspector covering Overview, Request, Response, and Error diagnostics). Every detail view integrates granular clipboard copying, multi-line bash-escaped cURL generation, and multi-format sharing (Markdown summary, cURL, or full JSON) via `share_plus`.

Crucially, this phase adheres to zero-dependency UI principles: syntax highlighting uses lightweight pure Dart regex tokenization within `SelectableText.rich`, eliminating fragile third-party syntax packages (`flutter_highlight` / `flutter_json_view`). Background isolate offloading via `compute()` ensures large payloads (> 50KB) never drop UI frames, and strict iPadOS anchor calculation prevents native popover crashes.

**Primary recommendation:** Build `NetworkInspectorScreen` and `NetworkInspectorDetailScreen` as standalone Material 3 widgets backed by `NetworkInspectorRepository`, using pure Dart `SelectableText.rich` regex tokenization for JSON syntax highlighting and `share_plus: ^13.3.1` wrapped with a safe `ShareExporter` anchor utility.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| **Screen Navigation & Deduplication** | Browser / Client | — | `NetworkInspector.open(context)` pushes `NetworkInspectorScreen` onto root navigator; internal `_isOpen` boolean prevents duplicate routes on rapid shakes. |
| **Theme Mode Override (System / Light / Dark)** | Browser / Client | — | Local `ThemeController` / `ValueNotifier<ThemeMode>` wrapping inspector routes with M3 `Theme` widget without mutating host app's global theme. |
| **Paginated Record Querying** | Browser / Client | Storage / Repo | `InspectorViewModel` maintains scroll state, triggering `NetworkInspectorRepository.getRecords(filter, sort, limit: 50, offset)` at 80% scroll depth. |
| **Search Debounce & Quick Filters** | Browser / Client | Storage / Repo | `TextEditingController` with 300ms `Timer` debounce converts text and `FilterChip` selections into immutable `RecordFilter` query objects. |
| **Large Payload JSON Formatting** | Background Isolate | Browser / Client | Flutter's `compute()` formats JSON strings > 50KB off the main UI isolate; payloads <= 50KB format synchronously. |
| **JSON Syntax Highlighting** | Browser / Client | — | Pure Dart regex scanner converts formatted JSON strings into styled `TextSpan` trees rendered inside `SelectableText.rich`. |
| **cURL Command Generation** | Client Utility | — | Pure Dart string formatter maps `NetworkRecord` headers, method, URL, and body into bash-escaped CLI commands with line continuations. |
| **Share Sheet Export** | Browser / Client | Native OS Sheet | `ShareExporter` extracts `RenderBox` bounds for iPadOS `sharePositionOrigin` and invokes `SharePlus.instance.share(ShareParams(...))`. |
| **Clear All Confirmation & Execution** | Browser / Client | Storage / Repo | Material 3 `AlertDialog` confirms deletion and delegates to `NetworkInspectorRepository.clearAll()`. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **Flutter SDK** | `>=3.10.0` | Cross-platform UI, Material 3, navigation | Standard Flutter framework providing Material 3 widgets (`SearchBar`, `FilterChip`, `Card`, `TabBarView`, `SelectableText.rich`, `compute`). |
| **`share_plus`** | `^13.3.1` [VERIFIED: pub.dev registry] | Native OS share sheet export across iOS, Android, macOS, Windows, Linux, and Web | Official Flutter Community Plus plugin. Resolves native sharing via `ACTION_SEND` and `UIActivityViewController`. |
| **`intl`** | `^0.20.3` [VERIFIED: pub.dev registry] | Human-readable date, timestamp, and duration formatting | Official Dart team package (`dart-lang/i18n`) for standardized timestamp (`HH:mm:ss.SSS`, `yyyy-MM-dd HH:mm:ss`) formatting. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **`flutter_test`** | SDK | Widget, golden, and integration testing harness | Used for verifying listing screen, detail tabs, search interactions, and JSON formatting in headless CI. |
| **`mocktail`** | `^1.0.5` [VERIFIED: pub.dev registry] | Reflection-free, code-gen-free mock objects for testing | Mocking `NetworkInspectorRepository` and navigation observers in widget tests. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **Pure Dart Regex + `SelectableText.rich`** | `flutter_json_view` / `flutter_highlight` | Rejected: Third-party viewers pull heavy grammars, break across Flutter major versions, and lack responsive clipboard selection. Pure Dart regex has 0 dependencies and runs safely on all platforms. |
| **`share_plus`** | Custom Platform Channels | Rejected: Custom Swift/Kotlin/C++ platform code requires high maintenance overhead and lacks automatic cross-platform coverage. `share_plus` is officially maintained by the Flutter Community. |
| **Flutter `compute()`** | Manual `Isolate.spawn` | Rejected: `compute()` automatically handles isolate lifecycle, error handling, message passing, and falls back seamlessly to synchronous execution on Flutter Web. |

**Installation:**
Add to `pubspec.yaml`:
```yaml
dependencies:
  share_plus: ^13.3.1
  intl: ^0.20.3
```

**Version verification:**
Verified against pub.dev registry on 2026-11-01:
- `share_plus`: `13.3.1` (published by `fluttercommunity.dev`, repository: `https://github.com/fluttercommunity/plus_plugins`)
- `intl`: `0.20.3` (published by `dart.dev`, repository: `https://github.com/dart-lang/i18n`)
- `mocktail`: `1.0.5` (published by `felangel.com`, repository: `https://github.com/felangel/mocktail`)

## Package Legitimacy Audit

| Package | Registry | Age | Versions | Source Repo | Verdict | Disposition |
|---------|----------|-----|----------|-------------|---------|-------------|
| `share_plus` | pub.dev | ~6 yrs | 89 | `https://github.com/fluttercommunity/plus_plugins` | `[OK]` | Approved |
| `intl` | pub.dev | ~12 yrs | 140 | `https://github.com/dart-lang/i18n` | `[OK]` | Approved |
| `mocktail` | pub.dev | ~4 yrs | 12 | `https://github.com/felangel/mocktail` | `[OK]` | Approved |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none  

## Architecture Patterns

### System Architecture Diagram

```
+---------------------------------------------------------------------------------+
|                       Host Application / Developer Gesture                      |
|                                                                                 |
|   NetworkInspector.open(context)       Device Shake (Phase 5 SHAKE-01)          |
+-----------------------------------+---------------------------------------------+
                                    |
                                    v
                     +------------------------------+
                     |  _isOpen Navigation Guard    |  [D-51: Suppress duplicates]
                     +--------------+---------------+
                                    |
                                    v
                     +------------------------------+
                     |   NetworkInspectorScreen     |  [D-49: Full-screen M3 route]
                     |   (Main Listing & Search)    |  [D-50: Theme toggle override]
                     +--------------+---------------+
                                    |
        +---------------------------+---------------------------+
        |                           |                           |
        v                           v                           v
+----------------+          +----------------+          +----------------+
| M3 SearchBar   |          | Quick Filters  |          | Paginated List |
| (300ms Debounce|          | Horizontal Bar |          | 50/page, 80%   |
| URL/body text) |          | & Modal Sheet  |          | infinite scroll|
+-------+--------+          +-------+--------+          +-------+--------+
        |                           |                           |
        +---------------------------+---------------------------+
                                    |
                                    v
                     +------------------------------+
                     |  NetworkInspectorRepository  |
                     |  getRecords(filter, sort,    |
                     |             limit, offset)   |
                     +--------------+---------------+
                                    |
                        User taps a record tile
                                    |
                                    v
                     +------------------------------+
                     | NetworkInspectorDetailScreen |  [D-57: 4 Main Tabs]
                     +--------------+---------------+
                                    |
       +-----------------+----------+----------+-----------------+
       |                 |                     |                 |
       v                 v                     v                 v
+--------------+  +--------------+      +--------------+  +--------------+
| Overview Tab |  | Request Tab  |      | Response Tab |  | Error Tab    |
| Status, URL, |  | Headers,     |      | Headers,     |  | Exception,   |
| Latency, Size|  | Query, Body, |      | Body, Size,  |  | Stack Trace, |
| Timestamps   |  | Multipart    |      | Status code  |  | Diagnostics  |
+--------------+  +------+-------+      +------+-------+  +--------------+
                         |                     |
                         +----------+----------+
                                    |
                                    v
                     +------------------------------+
                     |     JsonViewerWidget         |  [D-58: Pure Flutter M3]
                     |  - compute() if > 50KB       |  [D-59: Isolate offloading]
                     |  - SelectableText.rich       |  [D-60: Granular copy]
                     |  - Raw / Pretty Toggle       |
                     +--------------+---------------+
                                    |
                       Export & Sharing Actions
                                    |
       +----------------------------+----------------------------+
       |                                                         |
       v                                                         v
+------------------------------+          +------------------------------+
|       CurlGenerator          |          |        ShareExporter         |
|  - Bash single-quote escape  |          |  - Share as Markdown Summary |
|  - Line continuations (\)    |          |  - Share as cURL CLI         |
|  - -X, -H, --data-raw        |          |  - Share as Full JSON        |
|  [D-61: Terminal-executable] |          |  - iPadOS anchor protection  |
+------------------------------+          |  - Pre-redacted DB records   |
                                          |  - Optional exclude headers  |
                                          |  [D-62, D-63, D-64]          |
                                          +------------------------------+
```

### Recommended Project Structure
```
lib/src/
├── ui/
│   ├── network_inspector_screen.dart            # Main listing screen (UI-01, UI-02, D-49, D-56)
│   ├── network_inspector_detail_screen.dart     # 4-tab details screen (UI-07, D-57)
│   ├── components/
│   │   ├── request_tile.dart                    # Two-line card tile with badges (UI-01, D-53)
│   │   ├── search_bar_view.dart                 # M3 SearchBar with clear icon (UI-03, D-54)
│   │   ├── filter_chips_bar.dart                # Quick-filter horizontal chip bar (UI-04, D-55)
│   │   ├── filter_bottom_sheet.dart             # Modal sheet for advanced filtering (UI-04, D-55)
│   │   ├── sort_menu_button.dart                # AppBar popup menu for sorting (UI-05)
│   │   ├── clear_all_dialog.dart                # M3 confirmation dialog (UI-06, D-28)
│   │   ├── status_badge.dart                    # Color-coded method and status badges (D-53)
│   │   ├── copy_button.dart                     # Granular clipboard copy with SnackBar (UI-09, D-60)
│   │   ├── export_action_sheet.dart             # Multi-format share sheet picker (UI-11, D-62)
│   │   └── json_viewer.dart                     # M3 formatted JSON viewer (UI-08, D-58, D-59)
│   ├── controllers/
│   │   ├── inspector_view_model.dart            # State controller for listing, search, pagination
│   │   └── theme_controller.dart                # ThemeMode state (System, Light, Dark) (D-50)
│   └── utils/
│       ├── curl_generator.dart                  # Terminal-executable cURL generator (UI-10, D-61)
│       ├── json_format_isolate.dart             # Background compute isolate formatter (D-59)
│       └── share_exporter.dart                  # Safe SharePlus dispatcher with anchor (D-64)
```

### In-Repo Discrete Values & Enums

The following in-repo discrete values are verified from the codebase and MUST be referenced directly:

#### 1. `NetworkStatus`
Source: `lib/src/models/network_status.dart:2-10` [VERIFIED: lib/src/models/network_status.dart:2-10]
```dart
enum NetworkStatus {
  /// Request has been sent/intercepted and is awaiting server response.
  pending,

  /// Request completed with a valid HTTP response.
  success,

  /// Request encountered a network error, socket exception, timeout, or failure.
  failed;
```

#### 2. `BodyType`
Source: `lib/src/models/body_type.dart:2-19` [VERIFIED: lib/src/models/body_type.dart:2-19]
```dart
enum BodyType {
  /// Structured JSON format.
  json,

  /// Plain text, HTML, XML, or unstructured string content.
  text,

  /// URL-encoded form data (`application/x-www-form-urlencoded`).
  formData,

  /// Multi-part form data containing parameters and file upload references.
  multipart,

  /// Binary octet stream or raw byte content.
  binary,

  /// Empty or absent request/response body.
  empty;
```

#### 3. `RecordSortField` & `SortOrder`
Source: `lib/src/models/record_sort.dart:4-35` [VERIFIED: lib/src/models/record_sort.dart:4-35]
```dart
enum RecordSortField {
  /// Sort by request timestamp.
  timestamp,

  /// Sort by total transaction duration.
  duration,

  /// Sort by HTTP response status code.
  statusCode,

  /// Sort alphabetically by full request URL.
  url,

  /// Sort by response payload size.
  size;
}

enum SortOrder {
  ascending,
  descending;
}
```

Pre-configured `RecordSort` constants:
Source: `lib/src/models/record_sort.dart:63-84` [VERIFIED: lib/src/models/record_sort.dart:63-84]
```dart
  static const newestFirst = RecordSort(
    field: RecordSortField.timestamp,
    order: SortOrder.descending,
  );

  static const oldestFirst = RecordSort(
    field: RecordSortField.timestamp,
    order: SortOrder.ascending,
  );

  static const slowestFirst = RecordSort(
    field: RecordSortField.duration,
    order: SortOrder.descending,
  );

  static const fastestFirst = RecordSort(
    field: RecordSortField.duration,
    order: SortOrder.ascending,
  );
```

#### 4. `NetworkInspectorConstants`
Source: `lib/src/core/constants.dart:6-33` [VERIFIED: lib/src/core/constants.dart:6-33]
```dart
  static const int defaultMaxRecords = 500;
  static const int defaultMaxBodyBytes = 1048576;
  static const String redactedPlaceholder = '[REDACTED]';
  static const String internalTrackingHeader = 'x-fl-net-inspector-tracked-id';
  static const String headerInspectorId = 'x-network-inspector-id';
```

### Pattern 1: Navigation Deduplication & Root Navigator Resolution
**What:** Preventing multiple inspector instances on rapid shake or multiple taps while ensuring overlays cover bottom navigation bars.  
**When to use:** In `NetworkInspector.open(BuildContext context)`.  
**Example:**
```dart
final class NetworkInspector {
  static bool _isOpen = false;

  /// Programmatically opens the inspector UI screen (D-49, D-51, D-52).
  static Future<void> open(BuildContext context) async {
    if (!isEnabled || _isOpen) return;

    _isOpen = true;
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (context) => const NetworkInspectorScreen(),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _isOpen = false;
    }
  }
}
```

### Pattern 2: Reactive Debounced Search & Infinite Scrolling
**What:** Combining a 300ms debounce on `SearchBar` inputs with threshold-based infinite scrolling at 80% scroll depth.  
**When to use:** In `NetworkInspectorScreen` / `InspectorViewModel`.  
**Example:**
```dart
class _NetworkInspectorScreenState extends State<NetworkInspectorScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  
  static const int _pageSize = 50;
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  List<NetworkRecord> _records = [];
  RecordFilter _filter = RecordFilter.empty;
  RecordSort _sort = RecordSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filter = _filter.copyWith(searchQuery: query.trim().isEmpty ? null : query.trim());
        _resetAndReload();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

### Pattern 3: Offloaded JSON Formatting for Large Payloads
**What:** Offloading heavy `JsonEncoder.withIndent` formatting to a background isolate for bodies > 50KB to preserve 60fps responsiveness.  
**When to use:** In `JsonViewerWidget` when `rawPayload.length > 50 * 1024`.  
**Example:**
```dart
/// Top-level isolate entrypoint for JSON string formatting.
String formatJsonIsolate(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return rawJson;
  }
}

Future<String> formatJsonBody(String rawJson) async {
  if (rawJson.length > 50 * 1024) {
    return compute(formatJsonIsolate, rawJson);
  } else {
    return formatJsonIsolate(rawJson);
  }
}
```

### Pattern 4: Safe Share Sheet Anchor for iPadOS & macOS
**What:** Passing `sharePositionOrigin` calculated from the triggering widget's `RenderBox` to avoid fatal `NSGenericException` crashes on iPadOS.  
**When to use:** Whenever `SharePlus.instance.share(ShareParams(...))` is called.  
**Example:**
```dart
abstract final class ShareExporter {
  static Rect calculateAnchor(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      return renderBox.localToGlobal(Offset.zero) & renderBox.size;
    }
    final size = MediaQuery.sizeOf(context);
    return (size.center(Offset.zero) & const Size(1, 1));
  }

  static Future<void> shareText({
    required BuildContext context,
    required String text,
    String? subject,
  }) async {
    final origin = calculateAnchor(context);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
}
```

### Anti-Patterns to Avoid
- **Hardcoding Color Constants:** Using `Colors.black` or `Colors.white` directly in UI components. This breaks dark/light theme switching. Always use `Theme.of(context).colorScheme`.
- **Loading Full Database into Memory:** Calling `repository.getRecords(limit: 10000)` without pagination. Always paginate with `limit: 50` and `offset: currentOffset`.
- **Executing Heavy String Manipulation on UI Isolate:** Pretty-printing 500KB JSON strings synchronously during `build()`. Always check `> 50KB` and offload via `compute()`.
- **Calling `Share.share` without Anchor:** Calling share on iPadOS without `sharePositionOrigin`. Always compute the button's `RenderBox` bounding `Rect`.
- **Uncancelled Debounce Timers:** Leaving `_debounceTimer` active when popping a screen. Always invoke `_debounceTimer?.cancel()` in `dispose()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| **Syntax Highlighting Dependencies** | Custom grammar parser or third-party viewer packages (`flutter_highlight`, `flutter_json_view`) | Pure Dart regex tokenization into `TextSpan` + `SelectableText.rich` | Third-party packages break across major Flutter releases and lag Material 3 tokens. Pure regex tokenization is zero-dependency, crash-free, and supports native text selection. |
| **Native Share Sheet Dispatching** | Custom Swift / Kotlin platform channels | `share_plus: ^13.3.1` | Native sharing on Android (`ACTION_SEND`) and iOS (`UIActivityViewController`) has complex edge cases on tablets and desktop windows. `share_plus` is battle-tested. |
| **Isolate Worker Thread Management** | Raw `ReceivePort`, `SendPort`, and `Isolate.spawn` | Flutter's `compute()` | `compute()` manages worker isolate creation, message marshaling, cleanup, and falls back seamlessly to synchronous execution on Flutter Web. |
| **Timestamp Formatting** | Custom string splitting and date math | `intl: ^0.20.3` (`DateFormat`) | Formatting dates with timezone offsets, padding, and millisecond precision is error-prone. `intl` handles standard formats (`HH:mm:ss.SSS`) robustly. |
| **Data Access & Relational Filtering** | Custom SQL queries in UI widgets | `NetworkInspectorRepository.getRecords(filter, sort)` | UI widgets should remain decoupled from SQLite and in-memory storage implementations. |

## Runtime State Inventory

> Greenfield feature phase (not a rename/refactor/migration phase).  
> Step 2.5: SKIPPED (no preexisting stored data, runtime keys, or OS tasks require migration).

## Common Pitfalls

### Pitfall 1: iPadOS / macOS Desktop Popover Anchor Crash
**What goes wrong:** Tapping "Share" in `NetworkInspectorDetailScreen` causes the application to crash immediately with `NSGenericException: Your application has presented a UIActivityViewController... without providing an anchor view`.  
**Why it happens:** iPadOS and macOS present share sheets as popover menus rather than bottom sheets, requiring iOS to know which screen coordinate the arrow points to.  
**How to avoid:** Always extract `sharePositionOrigin` using `renderBox.localToGlobal(Offset.zero) & renderBox.size` via `ShareExporter` with a safe fallback to screen center.  
**Warning signs:** Works on iPhone simulator but crashes instantly on iPad simulator or physical iPad.

### Pitfall 2: UI Freezes During Large JSON Pretty-Printing
**What goes wrong:** Tapping the Response tab on a 300KB JSON payload causes noticeable UI stutter, dropped frames, or brief application freeze.  
**Why it happens:** `jsonDecode` and `JsonEncoder.withIndent('  ')` are CPU-intensive string operations executing on the single main UI thread.  
**How to avoid:** When payload string length exceeds `50 * 1024` bytes (50KB), display a loading spinner and process the string using `compute(formatJsonIsolate, rawPayload)` (D-59).  
**Warning signs:** Flutter DevTools Performance overlay displays long red bars on the UI thread when opening large response bodies.

### Pitfall 3: Route Stacking & Duplicate Navigation on Rapid Shakes
**What goes wrong:** Shaking the physical device vigorously or tapping a debug launcher button multiple times pushes 3-5 duplicate `NetworkInspectorScreen` routes onto the navigation stack.  
**Why it happens:** Navigation push calls are asynchronous and take several milliseconds to transition; multiple events trigger while the route is animating.  
**How to avoid:** Maintain a private static `_isOpen` boolean flag on `NetworkInspector` set to `true` before `navigator.push` and reset to `false` in a `finally` block or route pop callback (D-51).  
**Warning signs:** Pressing the AppBar back button on the inspector reveals another identical inspector screen beneath it.

### Pitfall 4: Memory Leak in Search Debounce Timer
**What goes wrong:** User types into `SearchBar`, quickly pops the inspector screen before 300ms elapse, and Flutter logs `setState() called after dispose()`.  
**Why it happens:** The uncancelled `Timer` fires after the widget has been unmounted from the tree.  
**How to avoid:** Store the timer in `Timer? _debounceTimer;`, explicitly call `_debounceTimer?.cancel()` in `dispose()`, and check `if (!mounted) return;` inside the timer callback.  
**Warning signs:** Red error messages in the debug console during widget testing or rapid screen navigation.

### Pitfall 5: Bash Execution Errors in Generated cURL Commands
**What goes wrong:** Pasting a generated cURL command into the macOS/Linux terminal results in `bash: syntax error near unexpected token` or truncated requests.  
**Why it happens:** Request headers, URLs, or payload bodies contain unescaped single quotes (`'`), causing the shell to terminate the single-quoted argument prematurely.  
**How to avoid:** In bash, single quotes inside single-quoted strings must be escaped as `'\''` (close quote, literal escaped quote, reopen quote). Replace all `'` in header values and bodies with `'\''` (D-61).  
**Warning signs:** Generated cURL command fails when tested in terminal with payloads containing apostrophes (e.g. `{"message": "it's working"}`).

## Code Examples

### 1. Bash-Escaped cURL Generator (`curl_generator.dart`)
```dart
import 'dart:convert';
import '../models/network_record.dart';

abstract final class CurlGenerator {
  /// Generates a copyable, terminal-executable cURL command from a [NetworkRecord] (UI-10, D-61).
  static String fromRecord(NetworkRecord record) {
    final buffer = StringBuffer();
    buffer.write('curl -X ${record.method.toUpperCase()} \\\n');
    buffer.write("  '${_escapeBash(record.url)}'");

    // Add headers
    for (final entry in record.requestHeaders.entries) {
      // Omit pseudo-headers or transport tracking headers
      if (entry.key.startsWith(':')) continue;
      final key = _escapeBash(entry.key);
      final value = _escapeBash(entry.value.toString());
      buffer.write(' \\\n');
      buffer.write("  -H '$key: $value'");
    }

    // Add request body if present
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

### 2. Zero-Dependency JSON Syntax Colorizer (`json_viewer.dart`)
```dart
import 'package:flutter/material.dart';

class JsonViewerWidget extends StatelessWidget {
  final String formattedJson;
  final bool isDark;

  const JsonViewerWidget({
    super.key,
    required this.formattedJson,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildSyntaxSpan(formattedJson),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.4,
      ),
    );
  }

  TextSpan _buildSyntaxSpan(String input) {
    final pattern = RegExp(
      r'("([^"\\]|\\.)*")\s*:\s*|'             // 1: Keys
      r'("[^"\\]*(\\.[^"\\]*)*")\s*(?!:)|'     // 2: String values
      r'(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*|' // 3: Numbers
      r'\b(true|false)\s*|'                     // 4: Booleans
      r'\b(null)\s*',                           // 5: Nulls
    );

    final keyColor = isDark ? Colors.lightBlueAccent : Colors.indigo;
    final stringColor = isDark ? Colors.lightGreenAccent : Colors.green[800]!;
    final numColor = isDark ? Colors.orangeAccent : Colors.deepOrange;
    final boolColor = isDark ? Colors.purpleAccent : Colors.purple[700]!;
    final nullColor = Colors.grey;
    final defaultColor = isDark ? Colors.white70 : Colors.black87;

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final Match match in pattern.allMatches(input)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: input.substring(lastEnd, match.start),
          style: TextStyle(color: defaultColor),
        ));
      }

      TextStyle style = TextStyle(color: defaultColor);
      if (match.group(1) != null) {
        style = TextStyle(color: keyColor, fontWeight: FontWeight.w600);
      } else if (match.group(2) != null) {
        style = TextStyle(color: stringColor);
      } else if (match.group(3) != null) {
        style = TextStyle(color: numColor);
      } else if (match.group(4) != null) {
        style = TextStyle(color: boolColor, fontWeight: FontWeight.bold);
      } else if (match.group(5) != null) {
        style = TextStyle(color: nullColor, fontStyle: FontStyle.italic);
      }

      spans.add(TextSpan(text: match.group(0), style: style));
      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      spans.add(TextSpan(
        text: input.substring(lastEnd),
        style: TextStyle(color: defaultColor),
      ));
    }

    return TextSpan(children: spans);
  }
}
```

### 3. Share Exporter with Safe Anchor (`share_exporter.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/network_record.dart';
import 'curl_generator.dart';

abstract final class ShareExporter {
  /// Safely presents a share sheet with iPadOS anchor view protection (UI-11, D-64).
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

  static String _toMarkdown(NetworkRecord record, bool excludeHeaders) {
    final buffer = StringBuffer();
    buffer.writeln('# Network Request: ${record.method} ${record.url}');
    buffer.writeln('- **Status**: ${record.responseStatusCode ?? "Pending"}');
    buffer.writeln('- **Duration**: ${record.durationMs ?? 0}ms');
    buffer.writeln('- **Timestamp**: ${record.requestTimestamp}');
    if (!excludeHeaders && record.requestHeaders.isNotEmpty) {
      buffer.writeln('\n## Request Headers\n```\n${record.requestHeaders}\n```');
    }
    if (record.requestBody?.body != null) {
      buffer.writeln('\n## Request Body\n```\n${record.requestBody!.body}\n```');
    }
    if (!excludeHeaders && record.responseHeaders != null) {
      buffer.writeln('\n## Response Headers\n```\n${record.responseHeaders}\n```');
    }
    if (record.responseBody?.body != null) {
      buffer.writeln('\n## Response Body\n```\n${record.responseBody!.body}\n```');
    }
    if (record.error != null) {
      buffer.writeln('\n## Error\n- Message: ${record.error!.message}');
      if (record.error!.stackTrace != null) {
        buffer.writeln('```\n${record.error!.stackTrace}\n```');
      }
    }
    return buffer.toString();
  }

  static String _toJsonSummary(NetworkRecord record, bool excludeHeaders) {
    final map = record.toMap();
    if (excludeHeaders) {
      map.remove('request_headers');
      map.remove('response_headers');
    }
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

enum ShareFormat { markdown, curl, json }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Share.share(text)` static method | `SharePlus.instance.share(ShareParams(...))` | `share_plus` 11.0.0+ | Avoids deprecated static methods; structured parameters support typed exclusions, anchors, and files cleanly. |
| Third-party JSON viewer packages (`flutter_json_view`) | Pure Dart regex syntax tokenizer into `SelectableText.rich` | Flutter 3.10+ | Zero dependency conflicts, instant compilation, supports native selection and Material 3 theming. |
| Heavy `TextField` with custom search decorations | Flutter Material 3 `SearchBar` | Flutter 3.10+ | Built-in M3 elevation, surface tint, search icon, clear trailing action, and accessibility support. |
| Foreground `jsonEncode` stringification | Background `compute()` isolate parsing for bodies > 50KB | Flutter 3.x | Guarantees zero dropped frames / jank on large JSON responses while running smoothly on mobile, desktop, and web. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SharePlus.instance.share(ShareParams(...))` is the recommended modern API in `share_plus: 13.3.1` [VERIFIED: pub.dev registry]. | Standard Stack / Code Examples | Low. Fallback to `Share.share(text, sharePositionOrigin: origin)` exists if deprecated bridge is required. |
| A2 | Background isolate offloading using `compute()` functions safely across Flutter platforms (falls back to synchronous execution on Web). | Architecture Patterns / D-59 | Low. Verified in Flutter foundation docs. |

## Open Questions (RESOLVED)

1. **Host App GlobalKey<NavigatorState>? in `NetworkInspectorConfig` (RESOLVED)**
   - What we know: Decision D-52 mentions: "optional fallback to `NetworkInspectorConfig.navigatorKey` if provided".
   - Current state: `NetworkInspectorConfig` currently does not have a `navigatorKey` field.
   - Resolution: RESOLVED: Add optional `final GlobalKey<NavigatorState>? navigatorKey;` to `NetworkInspectorConfig` in Phase 04 per D-52 so host apps with complex shell/nested routing can pass their root key. Scheduled in Plan 04-01 Task 1.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Material 3 UI widgets & tests | ✓ | 3.10+ compatible | — |
| Dart SDK | Core language runtime & isolates | ✓ | 3.x | — |
| `share_plus` | Native OS share sheet export (UI-11) | ✓ (pub.dev) | 13.3.1 | Copy to clipboard fallback (`UI-09`) |
| `intl` | Timestamp & date formatting | ✓ (pub.dev) | 0.20.3 | Built-in `DateTime.toIso8601String()` |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Flutter SDK) |
| Config file | `pubspec.yaml` |
| Quick run command | `flutter test test/ui/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| **UI-01** | Listing screen displays method badge, URL, status code, duration, size | widget | `flutter test test/ui/network_inspector_screen_test.dart` | ❌ Wave 0 |
| **UI-02** | Infinite scrolling & pagination auto-fetches next 50 records at 80% scroll | widget | `flutter test test/ui/pagination_test.dart` | ❌ Wave 0 |
| **UI-03** | Multi-parameter search filters records by URL, status, and payload text | widget | `flutter test test/ui/search_test.dart` | ❌ Wave 0 |
| **UI-04** | Method & status code quick chips and modal filter sheet filter records | widget | `flutter test test/ui/filter_test.dart` | ❌ Wave 0 |
| **UI-05** | Sorting by newest, oldest, duration, and status code alters record order | widget | `flutter test test/ui/sorting_test.dart` | ❌ Wave 0 |
| **UI-06** | Clear All confirmation prompt triggers `repository.clearAll()` | widget | `flutter test test/ui/clear_all_test.dart` | ❌ Wave 0 |
| **UI-07** | Details screen presents Overview, Request, Response, Error tabs | widget | `flutter test test/ui/network_inspector_detail_screen_test.dart` | ❌ Wave 0 |
| **UI-08** | JSON formatting, pretty/raw toggle, and background isolate parsing | unit/widget | `flutter test test/ui/json_viewer_test.dart` | ❌ Wave 0 |
| **UI-09** | Clipboard copy buttons trigger `Clipboard.setData` with confirmation SnackBar | widget | `flutter test test/ui/clipboard_copy_test.dart` | ❌ Wave 0 |
| **UI-10** | cURL generator produces valid bash-escaped multi-line CLI commands | unit | `flutter test test/ui/curl_generator_test.dart` | ❌ Wave 0 |
| **UI-11** | Share exporter produces Markdown, cURL, JSON text with safe anchor origin | unit/widget | `flutter test test/ui/share_exporter_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/ui/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full test suite passes cleanly before phase completion

### Wave 0 Gaps
- [ ] Add `share_plus: ^13.3.1` and `intl: ^0.20.3` to `pubspec.yaml`
- [ ] Add `navigatorKey` property to `NetworkInspectorConfig`
- [ ] Create `test/ui/helpers/test_record_fixtures.dart` providing standardized mock `NetworkRecord` instances

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| **V2 Authentication** | no | Inspector is a client diagnostic harness; does not manage user authentication credentials directly. |
| **V3 Session Management** | no | Session lifecycles are owned by the host app. |
| **V4 Access Control** | yes | Inspector access is disabled in release builds by default (`kReleaseMode` per `CORE-01`, `D-03`). Internal `_isOpen` guard prevents unauthorized or duplicate view presentation. |
| **V5 Input Validation** | yes | Search queries, status codes, and duration inputs in filter sheets are validated and bounds-checked to prevent regex injection or memory denial-of-service. |
| **V6 Cryptography** | yes | Zero custom cryptography. Stored network records retain pre-persistence redaction (`[REDACTED]`). Export action sheet provides optional "Exclude all headers" checkbox (`D-63`) for sharing privacy. |

### Known Threat Patterns for Flutter UI & Export

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive credential leakage in share sheet export | Information Disclosure | Default export to already-redacted database records (`D-09`–`D-12`); provide explicit "Exclude all headers" toggle (`D-63`) in export action sheet. |
| Denial of Service / App Freeze via massive JSON bodies | Denial of Service | Isolate worker execution via `compute()` for payloads > 50KB (`D-59`); payload truncation capped at 1MB (`DATA-05`). |
| Host App Navigation Hijack / Overlay Bypass | Elevation of Privilege | Use root navigator (`rootNavigator: true`) with optional `navigatorKey` to cleanly overlay modal sheets and shell navigators (`D-52`). |
| Native popover crash on iPadOS/macOS | Denial of Service | Centralized `ShareExporter` calculates `RenderBox` bounds with fallback to screen center (`D-64`). |

## Sources

### Primary (HIGH confidence)
- Official pub.dev Registry: `share_plus` 13.3.1 (`https://pub.dev/packages/share_plus`)
- Official pub.dev Registry: `intl` 0.20.3 (`https://pub.dev/packages/intl`)
- Flutter Official Documentation: `compute` function & isolate concurrency (`https://docs.flutter.dev/perf/isolates`)
- Flutter Official Documentation: Material 3 `SearchBar`, `FilterChip`, `SelectableText` (`https://docs.flutter.dev/ui/design/material`)
- In-Repo Source Code:
  - `lib/src/models/network_status.dart:2-10`
  - `lib/src/models/body_type.dart:2-19`
  - `lib/src/models/record_sort.dart:4-84`
  - `lib/src/models/record_filter.dart:5-40`
  - `lib/src/core/constants.dart:6-33`
  - `lib/src/repository/network_inspector_repository.dart:7-36`

### Secondary (MEDIUM confidence)
- Apple Developer Documentation & Flutter Community: `UIActivityViewController` iPadOS `popoverPresentationController.sourceRect` crash remediation.
- Bash Shell Syntax Guide: Single quote escaping in bash arguments via `'\''`.

### Tertiary (LOW confidence)
- None. All packages and APIs verified via pub.dev registry or official Flutter documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — packages verified on pub.dev registry (`share_plus: 13.3.1`, `intl: 0.20.3`).
- Architecture: HIGH — patterns conform directly to Flutter Material 3 standards and user decisions in `04-CONTEXT.md`.
- Pitfalls: HIGH — iPadOS anchor requirements, isolate compute rules, and search debounce memory leaks are well-documented.

**Research date:** 2026-11-01  
**Valid until:** 2026-12-01 (stable Flutter M3 and pub.dev package APIs)  
