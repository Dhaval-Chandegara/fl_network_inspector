# Roadmap: fl_network_inspector

## Milestones

- ✅ **v1.0 Initial Release** — Phases 1-6 (shipped 2026-11-03)
- ✅ **v1.1 Pub.dev Release Preparation** — Phases 7-10 (shipped 2026-11-05)
- 🚧 **v1.2 Backward Compatibility & Multi-Version Flutter Support** — Phases 11-14 (in progress)

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

<details>
<summary>✅ v1.1 Pub.dev Release Preparation (Phases 7-10) — SHIPPED 2026-11-05</summary>

- [x] **Phase 7: Packaging & Identity** (2/2 plans) — completed 2026-11-04
- [x] **Phase 8: Code Standards & Static Quality** (1/1 plans) — completed 2026-11-04
- [x] **Phase 9: Public API Documentation & Metadata** (1/1 plans) — completed 2026-11-04
- [x] **Phase 10: Publish Verification & Dry Run** (1/1 plans) — completed 2026-11-05

</details>

### 🚧 v1.2 Backward Compatibility & Multi-Version Flutter Support (In Progress)

**Milestone Goal:** Expand Flutter SDK and dependency compatibility to seamlessly support a wide matrix of Flutter versions (from Flutter 3.35/3.40 up through latest 3.50+) without pubspec dependency conflicts.

- [x] **Phase 11: Dependency Bounds Widening** - Audit and relax version constraints for core dependencies and client adapters. (completed 2026-11-21)
- [x] **Phase 12: API & Backward Compatibility Layer** - Implement resilient adapters and shims ensuring zero runtime crashes across dependency versions. (completed 2026-11-21)
- [ ] **Phase 13: Multi-Version Resolution & CI Test Matrix** - Validate pub resolution across target Flutter SDKs and establish multi-version CI automation.
- [ ] **Phase 14: Documentation & Publication Readiness** - Document supported version matrices, troubleshooting guidelines, and release notes for publication.

## Phase Details

### Phase 11: Dependency Bounds Widening
**Goal**: Audit and widen version constraints across core dependencies (`share_plus`, `sensors_plus`, `intl`, `sqflite`, `uuid`) and client adapters (`dio`, `http`) in `pubspec.yaml` to eliminate pub solver conflicts across Flutter 3.35 through 3.50+.
**Depends on**: Phase 10
**Requirements**: BOUND-01, BOUND-02, BOUND-03, BOUND-04, BOUND-05
**Success Criteria** (what must be TRUE):
  1. `pubspec.yaml` specifies widened semantic version constraints for `share_plus` (e.g. `>=9.0.0 <14.0.0`), `sensors_plus` (e.g. `>=4.0.0 <8.0.0`), `intl` (`>=0.18.0 <0.21.0`), `sqflite` / `sqflite_common_ffi` (`>=2.2.0 <3.0.0`), and `uuid` (`>=3.0.0 <5.0.0`).
  2. Client adapter constraints for `dio` (`>=5.0.0 <6.0.0`) and `http` (`>=1.0.0 <2.0.0`) allow host projects to resolve without version locking.
  3. `dart pub get` completes successfully in the development workspace with the widened bounds without solver conflicts or resolution errors.
**Plans:** 2 plans

Plans:
**Wave 1**
- [x] 11-01-PLAN.md — Widen dependency constraints across core libraries and client adapters in pubspec.yaml with resolution tracer

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 11-02-PLAN.md — Reinforce iPadOS popover share anchor fallback geometry and complete publication dry-run quality gates

### Phase 12: API & Backward Compatibility Layer
**Goal**: Implement resilient adapters, shims, and runtime guards ensuring zero compilation breaks or runtime exceptions across the entire supported dependency version spectrum and older Flutter SDKs.
**Depends on**: Phase 11
**Requirements**: API-01, API-02, API-03, API-04
**Success Criteria** (what must be TRUE):
  1. Share export functionality executes identically without runtime crashes or deprecated API exceptions across both minimum and latest supported `share_plus` versions (including iPadOS/macOS `sharePositionOrigin`).
  2. Shake detection initializes and listens via `userAccelerometerEventStream()` across minimum and latest supported `sensors_plus` versions with graceful fallback when hardware is missing or stream emits null.
  3. Package source code compiles and executes cleanly without unsupported Dart/Flutter language constructs on Flutter 3.35+ (Dart 3.x baseline).
  4. All 210+ package automated unit, integration, and widget tests pass 100% when running against lowest resolved dependency bounds using `sqflite_common_ffi`.
