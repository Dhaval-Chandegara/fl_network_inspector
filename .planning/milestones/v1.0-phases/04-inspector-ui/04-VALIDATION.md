---
phase: "04"
slug: "inspector-ui"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: true) (#2117)
status: draft
nyquist_compliant: true
wave_0_complete: false
created: "2026-11-01"
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Flutter SDK) |
| **Config file** | `pubspec.yaml` |
| **Quick run command** | `flutter test test/ui/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/ui/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | UI-01 | T-04-01 | Method badge, status color, duration, size rendered safely | widget | `flutter test test/ui/network_inspector_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | UI-02 | — | Threshold infinite scrolling requests 50 items at 80% depth | widget | `flutter test test/ui/pagination_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | UI-06 | — | Clear all confirmation dialog prompts before purging repository | widget | `flutter test test/ui/clear_all_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | UI-03 | T-04-03 | Debounced search queries across URL, method, status, payload | widget | `flutter test test/ui/search_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | UI-04 | — | Quick filter chips and modal bottom sheet filter records | widget | `flutter test test/ui/filter_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-03 | 02 | 2 | UI-05 | — | Sorting by timestamp, duration, and status code | widget | `flutter test test/ui/sorting_test.dart` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 2 | UI-07 | T-04-04 | 4 tabs (Overview, Request, Response, Error) render metadata & headers | widget | `flutter test test/ui/network_inspector_detail_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 2 | UI-08 | T-04-02 | Large JSON (>50KB) parsed off UI thread via compute; syntax colorized | unit/widget | `flutter test test/ui/json_viewer_test.dart` | ❌ W0 | ⬜ pending |
| 04-03-03 | 03 | 2 | UI-09 | — | Copy buttons set clipboard and display confirmation SnackBar | widget | `flutter test test/ui/clipboard_copy_test.dart` | ❌ W0 | ⬜ pending |
| 04-04-01 | 04 | 3 | UI-10 | — | Bash-escaped single quotes and multi-line cURL generated | unit | `flutter test test/ui/curl_generator_test.dart` | ❌ W0 | ⬜ pending |
| 04-04-02 | 04 | 3 | UI-11 | T-04-05 | Native share sheet export with iPadOS anchor view and header redaction | unit/widget | `flutter test test/ui/share_exporter_test.dart` | ❌ W0 | ⬜ pending |
| 04-04-03 | 04 | 3 | UI-07, UI-10, UI-11 | — | Export actions wired to detail screen with public barrel exports | widget | `flutter test test/ui/network_inspector_detail_screen_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add `share_plus: ^13.3.1` and `intl: ^0.20.3` to `pubspec.yaml`
- [ ] Add `navigatorKey` property to `NetworkInspectorConfig`
- [ ] `test/ui/helpers/test_record_fixtures.dart` — standardized mock `NetworkRecord` instances for widget tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Native OS Share Sheet Presentation | UI-11 | Native platform UI popover / activity view sheet cannot be tapped headlessly | Trigger Share Sheet on real iOS / Android / macOS device or simulator and verify system sheet opens with text. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending 2026-11-01
