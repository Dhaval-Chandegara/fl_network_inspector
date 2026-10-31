---
phase: "02"
slug: "sqlite-persistence"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-31"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Flutter SDK) / `sqflite_common_ffi` (`^2.4.5`) |
| **Config file** | `pubspec.yaml` |
| **Quick run command** | `flutter test test/repository/ test/storage/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/repository/` or `flutter test test/storage/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | DB-01, DB-02 | T-02-02 | Dependencies configured; FFI test harness initialized without native compile errors | integration | `flutter test test/storage/database_harness_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | DB-02 | T-02-01, T-02-02 | SQLite schema creates indexed columns, B-tree indexes, WAL mode & NORMAL synchronous pragmas | unit | `flutter test test/storage/database_schema_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | DB-05 | T-02-01 | Database migration manager handles versioning, table creation, and upgrades | unit | `flutter test test/storage/database_migration_test.dart` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | DB-03 | T-02-02 | WriteBufferQueue debounces (200ms), coalesces pairs, and bursts on high-water mark (20 items) | unit | `flutter test test/repository/write_buffer_queue_test.dart` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | DB-04 | T-02-03 | Hysteresis pruning purges oldest 50 records only when count > maxRecords + 50 via indexed subquery | unit | `flutter test test/storage/database_pruner_test.dart` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 3 | DB-01, DB-06 | T-02-01, T-02-04 | SqliteNetworkInspectorRepository satisfies contract using parameterized queries and FFI | unit/integration | `flutter test test/repository/sqlite_repository_test.dart` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 3 | DB-06 | T-02-04 | InMemoryNetworkInspectorRepository provides in-memory fallback for Web and memory mode | unit | `flutter test test/repository/in_memory_repository_test.dart` | ❌ W0 | ⬜ pending |
| 02-03-03 | 03 | 3 | DB-01..DB-06 | T-02-01..T-02-04 | Facade wires repository based on config/platform, barrel exports updated, full test suite green | integration | `flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add `sqflite: ^2.4.5`, `sqflite_common_ffi: ^2.4.5`, and `path: ^1.9.1` to `pubspec.yaml`
- [ ] `test/storage/database_harness_test.dart` — helper/harness for headless in-memory FFI SQLite testing
- [ ] `test/storage/database_schema_test.dart` — schema and pragma verification
- [ ] `test/storage/database_migration_test.dart` — migration execution and upgrade verification
- [ ] `test/repository/write_buffer_queue_test.dart` — debouncing, coalescing, and high-water flushing
- [ ] `test/storage/database_pruner_test.dart` — hysteresis threshold pruning and clear all
- [ ] `test/repository/sqlite_repository_test.dart` — SQLite repository operations (insert, query, filter, sort, pagination)
- [ ] `test/repository/in_memory_repository_test.dart` — In-memory repository fallback operations

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| *None* | N/A | All persistence, indexing, buffering, pruning, and migration logic runs headless via `sqflite_common_ffi`. | All phase behaviors have automated verification. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending 2026-10-31