**Plans:** 2/2 plans complete

Plans:
**Wave 1**
- [x] 12-01-PLAN.md — Harden ShareExporter and ShakeDetector runtime resilience across plugin versions

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 12-02-PLAN.md — Standardize Flutter SDK window metrics, align dependency floors, and implement lowest-bounds test pipeline

### Phase 13: Multi-Version Resolution & CI Test Matrix
**Goal**: Validate pub dependency resolution across simulated consumer environments and configure an automated multi-version CI test matrix.
**Depends on**: Phase 12
**Requirements**: MATRIX-01, MATRIX-02, MATRIX-03
**Success Criteria** (what must be TRUE):
  1. `pub get` resolves successfully in simulated consumer pubspecs matching target Flutter releases (Flutter 3.35, 3.40, 3.45, and 3.50+) without dependency solver conflicts.
  2. Automated GitHub Actions CI workflow runs across a multi-version Flutter matrix (min, intermediate, latest stable) and reports passing status for test and analysis runs.
  3. `flutter pub publish --dry-run` and `pana` analysis pass with 0 errors, 0 warnings, and maintain a full 140/140 quality score.
**Plans:** 2 plans

Plans:
**Wave 1**
- [ ] 13-01-PLAN.md — Ephemeral consumer resolution simulation and packaging pana quality gate scripts

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 13-02-PLAN.md — Multi-version GitHub Actions CI matrix and aggregate branch protection gate

### Phase 14: Documentation & Publication Readiness
**Goal**: Publish comprehensive developer guidance for version compatibility, dependency troubleshooting, and release documentation for milestone v1.2.
**Depends on**: Phase 13
**Requirements**: DOC-01, DOC-02, DOC-03
**Success Criteria** (what must be TRUE):
  1. `README.md` features a comprehensive Flutter & dependency compatibility matrix documenting supported versions for all core dependencies.
  2. `README.md` includes a dedicated dependency troubleshooting and resolution guide detailing recommended dependency overrides or constraint alignments.
  3. `CHANGELOG.md` contains clear release notes for milestone v1.2 detailing the widened compatibility ranges and migration/upgrade guidance.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 11 → 12 → 13 → 14

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & Models | v1.0 | 3/3 | Complete | 2026-10-31 |
| 2. SQLite Persistence | v1.0 | 3/3 | Complete | 2026-11-01 |
| 3. Network Capture & Interceptors | v1.0 | 3/3 | Complete | 2026-11-01 |
| 4. Inspector UI | v1.0 | 4/4 | Complete | 2026-11-02 |
| 5. Shake & Developer Experience | v1.0 | 2/2 | Complete | 2026-11-03 |
| 6. Quality, Testing & Release | v1.0 | 2/2 | Complete | 2026-11-03 |
| 7. Packaging & Identity | v1.1 | 2/2 | Complete | 2026-11-04 |
| 8. Code Standards & Static Quality | v1.1 | 1/1 | Complete | 2026-11-04 |
| 9. Public API Documentation & Metadata | v1.1 | 1/1 | Complete | 2026-11-04 |
| 10. Publish Verification & Dry Run | v1.1 | 1/1 | Complete | 2026-11-05 |
| 11. Dependency Bounds Widening | v1.2 | 2/2 | Complete | 2026-11-21 |
| 12. API & Backward Compatibility Layer | v1.2 | 2/2 | Complete    | 2026-11-21 |
| 13. Multi-Version Resolution & CI Test Matrix | v1.2 | 0/2 | Not started | - |
| 14. Documentation & Publication Readiness | v1.2 | 0/TBD | Not started | - |
