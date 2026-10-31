---
phase: "01"
slug: "foundation-models"
status: ready
nyquist_compliant: true
wave_0_complete: false
created: "2026-10-31"
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter Test / Dart Test (`test: ^1.25.0`, `flutter_test: sdk`) |
| **Config file** | `pubspec.yaml` (root) |
| **Quick run command** | `flutter test test/models/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/models/` or specific target test
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | CORE-02 | — | Valid package structure and pubspec dependencies | unit | `flutter pub get` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | CORE-01 | T-01-04 | Release mode no-op by default with explicit override | unit | `flutter test test/config/network_inspector_config_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | CORE-03 | — | Zero `dart:io` imports in models/config/utils | unit | `flutter test test/core/platform_safety_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | DATA-01 | T-01-05 | RFC 4122 v4 UUID and immutable request metadata | unit | `flutter test test/models/network_record_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | DATA-02 | — | Response metadata and error details serialization | unit | `flutter test test/models/http_error_details_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | DATA-03 | — | BodyType detection for JSON, text, form, binary, empty | unit | `flutter test test/models/payload_data_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-04 | 02 | 1 | DATA-04 | T-01-03 | MultipartEntry metadata capture with null filePath default | unit | `flutter test test/models/multipart_entry_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | DATA-05 | T-01-02 | 1MB truncation ceiling without UTF-8 decode crash | unit | `flutter test test/utils/payload_truncator_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | DATA-06 | T-01-01 | Case-insensitive deep recursive JSON/URL/header redaction | unit | `flutter test test/utils/redaction_engine_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-03 | 03 | 2 | CORE-02 | — | Barrel export verification (`lib/flutter_network_inspector.dart`) | unit | `flutter test test/core/barrel_export_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `pubspec.yaml` — Package metadata, Dart/Flutter SDK bounds, and dev dependencies (`flutter_test`, `flutter_lints`)
- [ ] `test/config/network_inspector_config_test.dart` — Stubs for CORE-01
- [ ] `test/core/barrel_export_test.dart` — Stubs for CORE-02
- [ ] `test/core/platform_safety_test.dart` — Stubs for CORE-03
- [ ] `test/models/network_record_test.dart` — Stubs for DATA-01, DATA-02
- [ ] `test/models/payload_data_test.dart` — Stubs for DATA-03
- [ ] `test/models/multipart_entry_test.dart` — Stubs for DATA-04
- [ ] `test/utils/payload_truncator_test.dart` — Stubs for DATA-05
- [ ] `test/utils/redaction_engine_test.dart` — Stubs for DATA-06

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| *None* | — | — | All phase behaviors have automated verification. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
