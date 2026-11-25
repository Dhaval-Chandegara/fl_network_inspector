# Phase 11: Dependency Bounds Widening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-21
**Phase:** 11-dependency-bounds-widening
**Areas discussed:** Plus plugins floor (share_plus & sensors_plus), Database & utility bounds (intl, sqflite, uuid), Client adapter ranges (dio & http), SDK environment baseline

---

## Plus plugins floor (share_plus & sensors_plus)

| Option | Description | Selected |
|--------|-------------|----------|
| >=10.0.0 <14.0.0 | SharePlus.instance & ShareParams exist across this entire range, avoiding compile-time signature conflicts while supporting Flutter 3.22 through 3.50+ | ✓ |
| >=9.0.0 <14.0.0 | Maximum backward reach (per BOUND-01), but requires Phase 12 shim to bridge Share.share vs SharePlus.instance.share | |
| You decide | Let the planner and researcher determine based on pub resolution analysis | |

**User's choice:** `(Recommended) >=10.0.0 <14.0.0 — SharePlus.instance & ShareParams exist across this entire range, avoiding compile-time signature conflicts while supporting Flutter 3.22 through 3.50+`

| Option | Description | Selected |
|--------|-------------|----------|
| >=6.0.0 <8.0.0 | Directly supports userAccelerometerEventStream() without deprecated getter warnings or sampling period mismatches | ✓ |
| >=5.0.0 <8.0.0 | Extends reach to Flutter 3.19/3.22 while keeping userAccelerometerEventStream() available | |
| >=4.0.0 <8.0.0 | Maximum backward reach (per BOUND-02), but requires Phase 12 fallback to userAccelerometerEvents on 4.x | |
| You decide | Let research verify the exact version where userAccelerometerEventStream() stabilized | |

**User's choice:** `(Recommended) >=6.0.0 <8.0.0 — Directly supports userAccelerometerEventStream() without deprecated getter warnings or sampling period mismatches`

| Option | Description | Selected |
|--------|-------------|----------|
| Strict semver upper bounds (<14.0.0 for share_plus, <8.0.0 for sensors_plus) | Adheres to pub.dev scoring and prevents unverified future breaking changes | ✓ |
| Permissive upper bounds | Allow next major pre-releases if pub permits | |
| You decide | Follow standard pub.dev package publishing recommendations | |

**User's choice:** `(Recommended) Strict semver upper bounds (<14.0.0 for share_plus, <8.0.0 for sensors_plus) — Adheres to pub.dev scoring and prevents unverified future breaking changes`

| Option | Description | Selected |
|--------|-------------|----------|
| Enforce screen-center or button-boundary fallback Rect | If context RenderBox is missing/unmounted, prevents iPadOS NSGenericException crashes across all share_plus versions | ✓ |
| Keep existing calculateAnchor(context) logic | Rely on context RenderBox retrieval from the caller modal | |
| You decide | Implement whatever is most resilient against iPad/tablet share sheet crashes | |

**User's choice:** `(Recommended) Enforce screen-center or button-boundary fallback Rect if context RenderBox is missing/unmounted — Prevents iPadOS NSGenericException crashes across all share_plus versions`

---

## Database & utility bounds (intl, sqflite, uuid)

| Option | Description | Selected |
|--------|-------------|----------|
| >=0.18.0 <0.21.0 | Broadest compatibility, resolves conflicts with flutter_localizations from Flutter 3.10 up to 3.50+ (per BOUND-03) | ✓ |
| >=0.19.0 <0.21.0 | Targets Flutter 3.22+ flutter_localizations baseline without supporting older 0.18.x | |
| You decide | Confirm with pub dependency solver analysis during research | |

**User's choice:** `(Recommended) >=0.18.0 <0.21.0 — Broadest compatibility, resolves conflicts with flutter_localizations from Flutter 3.10 up to 3.50+ (per BOUND-03)`

