# Milestones

## v1.2 Backward Compatibility & Multi-Version Flutter Support (Shipped: 2026-11-25)

**Phases completed:** 4 phases, 8 plans, 12 tasks (51 commits, 74 files changed, 16,645 Dart LOC)
**Closeout type:** Override closeout — Phase 11 and Phase 12 verification reports marked stale after subsequent edits in Phases 12/14; user approved proceeding without re-running verification.

**Key accomplishments:**
- Widened semver constraints across 9 core dependencies (`share_plus`, `sensors_plus`, `intl`, `sqflite`, `sqflite_common_ffi`, `uuid`, `path`, `dio`, `http`) and reinforced iPadOS popover share anchor geometry.
- Defensive popover origin sanitization and clipboard fallback for `ShareExporter` alongside NaN vector guards and sensor error observers for `ShakeDetector`.
- Standardized `MediaQuery` queries in `FilterBottomSheet`, aligned dependency floors in `pubspec.yaml`, hardened SQLite FFI imports, and added an automated lowest-bounds verification pipeline in `tool/verify_lowest_bounds.sh`.
- Delivered standalone automated verification scripts for consumer pub resolution simulation across 4 archetypes (`tool/verify_consumer_resolution.sh`) and pub.dev publication packaging QA (`tool/verify_pana.sh`) enforcing 0 dry-run warnings and >= 140/140 pana score.
- Configured the multi-version GitHub Actions CI automation matrix in `.github/workflows/ci.yml` featuring pull request concurrency controls, a fail-fast quality gate, parallel consumer resolution and lowest-bounds downgrade verification, a multi-version Flutter matrix (`stable`, `beta`, `3.22.0`), desktop multi-OS smoke tests (`macos-latest`, `windows-latest`), and an aggregate branch protection gate job (`all-checks-passed`).
- Added two-tier Flutter/Dart & ecosystem compatibility tables, restructured Quick Start into a 3-step v1.2.0 setup, authored the collapsible PubGrub troubleshooting cookbook in `README.md`, bumped `pubspec.yaml` to `1.2.0`, authored `example/README.md`, and added `CHANGELOG.md` release notes and migration guide.

---

## v1.1 Pub.dev Release Preparation (Shipped: 2026-11-05)

**Phases completed:** 4 phases, 5 plans, 6 tasks

**Key accomplishments:**
- Package renamed to `fl_network_inspector` v1.0.0 with canonical `lib/fl_network_inspector.dart` entry point, example consumer wiring, and 100% passing test suite across all 210 tests.
- Strict `.pubignore` configuration created and package publishing boundaries validated with `flutter pub publish --dry-run` achieving 0 warnings and 0 errors under the `fl_network_inspector` v1.0.0 identity.
- Enforced official Dart code formatting across 74 workspace files, resolved analyzer lint in barrel export test, verified 0 static analysis issues on root and example app, and passed all 210 regression tests.

---

## v1.0 Initial Release (Shipped: 2026-11-03)

**Phases completed:** 6 phases, 17 plans, 66+ commits, 15,390 lines of code

**Key accomplishments:**
- **Foundation & Redaction**: Built immutable Dart 3 domain models (`NetworkRecord`, `PayloadData`), 1MB memory payload truncator, and recursive regex credential redactor.
- **SQLite Persistence**: Engineered WAL-mode SQLite repository via `sqflite` with asynchronous write buffering and threshold FIFO pruning.
- **Transparent Interception**: Implemented non-destructive `HttpOverrides` chaining, dedicated `Dio` interceptor, and `package:http` client adapter with cross-interceptor deduplication.
- **Material 3 Inspector UI**: Designed dark-mode in-app debugging UI with real-time multi-parameter search, compound filtering, 4-tab details screen, background isolate JSON viewer, cURL generator, and native share sheet export.
- **Developer Experience & Shake**: Created accelerometer shake detection with gravity subtraction (`sensors_plus`), root `NetworkInspectorWrapper`, singleton `NetworkInspector.navigatorKey`, and Android 16 Edge-to-Edge + 16KB page size alignment.
- **Quality & Testing**: Achieved 100% test pass rate across 210 unit, integration, and widget tests with zero static analysis issues, accompanied by full documentation and an interactive reference example app.

---
