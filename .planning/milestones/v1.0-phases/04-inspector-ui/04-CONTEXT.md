# Phase 4: Inspector UI - Context

**Gathered:** 2026-11-01  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Design, implement, and verify an in-app Material 3 debugging user interface (`NetworkInspectorScreen` and `NetworkInspectorDetailScreen`) for browsing, searching, filtering, inspecting, formatting, and exporting captured HTTP traffic across mobile, desktop, and web platforms, decoupled from external dependencies and backed by `NetworkInspectorRepository`.

</domain>

<decisions>
## Implementation Decisions

### Navigation & Theme Integration
- **D-49:** Full-screen Material route (`Navigator.push`) for the main inspector screen (`NetworkInspectorScreen`), maximizing screen real estate for browsing records and deep multi-tab inspection with standard AppBar back navigation — **Reversibility:** costly — Defines public navigation signatures and screen scaffolding.
- **D-50:** Theming strategy: Inherit host app's `Theme.of(context)` by default with Material 3 styling, complemented by an in-app theme toggle (System / Light / Dark) in the AppBar for developers who need high-contrast dark inspection in a light host app — **Reversibility:** reversible — Local theme mode state management within the inspector view.
- **D-51:** Route deduplication guard: Track an internal `_isOpen` state flag on `NetworkInspector` or route observer to silently ignore duplicate open calls or rapid device shakes while the inspector is already visible on the screen — **Reversibility:** reversible — Navigation guard implementation.
- **D-52:** Navigation scope & key resolution: Use root navigator (`Navigator.of(context, rootNavigator: true)`) with optional fallback to `NetworkInspectorConfig.navigatorKey` if provided, ensuring the inspector overlays bottom navigation bars, nested shell routes, and modal sheets cleanly — **Reversibility:** costly — Interacts with host app routing setup.

### Listing Screen Density & Filter UX
- **D-53:** Request tile formatting: Two-line card tile with color-coded badges. Top line: Method badge (colored GET, POST, PUT, DELETE, PATCH) + Status code badge (green 2xx, blue 3xx, orange 4xx, red 5xx) + endpoint path (`/api/v1/users`). Second line: Timestamp (`HH:mm:ss`), duration (`ms`), payload size (`KB`), and trailing status indicator dot — **Reversibility:** reversible — UI widget presentation.
- **D-54:** Search interaction: Persistent SearchBar at top of listing screen with reactive 300ms debounce across URL, method, status code, and payload text, paired with a quick-clear (`x`) button — **Reversibility:** reversible — Reactive search controller and query integration.
- **D-55:** Filter organization: Horizontal quick-filter chips bar directly below search for 1-tap toggling (All, Errors Only, 2xx, 4xx/5xx, POST, GET), plus a "Filters" icon button opening a modal bottom sheet for advanced multi-parameter filtering (custom status code ranges, min/max duration, date range) — **Reversibility:** reversible — Filter UI architecture.
- **D-56:** Pagination strategy: Batch page size of 50 records with threshold-based infinite scrolling (auto-fetching the next 50 records when scrolled to the bottom 20% of list depth), complemented by pull-to-refresh (`RefreshIndicator`) to reload latest records — **Reversibility:** costly — Coordinates with `NetworkInspectorRepository.getRecords(limit: 50, offset: offset)`.

### Details Inspection & JSON Viewer UX
- **D-57:** Tabbed details screen architecture: 4 main top-level tabs (Overview, Request, Response, Error). Overview shows metadata summary; Request tab houses headers, query params, body, and multipart entries; Response tab houses headers and body; Error tab houses exception and stack trace — **Reversibility:** costly — Screen component structure and data binding.
- **D-58:** JSON Body rendering: Pure Flutter Material 3 formatted viewer with 2-space indentation (`JsonEncoder.withIndent('  ')`), lightweight syntax colorizer (keys, strings, numbers, booleans), a "Raw / Pretty" toggle button, and `SelectableText` for easy text selection without third-party dependencies — **Reversibility:** reversible — JSON viewer widget implementation.
- **D-59:** Large payload processing: Offload JSON formatting and pretty-print indentation to a background isolate using Flutter's `compute()` for bodies > 50KB with a brief loading spinner, while payloads <= 50KB are formatted synchronously on the UI isolate to preserve 60fps responsiveness — **Reversibility:** reversible — Performance optimization.
- **D-60:** Granular clipboard copy & developer feedback: Dedicated copy icon buttons on each section (full URL, request headers, response headers, request body, response body) with a lightweight confirmation `SnackBar` ("Copied [section] to clipboard") — **Reversibility:** reversible — User feedback pattern.