| Option | Description | Selected |
|--------|-------------|----------|
| >=2.2.0 <3.0.0 for both sqflite & sqflite_common_ffi | Rock-solid SQLite APIs across all 2.x releases without version conflict with consumer apps (per BOUND-04) | ✓ |
| >=2.3.0 <3.0.0 | Slightly narrower, aligns with newer platform channel enhancements | |
| You decide | Ensure maximum compatibility with Flutter desktop and mobile SQLite engines | |

**User's choice:** `(Recommended) >=2.2.0 <3.0.0 for both sqflite & sqflite_common_ffi — Rock-solid SQLite APIs across all 2.x releases without version conflict with consumer apps (per BOUND-04)`

| Option | Description | Selected |
|--------|-------------|----------|
| ^4.0.0 (>=4.0.0 <5.0.0) | Modern standard across Dart 3 / Flutter 3.x apps; preserves const Uuid() without requiring v3 constructor shims | ✓ |
| >=3.0.0 <5.0.0 | Widest possible compatibility across legacy apps; requires removing const from Uuid() instantiation if non-const on v3 | |
| You decide | Choose based on whether host apps commonly lock uuid to v3 | |

**User's choice:** `(Recommended) ^4.0.0 (>=4.0.0 <5.0.0) — Modern standard across Dart 3 / Flutter 3.x apps; preserves const Uuid() without requiring v3 constructor shims`

| Option | Description | Selected |
|--------|-------------|----------|
| Relax path to >=1.8.0 <2.0.0 | Eliminates transitive pub conflicts in older Flutter SDKs (like Flutter 3.10-3.16 which bundle path 1.8.x) | ✓ |
| Keep path at ^1.9.0 (>=1.9.0 <2.0.0) | | |
| You decide | Widen path if analyzer and tests verify no 1.9.1-only methods are used | |

**User's choice:** `(Recommended) Relax path to >=1.8.0 <2.0.0 — Eliminates transitive pub conflicts in older Flutter SDKs (like Flutter 3.10-3.16 which bundle path 1.8.x)`

---

## Client adapter ranges (dio & http)

| Option | Description | Selected |
|--------|-------------|----------|
| >=5.0.0 <6.0.0 | Covers all Dio 5.x releases since the initial DioException / InterceptorHandler architecture without version solving locks (per BOUND-05) | ✓ |
| Keep >=5.2.0 <6.0.0 | Keeps constraint pinned to Dio 5.2+ baseline | |
| You decide | Widen to >=5.0.0 if all tests and interceptors pass on 5.0.0 | |

**User's choice:** `(Recommended) >=5.0.0 <6.0.0 — Covers all Dio 5.x releases since the initial DioException / InterceptorHandler architecture without version solving locks (per BOUND-05)`

| Option | Description | Selected |
|--------|-------------|----------|
| >=1.0.0 <2.0.0 | Stable 1.x baseline for Dart 3, avoids pre-1.0 breaking changes in BaseClient/StreamedResponse (per BOUND-05) | ✓ |
| >=0.13.0 <2.0.0 | Support legacy pre-1.0 http packages (requires shimming any changed BaseClient signatures) | |
| You decide | Recommend >=1.0.0 based on Dart 3 ecosystem standards | |

**User's choice:** `(Recommended) >=1.0.0 <2.0.0 — Stable 1.x baseline for Dart 3, avoids pre-1.0 breaking changes in BaseClient/StreamedResponse (per BOUND-05)`

| Option | Description | Selected |
|--------|-------------|----------|
| Keep both dio and http in dependencies with permissive ranges | Zero setup friction for consumers, keeps NetworkInspectorDioInterceptor and NetworkInspectorHttpClient out of the box | ✓ |
| Move client adapters to separate companion packages | e.g. fl_network_inspector_dio in future milestones | |
| You decide | Retain current unified package structure for v1.2 | |

