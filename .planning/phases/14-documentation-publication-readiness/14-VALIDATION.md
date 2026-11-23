---
phase: "14"
slug: "documentation-publication-readiness"
status: draft
nyquist_compliant: false
wave_0_complete: true
created: "2026-11-23"
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `test: ^1.25.0` |
| **Config file** | `pubspec.yaml` (`dev_dependencies`) & `analysis_options.yaml` |
| **Quick run command** | `flutter analyze --no-fatal-infos` |
| **Full suite command** | `flutter test --no-pub && bash tool/verify_pana.sh` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze --no-fatal-infos`
- **After every plan wave:** Run `bash tool/verify_pana.sh`
- **Before `/gsd-verify-work`:** Full suite must be green (`flutter test --no-pub`, `bash tool/verify_consumer_resolution.sh`, and `bash tool/verify_pana.sh`)
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | DOC-01 | T-14-01 | Accurate documented SDK & dependency bounds prevent conflicting or vulnerable package resolutions | doc | `git diff README.md && grep -q "Flutter & Dependency Compatibility" README.md` | ✅ | ⬜ pending |
| 14-01-02 | 01 | 1 | DOC-02 | T-14-02 | Troubleshooting guide advises against unsafe overrides and documents safe conflict resolution recipes | doc | `grep -q "Troubleshooting & Conflict Resolution" README.md && grep -q "dependency_overrides" README.md` | ✅ | ⬜ pending |
| 14-02-01 | 02 | 1 | DOC-03 | T-14-03 | CHANGELOG.md, pubspec.yaml, and example align cleanly with zero warnings | metadata | `grep -q "## \[1.2.0\] - 2026-11-23" CHANGELOG.md && grep -q "version: 1.2.0" pubspec.yaml` | ✅ | ⬜ pending |
| 14-02-02 | 02 | 1 | DOC-03 | T-14-03 | Verified publication package quality score >= 140/160 with 0 dry-run warnings | quality gate | `bash tool/verify_pana.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Existing scripts (`tool/verify_pana.sh`, `tool/verify_consumer_resolution.sh`, `tool/verify_lowest_bounds.sh`) and tests fully support verification.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual inspection of README formatting on GitHub markdown preview | DOC-01, DOC-02 | Markdown rendering of tables and `<details>` accordions | Inspect README.md in GitHub web view or local markdown preview to ensure collapsible accordions expand cleanly |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending 2026-11-23
