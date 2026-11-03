# Phase 2: SQLite Persistence - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-31  
**Phase:** 2-SQLite Persistence  
**Areas discussed:** Schema Design & Table Architecture, Buffer Queue & Write Concurrency, FIFO Pruning Trigger Strategy, Platform & Headless Testing Architecture  

---

## Schema Design & Table Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Single unified table (`network_records`) | Dedicated indexed columns for search/filter (status, method, url, timestamp, duration) and JSON TEXT for payloads; matches `NetworkRecord.toMap()`/`fromMap()` with zero JOIN overhead | ✓ |
| Normalized multi-table relational schema | Separate tables (requests, responses, headers, multiparts) linked by foreign keys; requires JOINs to reconstruct records | |

**User's choice:** Single unified table (`network_records`)  
**Notes:** Network transactions are written and retrieved as cohesive records. Avoiding joins guarantees zero-stutter 60fps listing view performance during fast scrolling.

---

## Indexing Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Composite indexes on query paths | `CREATE INDEX` on `request_timestamp DESC`, `response_status_code`, `method`, `duration_ms`, and `status` to power sub-millisecond `RecordFilter` and `RecordSort` queries | ✓ |
| Minimal indexing | Only index `id` and `request_timestamp`; let other filters scan in memory | |

**User's choice:** Composite indexes on query paths  
**Notes:** Indexes match the `RecordFilter` and `RecordSort` query models directly.

---

## SQLite Pragmas

| Option | Description | Selected |
|--------|-------------|----------|
| `PRAGMA journal_mode = WAL` with `synchronous = NORMAL` | Enables concurrent non-blocking reads during background inserts, preventing UI thread frame drops during API bursts | ✓ |
| Standard DELETE journal mode | Traditional single-connection locking behavior | |

**User's choice:** `PRAGMA journal_mode = WAL` with `synchronous = NORMAL`  
**Notes:** WAL mode eliminates "database is locked" errors when the UI queries records while background writes occur.

---

## Database Migrations

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit versioned migration runner | `version: 1` with an extensible `onUpgrade` map/handler supporting future schema alterations without losing user logs | ✓ |
| Recreate on schema mismatch | Drop and recreate tables if version changes | |

**User's choice:** Explicit versioned migration runner  
**Notes:** Preserves developer logs across package updates.

---

## Write Ingestion Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Debounced batch queue (200ms / 10 items) | Queues writes in memory and flushes in SQLite transactions (`batch.commit(noResult: true)`); eliminates UI thread I/O stalls during parallel API bursts | ✓ |
| Immediate async writes with concurrency lock | Writes each record directly to SQLite on every event | |

**User's choice:** Debounced batch queue (200ms / 10 items)  
**Notes:** Drastically reduces disk write transactions during app startup bursts.

---

## Request-Response Lifecycle Coalescing

| Option | Description | Selected |
|--------|-------------|----------|
| Two-phase write with buffer coalescing | Insert pending row when request starts; update row when response arrives. If request is still in memory buffer, coalesce and update in RAM before writing | ✓ |
| End-of-transaction write only | Only persist to SQLite when response or error completes | |

**User's choice:** Two-phase write with buffer coalescing  
**Notes:** Ensures in-flight requests are immediately observable in UI and preserved even if the app crashes before completion.

---

## Burst Protection

| Option | Description | Selected |
|--------|-------------|----------|
| High-water mark trigger | Automatically trigger immediate asynchronous flush whenever pending buffer queue reaches 20 items | ✓ |
| Fixed interval timer only | Strictly flush on timer tick regardless of queue length | |

**User's choice:** High-water mark trigger (20 items)  
**Notes:** Prevents memory buildup during heavy network bursts.

---

## Lifecycle & Shutdown

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit `flush()` and `dispose()` hooks | Provide async `flush()` and `dispose()` on the repository, allowing facade and lifecycle listeners to flush pending writes before backgrounding or app exit | ✓ |
| Best-effort timer flush only | Rely solely on internal background timers without lifecycle hooks | |

**User's choice:** Explicit `flush()` and `dispose()` hooks  
**Notes:** Guarantees no log loss when the user switches apps or kills the process.

---

