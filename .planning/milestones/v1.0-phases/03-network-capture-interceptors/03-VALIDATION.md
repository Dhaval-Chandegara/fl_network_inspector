---
phase: "03"
slug: "network-capture-interceptors"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-01"
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) / `test` (`^1.25.0`) |
| **Config file** | `pubspec.yaml` |
| **Quick run command** | `flutter test test/interceptor/stream_tap_transformer_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick/scoped command for modified area (e.g. `flutter test test/interceptor/`)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | INTC-03 | T-03-03 | Byte-bounded chunk buffering up to 1MB | unit | `flutter test test/interceptor/stream_tap_transformer_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | INTC-02 | T-03-04 | Preserves host proxy & SSL delegate | unit | `flutter test test/interceptor/http_overrides_chaining_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | INTC-01 | T-03-01 | Non-destructive `dart:io` proxy capture | integration | `flutter test test/interceptor/http_client_interceptor_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | INTC-06 | T-03-01 | Synthetic header injection & wire stripping | unit | `flutter test test/interceptor/deduplication_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | INTC-04 | T-03-02 | Dio interceptor lifecycle & error handling | unit | `flutter test test/interceptor/dio_interceptor_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-03 | 02 | 2 | INTC-05 | T-03-02 | `http.BaseClient` adapter interception | unit | `flutter test test/interceptor/http_client_adapter_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 3 | INTC-07 | T-03-03 | Socket failures & timeouts captured as failed | unit | `flutter test test/interceptor/error_interception_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-02 | 03 | 3 | LOG-01 | T-03-05 | `NetworkInspector.logApi` / `startRequest` | unit | `flutter test test/logging/manual_logging_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-03 | 03 | 3 | LOG-02 | T-03-02 | Parameter decoding & redaction | unit | `flutter test test/logging/manual_logging_parameters_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/interceptor/stream_tap_transformer_test.dart` — tests non-destructive stream tapping, truncation, and single-subscription preservation (INTC-03)
- [ ] `test/interceptor/http_overrides_chaining_test.dart` — tests parent override preservation and restoration (INTC-02)
- [ ] `test/interceptor/http_client_interceptor_test.dart` — tests `dart:io` transparent client proxy interception (INTC-01)
- [ ] `test/interceptor/deduplication_test.dart` — tests synthetic tracking header injection, wire stripping, and duplicate suppression (INTC-06)
- [ ] `test/interceptor/dio_interceptor_test.dart` — tests Dio request/response/error interceptor hooks (INTC-04)
- [ ] `test/interceptor/http_client_adapter_test.dart` — tests `package:http` BaseClient adapter (INTC-05)
- [ ] `test/interceptor/error_interception_test.dart` — tests socket errors, timeouts, and partial body retention (INTC-07)
- [ ] `test/logging/manual_logging_test.dart` — tests `NetworkInspector.logApi`, `startRequest`, and `logError` (LOG-01)
- [ ] `test/logging/manual_logging_parameters_test.dart` — tests flexible body parameter, redaction, and metadata (LOG-02)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | All network capture, interceptor, and logging behaviors have automated headless test verification. | — |

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending 2026-11-01
