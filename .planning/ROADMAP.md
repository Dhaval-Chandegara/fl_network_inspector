# Roadmap: flutter_network_inspector

## Milestones

- ✅ **v1.0 Initial Release** — Phases 1-6 (shipped 2026-11-03)
- 🚧 **v1.1 Pub.dev Release Preparation** — Phases 7-10 (in progress)

## Phases

<details>
<summary>✅ v1.0 Initial Release (Phases 1-6) — SHIPPED 2026-11-03</summary>

- [x] **Phase 1: Foundation & Models** (3/3 plans) — completed 2026-10-31
- [x] **Phase 2: SQLite Persistence** (3/3 plans) — completed 2026-11-01
- [x] **Phase 3: Network Capture & Interceptors** (3/3 plans) — completed 2026-11-01
- [x] **Phase 4: Inspector UI** (4/4 plans) — completed 2026-11-02
- [x] **Phase 5: Shake & Developer Experience** (2/2 plans) — completed 2026-11-03
- [x] **Phase 6: Quality, Testing & Release** (2/2 plans) — completed 2026-11-03

</details>

### 🚧 v1.1 Pub.dev Release Preparation (In Progress)

**Milestone Goal:** Prepare the package for publication on pub.dev under `fl_network_inspector` v1.0.0, achieving maximum pana score, complete public documentation, clean packaging, and verified dry-run.

- [x] **Phase 7: Packaging & Identity** - Align package naming to fl_network_inspector, update imports, and configure publishing rules. (completed 2026-11-04)
- [ ] **Phase 8: Code Standards & Static Quality** - Apply code formatting, resolve all static analysis issues, and verify all automated tests.
- [ ] **Phase 9: Public API Documentation & Metadata** - Complete dartdoc documentation for all public APIs, polish README, CHANGELOG, and license.
- [ ] **Phase 10: Publish Verification & Dry Run** - Verify package via flutter pub publish dry run and complete pana audit checklist.

## Phase Details

### Phase 7: Packaging & Identity
**Goal**: Establish official package identity as `fl_network_inspector` v1.0.0 across all package manifests, import declarations, and publish exclusion rules.
**Depends on**: Phase 6
**Requirements**: PKG-01, PKG-02, PKG-03
**Success Criteria** (what must be TRUE):
  1. `pubspec.yaml` specifies package name `fl_network_inspector`, version `1.0.0`, valid description, and verified repository, issue tracker, and homepage URLs.
  2. All Dart source files in `lib/`, `test/`, and `example/` import from `package:fl_network_inspector/` with zero unresolved URI errors or references to the old package name.
**Plans:** 2/2 plans complete

Plans:
**Wave 1**
- [x] 07-01-PLAN.md — Manifest identity, root library rename, example wiring, and test import migration

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 07-02-PLAN.md — Publication ignore rules (.pubignore) and dry-run packaging verification

### Phase 8: Code Standards & Static Quality
**Goal**: Enforce strict code formatting, resolve all static analysis issues across the workspace, and confirm the entire automated test suite passes with zero regressions.
**Depends on**: Phase 7
**Requirements**: CODE-01, CODE-02, CODE-03
**Success Criteria** (what must be TRUE):
  1. `dart format --output=none --set-exit-if-changed .` exits with code 0 across the entire package, test suite, and example application.
  2. `flutter analyze` reports 0 issues, 0 warnings, and 0 lint violations across both the root package and `example/`.
  3. `flutter test` executes all 210 existing unit, integration, and widget tests cleanly with 100% passing and zero regressions under the new package identity.
**Plans**: TBD

### Phase 9: Public API Documentation & Metadata
**Goal**: Deliver complete public API dartdoc documentation, a developer-friendly README, structured CHANGELOG, and verified open-source LICENSE for pub.dev.
**Depends on**: Phase 8
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04
**Success Criteria** (what must be TRUE):
  1. `dart doc` generates API documentation with 100% documentation coverage across all exported symbols in `lib/fl_network_inspector.dart` without missing doc warnings.
  2. `README.md` provides pub.dev badges, feature highlights, installation and initialization guides, shake detection usage, client adapter code samples, and platform compatibility table.
  3. `CHANGELOG.md` documents `1.0.0` release notes adhering to Keep a Changelog and Semantic Versioning standards.
  4. `LICENSE` contains standard MIT license text with accurate copyright holder and year.
**Plans**: TBD

### Phase 10: Publish Verification & Dry Run
**Goal**: Verify pub.dev publishing readiness with zero-warning dry run, pana 140/140 audit readiness, and documented release workflow.
**Depends on**: Phase 9
**Requirements**: PUB-01, PUB-02, PUB-03
**Success Criteria** (what must be TRUE):
  1. `flutter pub publish --dry-run` executes with 0 warnings, 0 errors, and confirms archive size is compact and free of excluded development directories.
  2. Package satisfies all pana checklist criteria (platforms detected, sound null safety, valid constraints, zero analyzer issues, full doc comments).
  3. Publisher checklist and git release tagging instructions are verified and documented for the release operator.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 7 → 8 → 9 → 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & Models | v1.0 | 3/3 | Complete | 2026-10-31 |
| 2. SQLite Persistence | v1.0 | 3/3 | Complete | 2026-11-01 |
| 3. Network Capture & Interceptors | v1.0 | 3/3 | Complete | 2026-11-01 |
| 4. Inspector UI | v1.0 | 4/4 | Complete | 2026-11-02 |
| 5. Shake & Developer Experience | v1.0 | 2/2 | Complete | 2026-11-03 |
| 6. Quality, Testing & Release | v1.0 | 2/2 | Complete | 2026-11-03 |
| 7. Packaging & Identity | v1.1 | 2/2 | Complete    | 2026-11-04 |
| 8. Code Standards & Static Quality | v1.1 | 0/TBD | Not started | - |
| 9. Public API Documentation & Metadata | v1.1 | 0/TBD | Not started | - |
| 10. Publish Verification & Dry Run | v1.1 | 0/TBD | Not started | - |
