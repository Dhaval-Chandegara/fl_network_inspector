---
phase: 04-inspector-ui
plan: 04
subsystem: ui
tags: [flutter, material3, curl, share-sheet, export, public-api, barrel]

# Dependency graph
requires:
  - phase: 04-inspector-ui
    provides: 04-02-PLAN.md (search, filter, sort)
  - phase: 04-inspector-ui
    provides: 04-03-PLAN.md (detail screen, json viewer)
provides:
  - CurlGenerator generating multi-line bash-safe cURL commands with single-quote escaping ('\'') and line continuations
  - ShareExporter with safe iPadOS/macOS RenderBox anchor origin calculation to eliminate NSGenericException popover crashes
  - ExportActionSheet with Markdown, cURL, and Full JSON formats and sensitive header exclusion toggle
  - Detail screen AppBar integration for Copy cURL and Share actions
  - Public barrel exports for NetworkInspectorScreen and NetworkInspectorDetailScreen
affects:
  - Phase 05 (shake trigger and developer experience)

actuals:
  tokens: 32000
  tasks: 3
  commits: 1

tech-stack:
  added: []
  patterns:
    - Multi-line terminal-executable bash cURL formatting with single-quote escaping ('\'')
    - iPadOS/macOS popover anchor origin computation with fallback to screen center
    - Multi-format sharing sheet (Markdown, cURL, JSON) with sensitive header exclusion
    - Public UI barrel export pattern in root library file

key-files:
  created:
    - lib/src/ui/utils/curl_generator.dart
    - lib/src/ui/utils/share_exporter.dart
    - lib/src/ui/components/export_action_sheet.dart
    - test/ui/curl_generator_test.dart
    - test/ui/share_exporter_test.dart
  modified:
    - lib/src/ui/network_inspector_detail_screen.dart
    - lib/src/ui/network_inspector_screen.dart
    - lib/flutter_network_inspector.dart
    - test/ui/network_inspector_detail_screen_test.dart
    - test/ui/network_inspector_screen_test.dart

key-decisions:
  - "D-61: CurlGenerator constructs bash-safe multi-line cURL CLI commands escaping single quotes as '\'' and filtering internal tracking and pseudo-headers"
  - "D-62: ExportActionSheet modal bottom sheet presents three formats: Markdown Summary, cURL Command, and Full JSON"
  - "D-63: Checkbox toggle in export sheet enables stripping sensitive request and response headers when sharing diagnostics externally"
  - "D-64: ShareExporter safely computes RenderBox anchor origin with screen-center fallback, preventing fatal NSGenericException crashes on iPadOS/macOS"

patterns-established:
  - "ShareDelegate hook: ShareExporter.mockShareDelegate enables clean unit and widget testing of native share sheets without platform channels"
  - "Bash escaping: Shell single quotes escaped via input.replaceAll(\"'\", r\"'\\''\")"

requirements-completed:
  - UI-10
  - UI-11

verification:
  - "flutter test test/ui/curl_generator_test.dart test/ui/share_exporter_test.dart test/ui/network_inspector_detail_screen_test.dart passes"
  - "All 192 unit and widget tests pass across entire package"
---

# Plan 04-04 Summary: cURL Generation & Native Share Sheet Export

Implemented terminal-executable cURL CLI command generation and multi-format native OS share sheet export with iPadOS popover anchor crash protection and sensitive header redaction.

## What Was Done

1. **cURL CLI Command Generator (`lib/src/ui/utils/curl_generator.dart`):**
   - Implemented `CurlGenerator.fromRecord` generating multi-line bash-safe commands using `curl -X METHOD \\\n  'URL'`.
   - Escapes single quotes in URLs, headers, and request body payloads using the bash standard `'\''`.
   - Filters out internal HTTP/2 pseudo-headers (e.g. `:method`, `:path`, `:authority`) and inspector tracking headers (`x-fl-net-inspector-tracked-id`, `x-network-inspector-id`).
   - Supports `includeHeaders: false` to allow generating clean cURL commands with headers stripped.

2. **Native Share Exporter & Multi-Format Sheet (`lib/src/ui/utils/share_exporter.dart`, `lib/src/ui/components/export_action_sheet.dart`):**
   - Built `ShareExporter` providing multi-format serialization:
     - `formatMarkdown`: Formatted report with metadata, request headers, bodies, response headers, and error details.
     - `formatCurl`: Bash cURL command.
     - `formatJson`: Pretty-printed 2-space indented JSON from `record.toMap()`.
   - Implemented `calculateAnchor` computing `RenderBox` geometry (`renderBox.localToGlobal(Offset.zero) & renderBox.size`) with graceful fallback to `MediaQuery.sizeOf(context).center(Offset.zero) & const Size(1, 1)` to eliminate iPadOS `NSGenericException` crashes.
   - Built `ExportActionSheet` with options for Markdown, cURL, and JSON, plus an "Exclude all headers" checkbox tile.
   - Added `mockShareDelegate` to allow code-generation-free test verification.

3. **Detail Screen & Public Barrel Integration:**
   - Added "Copy cURL" (`Icons.terminal_rounded`) and "Share" (`Icons.share_rounded`) icon buttons to `NetworkInspectorDetailScreen` AppBar.
   - Wired Copy cURL to copy to system clipboard and show floating confirmation SnackBar ("Copied cURL to clipboard").
   - Wired Share to open `ExportActionSheet`.
   - Exported `NetworkInspectorScreen` and `NetworkInspectorDetailScreen` in `lib/flutter_network_inspector.dart`.
   - Added widget tests verifying navigation from listing to detail screen and verifying AppBar export actions.
