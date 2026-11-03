---
phase: "02"
slug: "sqlite-persistence"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-11-01"
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail for local SQLite persistence and repository caching.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Application / Network → SQLite File | Network metadata and serialized JSON payloads written to embedded SQLite file | Sanitized HTTP request/response metadata, headers, query parameters, payloads |
| In-Memory Queue → Disk I/O | Write buffer batches in-memory records before passing to SQLite platform channel | Unsaved pending and completed NetworkRecord maps |
| UI / Consumer Query → SQLite Driver | Filter and search query inputs crossing into SQL database query engine | Search text, status codes, HTTP methods, date and duration ranges |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-02-01 | Tampering | DatabaseManager | high | mitigate | Configured `PRAGMA journal_mode = WAL` and `PRAGMA synchronous = NORMAL` in `DatabaseManager._openDatabase` per D-19 to eliminate SQLite lock contention and database locked errors. Verified in `test/storage/database_harness_test.dart`. | closed |
| T-02-02 | Information Disclosure | DatabaseManager.onUpgrade | medium | mitigate | Implemented explicit versioned migration pipeline with sequential non-destructive `ALTER TABLE` steps per D-20 to prevent data loss or table truncation on package updates. Verified in `test/storage/database_migration_test.dart`. | closed |
| T-02-03 | Denial of Service | WriteBufferQueue | high | mitigate | Implemented 200ms debounce with 10-item micro-batches and 20-item high-water burst protection (D-21, D-23) to eliminate UI isolate frame drops during high-traffic network bursts. Verified in `test/repository/write_buffer_queue_test.dart`. | closed |
| T-02-04 | Denial of Service | DatabasePruner | high | mitigate | Enforced threshold hysteresis FIFO pruning at `maxRecords + 50` via indexed subquery (D-25, D-26) to prevent unbounded database growth and eliminate per-insert write amplification. Verified in `test/storage/database_pruner_test.dart`. | closed |
| T-02-05 | Injection | DatabaseQueryBuilder | high | mitigate | Built parameterized SQL queries using prepared statements and `whereArgs` arrays for all filter parameters (`searchQuery`, `httpMethods`, `statusCodes`, `errorOnly`, bounds) to eliminate SQL injection vulnerabilities. Verified in `test/storage/database_query_builder_test.dart`. | closed |
| T-02-06 | Information Disclosure | SqliteNetworkInspectorRepository | high | mitigate | Sensitive authorization headers, cookies, tokens, and credentials are deep-redacted via `RedactionEngine` and truncated via `PayloadTruncator` before records reach persistence per DATA-06 to ensure plaintext secrets are never written to SQLite disk storage. Verified in test suites. | closed |
| T-02-SC | Tampering | pub dependencies | high | mitigate | Package legitimacy audit verified on pub.dev for `sqflite ^2.4.5`, `sqflite_common_ffi ^2.4.5`, and `path ^1.9.1`; deprecated `sqlite3_flutter_libs` strictly excluded. Verified in `pubspec.yaml`. | closed |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|

*No accepted risks.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-01 | 7 | 7 | 0 | gsd-security-auditor |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-01
