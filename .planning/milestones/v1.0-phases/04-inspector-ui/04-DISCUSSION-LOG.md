# Phase 4: Inspector UI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-01  
**Phase:** 4-Inspector UI  
**Areas discussed:** Navigation & Theme Integration, Listing Screen Density & Filter UX, Details Inspection & JSON Viewer, cURL & Share Sheet Export Options  

---

## Navigation & Theme Integration

### Question 1: Presentation & Routing Style
| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen Material route (Navigator.push) | Maximum screen real estate for browsing records and inspecting large JSON/headers; standard AppBar back navigation | ✓ |
| Modal bottom sheet (showModalBottomSheet with isScrollControlled: true) | Slides up over the current view with swipe-down dismissal, ideal for quick peeks | |
| You decide | Follow idiomatic Material 3 debugging tool standards | |

**User's choice:** Full-screen Material route (Navigator.push)  
**Notes:** D-49: Pushes full-screen route for maximum inspection real estate.

### Question 2: Theme & Dark/Light Mode Handling
| Option | Description | Selected |
|--------|-------------|----------|
| Inherit host app theme with in-app toggle (System / Light / Dark) | Adapts to host app by default, but allows forcing dark/light mode via an AppBar toggle | ✓ |
| Strict host theme inheritance | Purely rely on host app's Theme.of(context) with zero inspector-specific toggles | |
| Dedicated dark-first developer theme | Always render inspector in a sleek dark theme (like Chrome DevTools / Charles Proxy) regardless of host app | |
| You decide | Choose the cleanest approach for host app isolation | |

**User's choice:** Inherit host app theme with in-app toggle (System / Light / Dark)  
**Notes:** D-50: Adapts to host app theme with AppBar toggle for manual override.

### Question 3: Route Stacking & Duplicate Prevention
| Option | Description | Selected |
|--------|-------------|----------|
| Route deduplication guard | Track an active route flag so repeated shakes or duplicate open() calls are ignored if the inspector is already visible | ✓ |
| Replace/Reset active inspector | Pop and push a fresh inspector route if an open call arrives while already open | |
| Unrestricted stacking | Allow standard Navigator.push with no internal tracking | |
| You decide | Implement the most reliable guard against double-push crashes | |

**User's choice:** Route deduplication guard  
**Notes:** D-51: Guard against duplicate pushes and shake triggers.

### Question 4: Navigation Scope & Custom Navigator Key
| Option | Description | Selected |
|--------|-------------|----------|
| Root navigator (rootNavigator: true) with optional navigatorKey | Ensures inspector overlays bottom nav bars / tabs, with fallback to global navigatorKey if provided | ✓ |
| Standard local Navigator (rootNavigator: false) | Pushes directly into the current nearest navigator context | |
| You decide | Pick the option with the widest compatibility across GoRouter / AutoRoute / standard Navigator | |

**User's choice:** Root navigator (rootNavigator: true) with optional navigatorKey  
**Notes:** D-52: Clean overlay on shell routes and bottom navigation bars.

---

## Listing Screen Density & Filter UX

### Question 1: Tile Formatting
| Option | Description | Selected |
|--------|-------------|----------|
| Two-line card tile with color-coded badges | Top line: Method badge (GET/POST/etc.) + Status code badge (200/404/500) + path; Second line: Timestamp (HH:mm:ss), duration (ms), payload size (KB), and status indicator dot | ✓ |
| Compact single-line dense row | Minimalist single-line row displaying method, status code, truncated path, and duration for maximum vertical density | |
| Three-line rich card with full URL and error snippet | Shows host domain, full path, status/duration/size, and a dedicated error banner preview if failed | |
| You decide | Use standard Chucker/DevTools mobile card styling | |

**User's choice:** Two-line card tile with color-coded badges  
**Notes:** D-53: Balances visual scanning speed with rich metadata.

### Question 2: Real-time Search Interaction
| Option | Description | Selected |
|--------|-------------|----------|
| Persistent SearchBar with 300ms debounce | Live search field at top of list that automatically queries database across URL, method, status, and payload text after 300ms typing pause, with quick clear (x) button | ✓ |
| Collapsible SearchBar action | Magnifying glass icon in AppBar that expands into search field when tapped, auto-filtering on text changes | |
| Modal SearchDelegate | Standard Flutter showSearch() view that overlays the list when search is initiated | |
| You decide | Material 3 SearchBar pattern | |

