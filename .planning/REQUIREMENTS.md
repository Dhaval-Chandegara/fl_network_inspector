# Requirements: fl_network_inspector

**Defined:** 2026-11-20
**Core Value:** Reliably capture, persist, and inspect HTTP requests and responses directly inside a Flutter application without breaking or modifying existing network streams, degrading app performance, or leaking sensitive data.

## Milestone v1.2 Requirements

Requirements for backward compatibility and multi-version Flutter support (Flutter 3.35 - 3.50+). Each maps to roadmap phases.

### Dependency Bounds Widening (BOUND)

- [x] **BOUND-01**: Audit and relax lower and upper version bounds for `share_plus` (e.g. `>=9.0.0 <14.0.0`) without breaking public sharing APIs.
- [x] **BOUND-02**: Audit and relax lower and upper version bounds for `sensors_plus` (e.g. `>=4.0.0 <8.0.0`) while retaining `userAccelerometerEventStream()`.
- [x] **BOUND-03**: Relax `intl` constraint to `>=0.18.0 <0.21.0` to eliminate conflicts with `flutter_localizations` in older Flutter SDKs.
- [x] **BOUND-04**: Relax `sqflite` and `sqflite_common_ffi` constraints (e.g. `>=2.2.0 <3.0.0`) and `uuid` (`>=3.0.0 <5.0.0` or `^4.0.0`) for wide consumer compatibility.
- [x] **BOUND-05**: Ensure `dio` (`>=5.0.0 <6.0.0`) and `http` (`>=1.0.0 <2.0.0`) maintain maximum client versatility.

### API Compatibility & Resilient Implementation (API)

- [x] **API-01**: Verify and adapt all `share_plus` calls so they execute identically across both older and newer `share_plus` versions (handling `sharePositionOrigin` and `Share.share` / `Share.shareXFiles`).
- [x] **API-02**: Verify and adapt `sensors_plus` calls for stream subscription across older and newer plugin versions with graceful null/sensor-absent handling.
- [x] **API-03**: Verify Dart and Flutter language/SDK feature compatibility across Flutter 3.35+ (Dart 3.x) to ensure no newer-only language features or SDK methods break on older toolchains.
- [x] **API-04**: Ensure all 210+ package tests pass under the lowest resolved dependency matrix using `sqflite_common_ffi`.

### Multi-Version Resolution & CI Validation Matrix (MATRIX)

- [x] **MATRIX-01**: Test and verify `pub get` resolution against simulated consumer pubspec environments for target Flutter releases (Flutter 3.35, 3.40, 3.45, 3.50+).
- [x] **MATRIX-02**: Create an automated GitHub Actions CI workflow with a Flutter version matrix testing across target Flutter channels/versions.
- [x] **MATRIX-03**: Validate dependency resolution with `--dry-run` and verify `pana` analysis score remains at 140/140 with widened bounds.

### Documentation & Consumer Guidance (DOC)

- [ ] **DOC-01**: Document supported Flutter version matrix in `README.md` and pubspec compatibility guide.
- [ ] **DOC-02**: Provide dependency conflict troubleshooting guide and recommended `pubspec.yaml` setups in `README.md`.
- [ ] **DOC-03**: Update `CHANGELOG.md` with milestone v1.2 release notes detailing widened compatibility.

## Future Requirements

### Post-v1.2 Features (v1.3+)

- **EXP-01**: In-memory ring buffer mode option (`enableDatabase: false`) without requiring SQLite.
- **EXP-02**: GraphQL operation name and query extraction in detail view.
- **EXP-03**: Har/Charles export format support.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Supporting Dart 2 / non-null-safe Flutter (<3.0.0) | Dart 3 sound null-safety is a hard constraint for package reliability and modern Dart idioms. |
| Vendoring / copy-pasting third-party plugin source code into package | Maintenance nightmare; package should rely on clean semantic version ranges rather than vendoring C/Java/Kotlin code. |
| Network traffic tampering / mock responses | Inspector is strictly observational; proxy interception tampering is out of scope. |
| Remote cloud telemetry sync | Privacy-first local SQLite architecture only. |
| Code generation dependencies (`build_runner`) | Avoid adding heavy build-time dependencies to consumer Flutter apps. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOUND-01 | Phase 11 | Complete |
| BOUND-02 | Phase 11 | Complete |
| BOUND-03 | Phase 11 | Complete |
| BOUND-04 | Phase 11 | Complete |
| BOUND-05 | Phase 11 | Complete |
| API-01 | Phase 12 | Complete |
| API-02 | Phase 12 | Complete |
| API-03 | Phase 12 | Complete |
| API-04 | Phase 12 | Complete |
| MATRIX-01 | Phase 13 | Complete |
| MATRIX-02 | Phase 13 | Complete |
| MATRIX-03 | Phase 13 | Complete |
| DOC-01 | Phase 14 | Pending |
| DOC-02 | Phase 14 | Pending |
| DOC-03 | Phase 14 | Pending |

**Coverage:**
- v1.2 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0 ✓

---
*Requirements defined: 2026-11-20*
*Last updated: 2026-11-20 for milestone v1.2 initialization*