### cURL & Share Sheet Export Options
- **D-61:** cURL command formatting: Generate multi-line bash-escaped cURL commands with line continuations (`\`), `-X METHOD`, `-H 'header: value'`, and safely quoted `--data-raw '...'` body ready for direct terminal execution — **Reversibility:** reversible — cURL generator utility.
- **D-62:** Multi-format Share Sheet picker: Tapping "Share" in the detail screen presents a quick action sheet offering "Share as Markdown Summary", "Share as cURL", or "Share as Full JSON" — **Reversibility:** reversible — Export flow.
- **D-63:** Sensitive data handling during export: Default to pre-redacted database records (which already have sensitive keys masked as `[REDACTED]` per `D-09`–`D-12`), with an optional "Exclude all headers" checkbox in the export sheet for maximum privacy when sharing with third parties — **Reversibility:** reversible — Export privacy guard.
- **D-64:** iPadOS / macOS Desktop share sheet anchor protection: Centralized `ShareExporter` utility that safely extracts `sharePositionOrigin` (`RenderBox.localToGlobal(Offset.zero) & box.size`) from the triggering widget's `BuildContext` with automatic fallback to screen center if unattached, preventing fatal `NSGenericException` crashes — **Reversibility:** costly — Platform integration safety rule.

### the agent's Discretion
- Visual color palette for HTTP methods (GET: blue/teal, POST: green, PUT: orange, DELETE: red, PATCH: purple).
- Specific typography, spacing, and elevation values adhering to Material 3 tokens.
- Empty states with informative illustrations/icons for "No network requests yet" and "No matching search results".
- Confirmation dialog styling for the "Clear All" action (`UI-06`, `D-28`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Specifications & Guidelines
- `.planning/PROJECT.md` — Project core value, constraints, and architecture.
- `.planning/REQUIREMENTS.md` § Network Inspector UI (`UI-01` through `UI-11`).
- `.planning/research/STACK.md` § Core Technologies (`intl: ^0.20.3`, `share_plus: ^13.3.1`) & Pitfalls (iPadOS Share anchor views, third-party JSON viewers).
- `.planning/research/ARCHITECTURE.md` § Layer 5: Presentation UI Layer.
- `.planning/research/PITFALLS.md` § Pitfall 7 (iPadOS share sheet anchor crash) & Pitfall 4 (Large payload memory exhaustion).
- `.planning/phases/01-foundation-models/01-CONTEXT.md` — Phase 1 locked decisions (`D-01` through `D-16`): `NetworkRecord`, `PayloadData`, `RedactionEngine`.
- `.planning/phases/02-sqlite-persistence/02-CONTEXT.md` — Phase 2 locked decisions (`D-17` through `D-32`): `NetworkInspectorRepository`, `RecordFilter`, `RecordSort`, `clearAll`.
- `.planning/phases/03-network-capture-interceptors/03-CONTEXT.md` — Phase 3 locked decisions (`D-33` through `D-48`): Interceptor pipelines, deduplication, and manual logging APIs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkInspectorRepository` (`lib/src/repository/network_inspector_repository.dart`): Provides `getRecords(filter, sort, limit, offset)`, `getRecordCount(filter)`, `getById(id)`, and `clearAll()`.
- `RecordFilter` (`lib/src/models/record_filter.dart`): Supports filtering by `methods`, `statusCodes`, `errorOnly`, `searchQuery`, `startDate`, `endDate`, `minDurationMs`, `maxDurationMs`.
- `RecordSort` (`lib/src/models/record_sort.dart`): Supports sorting by `timestampDesc`, `timestampAsc`, `durationDesc`, `durationAsc`, `statusCodeDesc`, `statusCodeAsc`.
- `NetworkRecord` (`lib/src/models/network_record.dart`): Holds full request/response lifecycle data, headers, body strings, multipart entries, and error details.
- `NetworkInspector.repository`: Static accessor exposing the configured active repository instance.

### Established Patterns
- Pure sound null-safe Dart 3 classes with immutable value semantics.
- Material 3 design tokens and theme adaptation.
- Zero-dependency JSON pretty printing via `JsonEncoder.withIndent('  ')`.
- Headless testing via `testWidgets` with `InMemoryNetworkInspectorRepository` or FFI SQLite.

### Integration Points
- Public static method `NetworkInspector.open(BuildContext context)` will push `NetworkInspectorScreen` onto the navigator stack.
- `NetworkInspectorScreen` queries `NetworkInspector.repository` for paginated list viewing, searching, and filtering.
- Tapping a record in the listing pushes `NetworkInspectorDetailScreen(record: record)` for deep tabbed inspection and sharing.

</code_context>

<specifics>
## Specific Ideas

- The listing screen AppBar should feature a clean title ("Network Inspector"), record count badge, theme mode toggle (System/Light/Dark), and an overflow menu containing "Clear All" (with confirmation dialog) and "Export All".
- Color-coded badges for status codes should use standard HTTP semantics: Green for 2xx, Blue for 3xx, Amber/Orange for 4xx, Red for 5xx.
- HTTP method badges should have distinct background tint colors to allow rapid visual scanning.

</specifics>

<deferred>
## Deferred Ideas

- None — all discussed decisions directly support Phase 4 scope.

</deferred>

---

*Phase: 4-Inspector UI*  
*Context gathered: 2026-11-01*