**User's choice:** `(Recommended) Keep both dio and http in dependencies with permissive ranges — Zero setup friction for consumers, keeps NetworkInspectorDioInterceptor and NetworkInspectorHttpClient out of the box`

| Option | Description | Selected |
|--------|-------------|----------|
| Include pub downgrade / minimum-bounds resolution check in Phase 11 validation | Verifies that flutter pub get works cleanly at both lowest (e.g. dio 5.0.0) and latest resolved bounds | ✓ |
| Standard flutter pub get only | Leave lowest-bounds test matrix verification exclusively to Phase 12 & 13 | |
| You decide | Validate whatever ensures pub solver safety | |

**User's choice:** `(Recommended) Include pub downgrade / minimum-bounds resolution check in Phase 11 validation — Verifies that flutter pub get works cleanly at both lowest (e.g. dio 5.0.0) and latest resolved bounds`

---

## SDK environment baseline

| Option | Description | Selected |
|--------|-------------|----------|
| Keep sdk: ">=3.0.0 <4.0.0" and flutter: ">=3.10.0" | Unless pub solver analysis proves a higher minimum is mandated by dependencies | ✓ |
| Align flutter minimum to ">=3.19.0" or ">=3.22.0" | Explicitly reflect the share_plus 10+ / sensors_plus 6+ ecosystem baseline | |
| You decide | Let research verify the exact minimum Flutter SDK compatible with all lowest-bound dependencies | |

**User's choice:** `(Recommended) Keep sdk: ">=3.0.0 <4.0.0" and flutter: ">=3.10.0" unless pub solver analysis proves a higher minimum is mandated by dependencies`

| Option | Description | Selected |
|--------|-------------|----------|
| Keep dev_dependencies as-is | flutter_lints ^3.0.0, test ^1.25.0, http_parser ^4.0.2; dev dependencies do not affect consumers and ensure reproducible CI linting | ✓ |
| Widen flutter_lints to ">=3.0.0 <6.0.0" | Development flexibility across developer environments | |
| You decide | Maintain strict CI linting consistency | |

**User's choice:** `(Recommended) Keep dev_dependencies (flutter_lints ^3.0.0, test ^1.25.0, http_parser ^4.0.2) as-is — Dev dependencies do not affect consumers; maintaining them ensures reproducible CI linting`

| Option | Description | Selected |
|--------|-------------|----------|
| Bump to 1.1.0 or 1.2.0 at Phase 14 (release prep) | Keep version 1.0.1 (or 1.1.0-dev) during development phases 11-13 to prevent premature tag/release confusion | ✓ |
| Bump version in pubspec.yaml to 1.2.0-dev.1 in Phase 11 immediately | Reflect work in progress on milestone v1.2 | |
| You decide | Follow the milestone release workflow established in v1.1 | |

**User's choice:** `(Recommended) Bump to 1.1.0 or 1.2.0 at Phase 14 (release prep) — Keep version 1.0.1 (or 1.1.0-dev) during development phases 11-13 to prevent premature tag/release confusion`

| Option | Description | Selected |
|--------|-------------|----------|
| Enforce 0 warnings on flutter analyze & flutter pub publish --dry-run in Phase 11 | Ensures pub.dev 140/140 scoring and valid package formatting are maintained at every step | ✓ |
| Run flutter analyze only | Postpone publish dry-run check until Phase 13/14 | |
| You decide | Adhere to the zero-warning quality standards from Milestone v1.1 | |

**User's choice:** `(Recommended) Enforce 0 warnings on flutter analyze & flutter pub publish --dry-run in Phase 11 — Ensures pub.dev 140/140 scoring and valid package formatting are maintained at every step`

---

## the agent's Discretion

- Researcher and planner may verify if minimum bounds resolution requires specific mock overrides in headless test harnesses (`sqflite_common_ffi` test runners).

## Deferred Ideas

None — discussion stayed strictly within the phase scope.
