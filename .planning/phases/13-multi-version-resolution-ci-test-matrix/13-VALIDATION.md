---
phase: "13"
slug: "multi-version-resolution-ci-test-matrix"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-23"
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Flutter SDK) & `test: ^1.25.0` |
| **Config file** | `pubspec.yaml`, `analysis_options.yaml` |
| **Quick run command** | `flutter test test/core/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/core/` & `flutter analyze --no-fatal-infos`
- **After every plan wave:** Run `bash tool/verify_consumer_resolution.sh && bash tool/verify_lowest_bounds.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | MATRIX-01 | T-13-01 | Safe ephemeral sandbox isolation using mktemp -d with cleanup trap | integration | `bash tool/verify_consumer_resolution.sh` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | MATRIX-03 | T-13-02 | Deterministic pana score verification >= 140 points without publishing | script | `bash tool/verify_pana.sh` | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 2 | MATRIX-02 | T-13-03 | GitHub Actions CI matrix with read-only permissions and concurrency cancellation | ci-config | `gh workflow run ci.yml --ref $(git branch --show-current) || cat .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 2 | MATRIX-02 | T-13-04 | End-to-end all-checks-passed branch protection aggregate gate | ci-config | `grep -q "all-checks-passed" .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tool/verify_consumer_resolution.sh` — covers MATRIX-01 (ephemeral consumer simulation across 4 archetypes)
- [ ] `tool/verify_pana.sh` — covers MATRIX-03 (pana >= 140 points threshold check & dry-run)
- [ ] `.github/workflows/ci.yml` — covers MATRIX-02 (multi-version Flutter matrix & quality gate)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GitHub Actions runner execution across `macos-latest` and `windows-latest` | MATRIX-02 | Requires remote GitHub Actions runner environment | Push commit to GitHub or trigger workflow via GitHub UI/CLI to observe live runner execution |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
