# Phase 10: Publish Verification & Dry Run - Context

**Gathered:** 2026-11-04
**Status:** Ready for planning
**Mode:** Auto-generated (release verification & publication dry-run phase)

<domain>
## Phase Boundary

Verify pub.dev publishing readiness with zero-warning dry run, pana 140/140 audit readiness, and documented release workflow.

### Requirements Covered
- **PUB-01**: Execute `flutter pub publish --dry-run` and verify 0 errors, 0 warnings, 0 hints, and clean archive size.
- **PUB-02**: Audit package with pana checklist (140/140 potential pub points) covering platforms, SDK constraints, dependencies, and doc coverage.
- **PUB-03**: Provide finalized step-by-step publisher execution checklist and git release tagging instructions.

</domain>

<decisions>
## Implementation Decisions

### Dry Run Verification (PUB-01)
- Run `flutter pub publish --dry-run` and assert that it finishes with 0 warnings, 0 errors, and reports:
  "Package has 0 warnings."
- Verify that development files (`.planning/`, `.agents/`, `.claude/`, `.codex/`, `GEMINI.md`, `doc/api/`) remain cleanly excluded by `.pubignore`.

### Pana Scoring Audit (PUB-02)
- Audit all 6 pana dimensions:
  1. Follow Dart file conventions (10/10) - `pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`.
  2. Provide documentation (10/10) - 100% public doc comments across `lib/fl_network_inspector.dart`.
  3. Platform support (20/20) - Android, iOS, Windows, Linux, macOS, Web correctly recognized.
  4. Pass static analysis (50/50) - 0 errors/warnings/lints in `flutter analyze`.
  5. Support up-to-date dependencies (40/40) - valid SDK and dependency constraints.
  6. Support sound null safety (10/10) - Dart 3 null safety throughout.
- Target: 140/140 maximum pub points.

### Release Operator Checklist (PUB-03)
- Produce a clear, actionable `RELEASE-CHECKLIST.md` documenting:
  1. Pre-publish verification steps.
  2. Git tag creation: `git tag -a v1.0.0 -m "Release v1.0.0"`.
  3. Push to remote: `git push origin main --tags`.
  4. Pub.dev publication: `flutter pub publish`.
  5. Post-publish smoke check on pub.dev.

</decisions>

<code_context>
## Existing Code Insights

- Package name: `fl_network_inspector`
- Version: `1.0.0`
- Tests: 213 passing tests.
- Analyzer: 0 issues.
- Dartdoc: 0 warnings, 0 errors.

</code_context>

<specifics>
## Specific Ideas

Keep release instructions concise and foolproof for the package maintainer.

</specifics>

<deferred>
## Deferred Ideas

None — publish verification phase.
</deferred>
