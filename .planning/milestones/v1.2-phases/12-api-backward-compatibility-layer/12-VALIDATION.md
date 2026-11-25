---
phase: "12"
slug: "api-backward-compatibility-layer"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-21"
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter Test (`flutter_test` SDK) |
| **Config file** | `pubspec.yaml` + `analysis_options.yaml` |
| **Quick run command** | `flutter test test/ui/share_exporter_test.dart test/shake/shake_detector_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/ui/share_exporter_test.dart test/shake/shake_detector_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green (`bash tool/verify_lowest_bounds.sh && flutter test && flutter analyze --no-fatal-infos`)
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | API-01 | T-12-01 | ShareExporter defensive origin sanitization & clipboard fallback | unit / widget | `flutter test test/ui/share_exporter_test.dart` | ✅ | ⬜ pending |
| 12-01-02 | 01 | 1 | API-02 | T-12-02 | ShakeDetector NaN/Infinity coordinate discarding & error callback | unit | `flutter test test/shake/shake_detector_test.dart` | ✅ | ⬜ pending |
| 12-02-01 | 02 | 2 | API-03 | T-12-03 | SDK compatibility shims & 0 analyzer warnings | static / widget | `flutter analyze --no-fatal-infos && flutter test` | ✅ | ⬜ pending |
| 12-02-02 | 02 | 2 | API-04 | T-12-SC | Lowest-bounds test verification script with trap restoration | integration / shell | `bash tool/verify_lowest_bounds.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tool/verify_lowest_bounds.sh` — automated downgrade verification shell script with trap handlers and targeted package downgrade (REQ-API-04)
- [ ] Add explicit `import 'package:sqflite/sqflite.dart';` in `lib/src/storage/platform/ffi_init_io.dart` and storage tests for `sqflite: 2.2.0` compatibility

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 25s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
