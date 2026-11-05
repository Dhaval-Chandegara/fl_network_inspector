# Phase 10: Publish Verification & Dry Run - Research

**Phase Goal**: Verify pub.dev publishing readiness with zero-warning dry run, pana 140/140 audit readiness, and documented release workflow.
**Requirements**: PUB-01, PUB-02, PUB-03

## 1. Dry Run Verification (PUB-01)
- Command: `flutter pub publish --dry-run`
- Result: **Package has 0 warnings**.
- Total compressed archive size: **118 KB**.
- Archive contents include:
  - Root metadata: `CHANGELOG.md`, `LICENSE`, `README.md`, `analysis_options.yaml`, `pubspec.yaml`
  - Canonical library: `lib/fl_network_inspector.dart` and `lib/src/`
  - Example app: `example/`
  - Automated tests: `test/`
- Excluded cleanly:
  - `.planning/`, `.agents/`, `.claude/`, `.codex/`, `.opencode/`, `GEMINI.md`, build outputs, test caches.

## 2. Pana Audit & Score Breakdown (PUB-02)
Target Score: **140 / 140 points**
- **Follow Dart file conventions (10/10)**:
  - `pubspec.yaml` (name, version, description 119 chars, homepage, repository, issue_tracker, topics).
  - `README.md` (valid markdown, badges, guides).
  - `CHANGELOG.md` (Keep a Changelog, semver `1.0.0`).
  - `LICENSE` (standard MIT license).
- **Provide documentation (10/10)**:
  - `dart doc --dry-run` reports 0 errors and 0 warnings.
  - 100% public API doc coverage.
- **Platform support (20/20)**:
  - Android, iOS, Windows, Linux, macOS, Web correctly recognized.
- **Pass static analysis (50/50)**:
  - `flutter analyze` reports 0 errors, 0 warnings, 0 lints.
- **Support up-to-date dependencies (40/40)**:
  - All dependency version bounds are modern and compatible with Flutter 3.10+ and Dart 3.0+.
- **Support sound null safety (10/10)**:
  - Full sound null safety enabled.

## 3. Publisher Release Workflow (PUB-03)
A step-by-step developer guide `RELEASE-CHECKLIST.md` documenting:
1. Final pre-flight verification commands.
2. Git tagging: `git tag -a v1.0.0 -m "Release fl_network_inspector v1.0.0"`.
3. Pushing tags: `git push origin main --tags`.
4. Executing the live publish: `flutter pub publish`.
5. Post-publish validation on pub.dev.