## FIFO Prune Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Threshold hysteresis (`maxRecords + 50`) | Only trigger pruning when count exceeds `maxRecords + 50`, then batch delete the oldest 50 records in one query; reduces pruning I/O by 50x | ✓ |
| Strict per-insert pruning | Run prune query immediately on every insert once `maxRecords` is reached | |

**User's choice:** Threshold hysteresis (`maxRecords + 50`)  
**Notes:** Eliminates continuous DELETE statements on every single API request.

---

## FIFO Prune Query

| Option | Description | Selected |
|--------|-------------|----------|
| Single indexed subquery | `DELETE FROM network_records WHERE id NOT IN (SELECT id FROM network_records ORDER BY request_timestamp DESC LIMIT ?);` leverages existing timestamp index | ✓ |
| Two-step query in Dart | SELECT oldest IDs in Dart memory, then execute batch delete with WHERE id IN (...) | |

**User's choice:** Single indexed subquery  
**Notes:** Atomic in SQLite engine and avoids roundtrip data transfer to Dart.

---

## Error Isolation

| Option | Description | Selected |
|--------|-------------|----------|
| Silent background catch | Execute pruning asynchronously; log any database exceptions without interrupting user network operations | ✓ |
| Propagate prune errors | Throw exceptions to caller if pruning fails | |

**User's choice:** Silent background catch  
**Notes:** Storage maintenance must never break or crash application network traffic.

---

## Clear All Action

| Option | Description | Selected |
|--------|-------------|----------|
| `DELETE FROM network_records` with buffer flush | Truncate table rows and clear in-memory buffer, preserving schema structure and open connection | ✓ |
| Drop and recreate table | Drop and recreate table | |

**User's choice:** `DELETE FROM network_records` with buffer flush  
**Notes:** Clean, fast, and does not require closing or re-opening database connections.

---

## Repository Abstraction

| Option | Description | Selected |
|--------|-------------|----------|
| Abstract `NetworkInspectorRepository` interface | Clean interface (`save`, `getRecords`, `getRecordCount`, `clearAll`, `flush`, `dispose`) implemented by `SqliteNetworkInspectorRepository`; decouples UI and interceptors from SQLite | ✓ |
| Concrete SQLite manager class only | Direct sqlite database operations without an abstract interface | |

**User's choice:** Abstract `NetworkInspectorRepository` interface  
**Notes:** Critical for testing and supporting Web/in-memory fallbacks.

---

## Headless Testing Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| `DatabaseFactory` injection | `SqliteNetworkInspectorRepository` accepts optional `DatabaseFactory` and path; unit tests pass `databaseFactoryFfi` with `inMemoryDatabasePath` for real, blazing-fast headless SQL testing | ✓ |
| Mocktail mocking | Mock the SQLite Database and Batch interfaces instead of running against real SQLite | |

**User's choice:** `DatabaseFactory` injection (`sqflite_common_ffi` + `inMemoryDatabasePath`)  
**Notes:** Runs real SQLite schemas, indices, and transactions in headless CI without a device or simulator.

---

## Desktop Support

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-initialize FFI on Desktop | Automatically initialize `sqflite_common_ffi` on Windows/Linux desktop platforms so consumers need zero extra desktop boilerplate | ✓ |
| Require manual desktop setup in host app | Leave FFI setup to consumer app's `main()` | |

**User's choice:** Auto-initialize FFI on Desktop  
**Notes:** Seamless developer experience across all platforms.

---

## Web Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| In-memory repository fallback on Web (`kIsWeb`) | Seamlessly fall back to an in-memory ring-buffer repository on Flutter Web (or when `enableDatabase: false`); zero app crashes | ✓ |
| Throw `UnsupportedError` on Web | Strictly forbid Web execution | |

**User's choice:** In-memory repository fallback on Web (`kIsWeb`)  
**Notes:** Web applications using Dio or package:http will still be able to inspect requests in-memory without crashing.

---

## the agent's Discretion

- Pagination query builder specifics (`WHERE`, `ORDER BY`, `LIMIT`, `OFFSET`).
- In-memory ring-buffer queue data structure.
- Default database file naming (`fl_network_inspector.db`).

## Deferred Ideas

- Full text search using SQLite FTS5 extension (deferred to v1.2.0).