**User's choice:** Persistent SearchBar with 300ms debounce  
**Notes:** D-54: Reactive search field with instant clear button.

### Question 3: Filter Organization
| Option | Description | Selected |
|--------|-------------|----------|
| Horizontal quick-filter chips bar + bottom sheet for advanced filters | Horizontal scrollable chips for fast 1-tap toggling (All, Errors Only, 2xx, 4xx/5xx, POST, GET) plus a Tune/Filter button for advanced duration/date filters | ✓ |
| Filter button opening modal sheet only | Keeps header compact with a single Filter icon in the AppBar opening a comprehensive modal bottom sheet | |
| Persistent collapsible filter panel | Accordion panel below search that expands into filter controls when tapped | |
| You decide | Choose the most convenient layout for quick daily debugging | |

**User's choice:** Horizontal quick-filter chips bar + bottom sheet for advanced filters  
**Notes:** D-55: Rapid 1-tap quick filters with full-featured advanced modal sheet.

### Question 4: Pagination Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| 50 records/page with threshold infinite scroll + Pull-to-refresh | Loads 50 items initially, requests next 50 when user scrolls to bottom 20% of list, and supports RefreshIndicator to reload fresh records | ✓ |
| 25 records/page with explicit 'Load More' button | Smaller batches with an explicit button at the footer to prevent unexpected jumpy scroll behavior | |
| 100 records/page with animated auto-prepend | Larger page size that keeps a long list in memory, automatically prepending new incoming requests at the top | |
| You decide | Optimize for smooth 60fps scrolling and minimal RAM usage | |

**User's choice:** 50 records/page with threshold infinite scroll + Pull-to-refresh  
**Notes:** D-56: 50 records per page batch with 80% scroll depth auto-fetch and pull-to-refresh.

---

## Details Inspection & JSON Viewer

### Question 1: Tabs & Sections Organization
| Option | Description | Selected |
|--------|-------------|----------|
| 4 Main Tabs (Overview, Request, Response, Error) with inner sections | Clean top TabBar; Request tab contains Headers, Query Params, Body & Multipart; Response tab contains Headers & Body | ✓ |
| Flat scrollable TabBar with all 7-8 tabs | Horizontal scrolling top bar (Overview, Req Headers, Req Body, Query Params, Resp Headers, Resp Body, Multipart, Error) | |
| Single-page accordion view | All sections on one long scrollable page with expandable/collapsible Material ExpansionTile cards | |
| You decide | Standard mobile API inspector tab architecture | |

**User's choice:** 4 Main Tabs (Overview, Request, Response, Error) with inner sections  
**Notes:** D-57: Clean, non-overwhelming 4-tab top navigation.

### Question 2: JSON Body Rendering
| Option | Description | Selected |
|--------|-------------|----------|
| Formatted syntax-colored JSON with Raw/Pretty toggle & SelectableText | Indented 2-space JSON with syntax coloring for keys/values, copy button, and toggle to view raw string | ✓ |
| Collapsible tree node view + Raw toggle | Interactive tree widget where each JSON object/array can be individually collapsed or expanded | |
| Pure plain text monospace viewer with search & copy | Lightweight monospace selectable text without syntax coloring for maximum performance | |
| You decide | Zero external dependencies, pure Flutter Material 3 widget | |

**User's choice:** Formatted syntax-colored JSON with Raw/Pretty toggle & SelectableText  
**Notes:** D-58: Pure Flutter implementation with zero external syntax highlighter dependencies.

### Question 3: Large Payload Isolate Processing
| Option | Description | Selected |
|--------|-------------|----------|
| Background isolate formatting (compute) for bodies > 50KB | Offloads JSON decode and pretty-print indentation to a background isolate with a spinner, keeping UI 60fps responsive | ✓ |
| Synchronous formatting with size guard (> 200KB prompts 'Format payload?') | Instant formatting for normal payloads; very large payloads require a tap to format | |
| Always background isolate | Run all JSON formatting in compute() regardless of size for uniform behavior | |
| You decide | Balance UI responsiveness with instantaneous rendering for small responses | |

