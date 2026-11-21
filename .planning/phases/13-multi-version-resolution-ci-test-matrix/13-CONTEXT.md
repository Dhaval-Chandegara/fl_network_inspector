# Phase 13: Multi-Version Resolution & CI Test Matrix - Context

**Gathered:** 2026-11-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate pub dependency resolution across simulated consumer environments and configure an automated multi-version CI test matrix. This phase delivers automated consumer pub resolution tests simulating consumer environments across target Flutter releases (Flutter 3.35, 3.40, 3.45, 3.50+), a complete GitHub Actions CI matrix (`.github/workflows/ci.yml`), automated CI execution of the lowest-bounds test pipeline (`tool/verify_lowest_bounds.sh`), and packaging verification achieving a 140/140 pana analysis score, satisfying requirements MATRIX-01, MATRIX-02, and MATRIX-03.

</domain>

<decisions>
## Implementation Decisions

### CI Test Matrix Dimensions & Multi-OS Runners
- **D-01:** Configure the GitHub Actions test matrix across Flutter channels `stable`, `beta`, and the pinned minimum supported SDK baseline (`3.10.0` / `3.22.0`). This provides comprehensive coverage of current stable, future beta, and minimum guaranteed baseline without CI runner bloat. — **Reversibility:** costly — Matrix configuration shapes CI execution time, compute usage, and branch status checks.
- **D-02:** Execute the primary Flutter matrix on `ubuntu-latest`, and add a dedicated multi-OS smoke test job running on `macos-latest` and `windows-latest` specifically verifying the SQLite FFI platform bindings and test suite headlessly across desktop environments.
- **D-03:** Run `tool/verify_lowest_bounds.sh` as a dedicated standalone CI job on `ubuntu-latest` (Flutter stable) to cleanly isolate dependency downgrade testing from standard test matrix runs.
- **D-04:** Set `continue-on-error: true` for the `beta` channel matrix job to surface upcoming Flutter framework breaks early in CI logs without blocking active PR merges on unreleased framework regressions.

### Consumer Pub Resolution Simulation Strategy
- **D-05:** Implement `tool/verify_consumer_resolution.sh` to generate ephemeral consumer Flutter projects inside a temporary directory (`mktemp -d`), linking `flutter_network_inspector` via path dependency (`path: ../`). This keeps the repository clean of dummy projects and lockfile pollution while providing reproducible local and CI validation. — **Reversibility:** costly — Standardizes consumer resolution verification contract across all test environments.
- **D-06:** Test 4 core representative consumer archetype scenarios in `tool/verify_consumer_resolution.sh`:
  1. **Modern Consumer:** Default contemporary Flutter app resolving latest package bounds.
  2. **Legacy Floor Consumer:** Pinned floors matching `dio: 5.2.0`, `share_plus: 11.0.0`, `intl: 0.18.0`, and `sqflite: 2.2.0`.
  3. **Mid-Tier Consumer:** Realistic mix of Dio 5.x and Http 1.x dependencies.
  4. **Strict Localization Consumer:** Simulating `flutter_localizations` constraint interactions with `intl: 0.18.0`.
- **D-07:** Deepen consumer validation beyond `pub get` by generating a minimal consumer entrypoint (`main.dart`) that imports and references `NetworkInspector`, and running `dart analyze` to guarantee zero compile-time or type compatibility errors.
- **D-08:** Integrate `tool/verify_consumer_resolution.sh` as a mandatory step in the main CI workflow, executing across all PRs and pushes to `main`.

### Pana Analysis & Packaging Gate Automation
- **D-09:** Create a standalone verification script `tool/verify_pana.sh` combining `pana --exit-code-threshold 140` and `flutter pub publish --dry-run`, executable locally by developers and in CI. — **Reversibility:** costly — Directly enforces pub.dev package quality gate.
- **D-10:** Enforce a strict 140/140 score threshold (`--exit-code-threshold 140`), guaranteeing zero deductions on code formatting, documentation, platform support, and dependency health.
- **D-11:** Establish a dedicated fast "Lint & Quality" CI job running `dart format --output=none --set-exit-if-changed`, `flutter analyze --no-fatal-infos`, and `tool/verify_pana.sh` to fail fast on syntax, formatting, or packaging issues before running the heavier multi-OS test matrix.
- **D-12:** Include graceful diagnostics in `tool/verify_pana.sh`: if pub.dev is unreachable or network access is restricted, output actionable diagnostic messages while proceeding with `flutter pub publish --dry-run`.

