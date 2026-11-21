---
phase: "11"
slug: "dependency-bounds-widening"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-21"
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter Test (`flutter_test` SDK) |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `flutter test test/core/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/core/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green (`dart pub downgrade --dry-run && flutter test && flutter analyze --no-fatal-infos && flutter pub publish --dry-run`)
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | BOUND-01..05 | T-11-01, T-11-SC | Dependency bounds widening tracer | unit / smoke | `flutter test test/core/platform_safety_test.dart` | ✅ | ⬜ pending |
| 11-01-02 | 01 | 1 | BOUND-01..05 | T-11-02 | Subsystem regression verification | unit / integration | `flutter test test/repository/sqlite_repository_test.dart test/shake/shake_detector_test.dart test/interceptor/` | ✅ | ⬜ pending |
| 11-02-01 | 02 | 2 | BOUND-01 | T-11-03 | Popover anchor fallback geometry | widget / unit | `flutter test test/ui/share_exporter_test.dart` | ✅ | ⬜ pending |
| 11-02-02 | 02 | 2 | BOUND-01..05 | T-11-SC | Minimum-bounds downgrade check & publication quality gates | quality gate | `dart pub downgrade --dry-run && flutter test && flutter analyze --no-fatal-infos && flutter pub publish --dry-run` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements (213 tests across models, repository, interceptors, shake, and UI).

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