**User's choice:** Background isolate formatting (compute) for bodies > 50KB  
**Notes:** D-59: Zero UI thread stutter for large JSON payloads.

### Question 4: Granular Clipboard Copy Actions
| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated copy icon buttons on each section + SnackBar confirmation | Small copy icon next to URL, Headers, and Body with a brief 'Copied to clipboard' SnackBar | ✓ |
| Long-press to copy on any field or tile with haptic feedback | Minimalist UI without visible copy buttons, using gestures and haptics | |
| Bottom action bar with 'Copy Menu' | Unified button at bottom of details screen opening a sheet to copy URL, cURL, Headers, or Body | |
| You decide | Standard developer tooling clipboard interaction | |

**User's choice:** Dedicated copy icon buttons on each section + SnackBar confirmation  
**Notes:** D-60: Fast, discoverable 1-tap section copying.

---

## cURL & Share Sheet Export Options

### Question 1: cURL Command Structure & Escaping
| Option | Description | Selected |
|--------|-------------|----------|
| Multi-line bash-escaped cURL with line continuations (\) | Clean, readable format with -X METHOD, -H headers, and quoted --data-raw body ready for terminal paste | ✓ |
| Single-line minified cURL command | Compact single-line command with spaces for quick terminal or Postman import | |
| Interactive cURL modal with format toggles | Allows choosing between multi-line bash, single-line, or PowerShell syntax | |
| You decide | Idiomatic POSIX-compliant cURL generator | |

**User's choice:** Multi-line bash-escaped cURL with line continuations (\)  
**Notes:** D-61: Terminal-friendly POSIX bash cURL format.

### Question 2: Share Sheet Export Format Picker
| Option | Description | Selected |
|--------|-------------|----------|
| Multi-format Share Sheet picker (Summary Report, cURL, or Full JSON) | Tapping Share opens a quick action sheet letting the user choose between a Markdown summary, cURL, or raw JSON | ✓ |
| Markdown / Plain text report only | Formatted summary with overview, headers, body, cURL, and error details designed for pasting directly into Slack or GitHub issues | |
| Raw JSON export only | Standard serialized NetworkRecord payload suitable for programmatic tooling import | |
| You decide | Developer-first sharing experience | |

**User's choice:** Multi-format Share Sheet picker (Summary Report, cURL, or Full JSON)  
**Notes:** D-62: Flexible sharing targets for Slack/GitHub vs. terminal vs. tools.

### Question 3: Sensitive Data Redaction on Export
| Option | Description | Selected |
|--------|-------------|----------|
| Default to stored redactions with 'Exclude all headers' toggle in export sheet | Uses pre-redacted database records by default, plus an optional checkbox to strip all headers for external sharing | ✓ |
| Pure pre-redacted export | Always share the stored record directly (which already has sensitive keys masked as [REDACTED] via D-09/D-12) with no extra prompts | |
| Interactive redaction preview | Shows a quick preview with custom redaction checklist before launching the native share sheet | |
| You decide | Ensure zero risk of leaking secrets during export | |

**User's choice:** Default to stored redactions with 'Exclude all headers' toggle in export sheet  
**Notes:** D-63: Maximum security and confidentiality during export.

### Question 4: iPadOS & macOS Desktop Share Anchor Protection
| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated ShareExporter utility with automatic RenderBox origin & center fallback | Centralized helper extracting sharePositionOrigin from triggering widget's context with safe screen center fallback | ✓ |
| Per-widget local RenderBox calculation | Compute localToGlobal directly within the detail screen AppBar action callback | |
| You decide | Guarantee crash-proof share sheet presentation across iOS, iPadOS, and macOS desktop | |

**User's choice:** Dedicated ShareExporter utility with automatic RenderBox origin & center fallback  
**Notes:** D-64: Guarantees zero `NSGenericException` crashes on iPadOS / macOS.

---

## the agent's Discretion

- Visual styling and color coding for HTTP method badges (GET, POST, PUT, DELETE, PATCH).
- Material 3 design token adherence (typography, spacing, borders, elevation).
- Empty state widgets and illustrations for empty records and search no-results.
- Confirmation dialog styling for "Clear All" action.

## Deferred Ideas

- None — all discussed topics directly support Phase 4 scope.