### CI Workflow Concurrency & Branch Triggers
- **D-13:** Configure `.github/workflows/ci.yml` triggers on `push: branches: [main]`, `pull_request: branches: [main]`, and `workflow_dispatch` (manual trigger).
- **D-14:** Set up concurrency controls with `group: ${{ github.workflow }}-${{ github.ref }}` and `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}` to cancel obsolete in-progress PR runs immediately while ensuring main branch verification always completes.
- **D-15:** Standardize on `subosito/flutter-action@v2` with `cache: true` across all jobs to cache pub packages and accelerate CI runs.
- **D-16:** Provide an `all-checks-passed` aggregate gate job that depends on all quality, matrix, downgrade, and consumer simulation jobs (`needs: [lint-and-quality, test-matrix, multi-os-smoke, lowest-bounds, consumer-resolution]`), exposing a single required status check for GitHub branch protection rules. — **Reversibility:** costly — Branch protection rules bind to this check name.

### the agent's Discretion
- The planner and researcher have discretion regarding the exact bash script syntax and tempdir handling in `tool/verify_consumer_resolution.sh` and `tool/verify_pana.sh`.
- The planner may choose exact step naming and cache keys in `.github/workflows/ci.yml`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Manifest & Roadmap
- [pubspec.yaml](file:///Users/dhavalchandegara/projects/fl_network_inspector/pubspec.yaml) — Widened dependency ranges and Dart/Flutter SDK constraints.
- [.planning/ROADMAP.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/ROADMAP.md#L73-L84) §Phase 13 — Goals, requirements, and success criteria for Multi-Version Resolution & CI Test Matrix.
- [.planning/REQUIREMENTS.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/REQUIREMENTS.md#L25-L30) §MATRIX-01..03 — Functional requirements for multi-version validation, GitHub Actions CI matrix, and pana score.
- [.planning/phases/11-dependency-bounds-widening/11-CONTEXT.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/phases/11-dependency-bounds-widening/11-CONTEXT.md) — Baseline dependency bounds widening decisions.
- [.planning/phases/12-api-backward-compatibility-layer/12-CONTEXT.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/phases/12-api-backward-compatibility-layer/12-CONTEXT.md) — API adaptation layer decisions and lowest bounds verification pattern.

### Existing Verification Scripts
- [tool/verify_lowest_bounds.sh](file:///Users/dhavalchandegara/projects/fl_network_inspector/tool/verify_lowest_bounds.sh) — Reusable script with exit signal traps testing lowest resolved dependency floors.

### Testing & Platform Files
- [lib/src/storage/platform/ffi_init_io.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/storage/platform/ffi_init_io.dart) — SQLite FFI initialization across Windows, macOS, Linux.
- [test/storage/database_harness_test.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/test/storage/database_harness_test.dart) — Database harness verification under FFI.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tool/verify_lowest_bounds.sh`: Shell script template featuring `set -euo pipefail`, trap restoration for `pubspec.lock`, and targeted `dart pub downgrade`. Reusable as a pattern for `tool/verify_consumer_resolution.sh` and `tool/verify_pana.sh`.
- `sqflite_common_ffi`: Configured for headless test runs across desktop platforms.
- `lib/src/ui/utils/share_exporter.dart` & `lib/src/shake/shake_detector.dart`: Hardened against runtime exceptions across multiple dependency versions.

### Established Patterns
- Signal trap lockfile restoration (`trap cleanup EXIT INT TERM`) ensures zero permanent repo pollution when manipulating package dependencies.
- Headless testing using `flutter test --no-pub` under downgraded dependencies.

### Integration Points
- `.github/workflows/ci.yml`: New GitHub Actions workflow file defining multi-version matrix, quality gates, and status checks.
- `tool/verify_consumer_resolution.sh`: New automated consumer simulation script testing path dependency resolution across 4 archetypes.
- `tool/verify_pana.sh`: New packaging verification script validating pana 140/140 score and `flutter pub publish --dry-run`.

</code_context>

<specifics>
## Specific Ideas

- Ephemeral consumer simulation in `tool/verify_consumer_resolution.sh` avoiding static fixture clutter in git.
- Strict 140/140 score threshold in `tool/verify_pana.sh` ensuring maximum pub.dev score.
- Single `all-checks-passed` aggregate job in GitHub Actions for clean branch protection configuration.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed strictly within the phase scope.

</deferred>

---

*Phase: 13-Multi-Version Resolution & CI Test Matrix*
*Context gathered: 2026-11-21*
