# Phase 11: Dependency Bounds Widening - Context

**Gathered:** 2026-11-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit and widen version constraints across core dependencies (`share_plus`, `sensors_plus`, `intl`, `sqflite`, `sqflite_common_ffi`, `path`, `uuid`) and client adapters (`dio`, `http`) in `pubspec.yaml` to eliminate pubgrub solver conflicts across Flutter 3.35 through 3.50+ while keeping the Dart 3 / Flutter 3.10+ baseline intact and passing publication dry-run with 0 warnings.
</domain>

<decisions>
## Implementation Decisions

### Plus Plugins Floor (`share_plus` & `sensors_plus`)
- **D-01:** Target `share_plus: ">=10.0.0 <14.0.0"` in `pubspec.yaml`. `SharePlus.instance` and `ShareParams` are natively available across this entire range, avoiding compile-time signature conflicts while supporting Flutter 3.22 through 3.50+. — **Reversibility:** costly — Published dependency ranges cannot be narrowed on pub.dev without breaking downstream apps.
- **D-02:** Target `sensors_plus: ">=6.0.0 <8.0.0"` in `pubspec.yaml`. Directly supports `userAccelerometerEventStream()` across the full range without deprecated getter warnings or sampling period mismatches. — **Reversibility:** costly — Published dependency ranges dictate consumer pub solver compatibility.
- **D-03:** Enforce strict semver upper bounds (`<14.0.0` for `share_plus`, `<8.0.0` for `sensors_plus`) to adhere to pub.dev scoring and prevent breaking changes from unreleased future major versions.
- **D-04:** Enforce screen-center or button-boundary fallback `Rect` for iPadOS / tablet `sharePositionOrigin` if context `RenderBox` is missing or unmounted, preventing iPadOS `NSGenericException` crashes across all `share_plus` versions.

### Database & Utility Bounds (`intl`, `sqflite`, `uuid`, `path`)
- **D-05:** Set `intl: ">=0.18.0 <0.21.0"`. Broadest compatibility, resolving transitive version conflicts with `flutter_localizations` from Flutter 3.10 up to 3.50+ (satisfies BOUND-03).
- **D-06:** Set `sqflite: ">=2.2.0 <3.0.0"` and `sqflite_common_ffi: ">=2.2.0 <3.0.0"`. Rock-solid SQLite APIs across all 2.x releases without version conflict with consumer apps on mobile and desktop (satisfies BOUND-04).
- **D-07:** Set `uuid: "^4.0.0"` (`>=4.0.0 <5.0.0`). Modern standard across Dart 3 / Flutter 3.x apps; preserves `const Uuid()` without requiring v3 constructor shims.
- **D-08:** Relax `path: ">=1.8.0 <2.0.0"`. Eliminates transitive pub conflicts in older Flutter SDKs (like Flutter 3.10-3.16 which bundle path 1.8.x).

### Client Adapter Ranges (`dio` & `http`)
- **D-09:** Widen `dio: ">=5.0.0 <6.0.0"`. Covers all Dio 5.x releases since the initial `DioException` / `RequestInterceptorHandler` architecture without version solving locks (satisfies BOUND-05).
- **D-10:** Maintain `http: ">=1.0.0 <2.0.0"`. Stable 1.x baseline for Dart 3, avoiding pre-1.0 breaking changes in `BaseClient` / `StreamedResponse`.
- **D-11:** Keep both `dio` and `http` in `dependencies` with permissive ranges to provide zero setup friction for consumers out of the box.
- **D-12:** Include pub downgrade / minimum-bounds resolution check in Phase 11 validation to verify that `flutter pub get` works cleanly at both lowest and latest resolved bounds.

### SDK Environment Baseline & Quality Gates
- **D-13:** Keep `environment: sdk: ">=3.0.0 <4.0.0"` and `flutter: ">=3.10.0"` unless pub solver analysis during research proves a higher minimum Flutter SDK is mandated by the lowest allowed versions.
- **D-14:** Keep `dev_dependencies` (`flutter_lints: ^3.0.0`, `test: ^1.25.0`, `http_parser: ^4.0.2`) as-is to preserve reproducible CI linting.
- **D-15:** Bump package version in `pubspec.yaml` to `1.2.0` at Phase 14 (release prep); keep version `1.0.1` during development phases 11-13 to prevent premature release confusion.
- **D-16:** Enforce 0 warnings on `flutter analyze` and `flutter pub publish --dry-run` in Phase 11 to maintain pub.dev 140/140 scoring readiness.

### the agent's Discretion
- Researcher and planner may verify if minimum bounds resolution requires specific mock overrides in headless test harnesses (`sqflite_common_ffi` test runners).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Manifest & Roadmap
- [pubspec.yaml](file:///Users/dhavalchandegara/projects/fl_network_inspector/pubspec.yaml) — Current dependency bounds and SDK environment declarations.
- [.planning/ROADMAP.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/ROADMAP.md#L44-L53) §Phase 11 — Goals, dependencies, and success criteria for Dependency Bounds Widening.
- [.planning/REQUIREMENTS.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/REQUIREMENTS.md#L10-L17) §BOUND-01..05 — Functional requirements for dependency bound relaxation.

### Critical Call Sites & Adapters
- [lib/src/ui/utils/share_exporter.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/ui/utils/share_exporter.dart#L190-L208) — Usage of `SharePlus.instance.share` and `ShareParams`.
- [lib/src/shake/shake_detector.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/shake/shake_detector.dart#L75-L95) — Usage of `userAccelerometerEventStream()`.
- [lib/src/utils/uuid_generator.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/utils/uuid_generator.dart#L1-L12) — Usage of `const Uuid()` and `Uuid().v4()`.
- [lib/src/interceptor/dio/network_inspector_dio_interceptor.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/dio/network_inspector_dio_interceptor.dart#L1-L30) — Dio 5.x interceptor integration.
- [lib/src/interceptor/http/network_inspector_http_client.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/http/network_inspector_http_client.dart#L1-L30) — `package:http` `BaseClient` wrapping.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ShareExporter`: Centralized sharing utility with `mockShareDelegate` and `calculateAnchor(context)` to insulate UI callers from direct plugin coupling.
- `ShakeDetector`: Lifecycle-aware shake detection stream wrapper with custom/mock stream injection.
- `UuidGenerator`: Centralized UUID wrapper class isolating `package:uuid` from all interceptors and models.

### Established Patterns
- All plugin and third-party dependency calls are encapsulated within dedicated utility classes or interceptor adapters, keeping models and core business logic clean.
- Unit and widget tests use in-memory SQLite FFI (`sqflite_common_ffi`) without requiring physical device or platform channel bindings.

### Integration Points
- `pubspec.yaml`: The single source of truth for package dependencies, version constraints, and environment requirements.
- Automated tests (`flutter test`): Test suites verifying all 210+ test cases pass under updated resolution.

</code_context>

<specifics>
## Specific Ideas

- Ensure `share_plus` is widened to `>=10.0.0 <14.0.0` and `sensors_plus` to `>=6.0.0 <8.0.0`.
- Relax `intl` to `>=0.18.0 <0.21.0` and `path` to `>=1.8.0 <2.0.0` for maximum compatibility with older Flutter SDK localizations and paths.
- Widen `dio` to `>=5.0.0 <6.0.0` while maintaining `http` at `>=1.0.0 <2.0.0` and `uuid` at `^4.0.0`.
- Verify both default `flutter pub get` and minimum-bounds resolution before completing Phase 11.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed strictly within the phase scope.
</deferred>

---

*Phase: 11-Dependency Bounds Widening*
*Context gathered: 2026-11-21*
