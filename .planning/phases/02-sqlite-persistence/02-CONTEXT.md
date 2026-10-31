# Phase 2: SQLite Persistence - Context

**Gathered:** 2026-10-31  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Design, implement, and verify an efficient, indexed local SQLite database persistence engine, automated FIFO pruning system, in-memory write buffer queue, and repository abstraction layer that persists `NetworkRecord` transactions without blocking the Flutter UI isolate, supports sub-millisecond filtering/pagination, and runs headless tests via FFI.

</domain>

<decisions>
## Implementation Decisions

### Schema Design & Table Architecture
- **D-17:** Single unified `network_records` table with dedicated indexed columns for searchable metadata (`id`, `url`, `base_url`, `path`, `method`, `request_content_type`, `request_size`, `request_timestamp`, `response_status_code`, `response_content_type`, `response_size`, `response_timestamp`, `duration_ms`, `status`) and JSON TEXT columns for composite payloads (`request_headers`, `request_query_params`, `request_body`, `response_headers`, `response_body`, `error`, `multipart_entries`), matching `NetworkRecord.toMap()` and `fromMap()` directly with zero JOIN overhead — **Reversibility:** costly — Core database schema and column mappings define downstream queries and UI display.
- **D-18:** Dedicated SQLite B-tree indexes on `request_timestamp DESC`, `response_status_code`, `method`, `duration_ms`, and `status` to ensure sub-millisecond filtering and sorting across thousands of records — **Reversibility:** costly — Affects query plans and SQLite catalog.
- **D-19:** Pragmas `PRAGMA journal_mode = WAL` and `PRAGMA synchronous = NORMAL` configured immediately upon SQLite database open, enabling concurrent non-blocking reads during active writes and eliminating lock contention (`database is locked`) — **Reversibility:** reversible — Database connection configuration.
- **D-20:** Explicit versioned migration architecture with `version: 1` and an extensible `onUpgrade(db, oldVersion, newVersion)` map/pipeline, supporting future schema alterations without wiping user logs — **Reversibility:** costly — Migration contracts govern package version upgrades.

### Buffer Queue & Write Concurrency
- **D-21:** In-memory write buffer queue with 200ms debounce and 10-item batch transactions (`batch.commit(noResult: true)`), isolating the UI isolate from disk I/O latency during rapid API bursts — **Reversibility:** reversible — Internal repository write implementation.
- **D-22:** Two-phase persistence with in-memory buffer coalescing: inserts pending row when request starts, updates existing row by `id` when response or error completes; if the pending request is still queued in the RAM buffer when the response arrives, coalesces into a single completed record before writing to disk — **Reversibility:** costly — Repository write state management and interceptor coordination.
- **D-23:** High-water mark burst protection: automatically triggers immediate asynchronous batch commit whenever the pending in-memory queue reaches 20 items — **Reversibility:** reversible — Buffer configuration parameter.
- **D-24:** Explicit `flush()` and `dispose()` methods on `NetworkInspectorRepository` for clean asynchronous flushing during app lifecycle state transitions (e.g., app pausing or exiting) — **Reversibility:** reversible — Repository lifecycle contract.

### FIFO Pruning Trigger Strategy
- **D-25:** Threshold hysteresis pruning (`maxRecords + 50`, e.g. at 550 records for default `maxRecords = 500`), batch-deleting the oldest 50 records in a single query when the count exceeds `maxRecords + 50`, reducing pruning I/O overhead by 50x compared to per-insert pruning — **Reversibility:** reversible — Pruning trigger algorithm.
- **D-26:** Indexed subquery pruning: `DELETE FROM network_records WHERE id NOT IN (SELECT id FROM network_records ORDER BY request_timestamp DESC LIMIT ?);` leveraging the B-tree index on `request_timestamp DESC` — **Reversibility:** reversible — SQL query optimization.
- **D-27:** Asynchronous error-isolated maintenance: pruning executes as a background maintenance task wrapped in try-catch to ensure background database maintenance never impacts application network requests — **Reversibility:** reversible.
- **D-28:** Developer "Clear All" action (UI-06): executes `DELETE FROM network_records;` and flushes in-memory write buffer queues, preserving the database schema, open connection, and active indexes — **Reversibility:** reversible.

### Platform & Headless Testing Architecture
- **D-29:** Abstract `NetworkInspectorRepository` interface defining `save`, `saveBatch`, `getById`, `getRecords` (with `RecordFilter` and `RecordSort` pagination), `getRecordCount`, `clearAll`, `flush`, and `dispose`, implemented by `SqliteNetworkInspectorRepository` and `InMemoryNetworkInspectorRepository` — **Reversibility:** costly — Public repository abstraction for interceptors and UI.
- **D-30:** `DatabaseFactory` and database path injection in `SqliteNetworkInspectorRepository`, enabling headless unit/widget tests to run against real in-memory SQLite (`inMemoryDatabasePath` + `databaseFactoryFfi`) in CI without needing native mobile platform channels — **Reversibility:** costly — Repository constructor dependency injection.
- **D-31:** Automatic desktop FFI initialization (`sqfliteFfiInit()` and `databaseFactory = databaseFactoryFfi`) on Windows and Linux desktop platforms, requiring zero extra boilerplate in consumer application `main()` — **Reversibility:** reversible.
- **D-32:** Graceful fallback to `InMemoryNetworkInspectorRepository` on Flutter Web (`kIsWeb`) or when `enableDatabase: false` (per D-04), providing in-memory ring-buffer inspection without crashes — **Reversibility:** reversible.

### the agent's Discretion
- Batch commit transaction timeouts and error retry heuristics.
- Implementation details of pagination query SQL generator (`WHERE`, `ORDER BY`, `LIMIT`, `OFFSET`).
- In-memory ring-buffer queue data structure for Web fallback.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Specifications & Guidelines
- `.planning/PROJECT.md` — Project core value, constraints, and architecture.
- `.planning/REQUIREMENTS.md` § Local SQLite Database Architecture (`DB-01` through `DB-06`).
- `.planning/research/STACK.md` § Core Technologies (`sqflite: ^2.4.5`, `sqflite_common_ffi: ^2.4.5`, `path: ^1.9.1`).
- `.planning/research/ARCHITECTURE.md` § Layer 2: Persistence & Storage Engine.
- `.planning/research/PITFALLS.md` § Pitfall 1 (UI thread blocking during SQLite batch writes) & Pitfall 2 (Unbounded database growth and FIFO pruning).
- `.planning/phases/01-foundation-models/01-CONTEXT.md` — Phase 1 locked decisions (`D-01` through `D-16`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkRecord` (`lib/src/models/network_record.dart`): Already provides `toMap()` with snake_case keys and `fromMap()` capable of parsing stringified JSON columns from SQLite.
- `RecordFilter` (`lib/src/models/record_filter.dart`): Models search query, HTTP methods, status codes, duration bounds, and date ranges.
- `RecordSort` (`lib/src/models/record_sort.dart`): Models sort field (`timestamp`, `duration`, `statusCode`, `url`, `size`) and sort order.
- `NetworkInspectorConfig` (`lib/src/config/network_inspector_config.dart`): Exposes `maxRecords` (default 500) and `enableDatabase`.
- `NetworkInspector` facade (`lib/src/core/network_inspector.dart`): Central singleton entry point to wire repository access.

### Established Patterns
- Pure handwritten Dart 3 classes with immutable value semantics and zero `build_runner` dependencies.
- Defensive error isolation: background maintenance operations must never throw into consumer network flows.

### Integration Points
- `SqliteNetworkInspectorRepository` implements `NetworkInspectorRepository`.
- `NetworkInspector.initialize()` initializes the repository when `enableDatabase` is true.
- Interceptors (Phase 3) call `repository.save()` during request and response handling.
- UI listing screen (Phase 4) calls `repository.getRecords(filter: ..., sort: ..., limit: ..., offset: ...)`.

</code_context>

<specifics>
## Specific Ideas

- Use `batch.commit(noResult: true)` for maximum write throughput during high-traffic bursts.
- Ensure `getRecordCount()` uses `SELECT COUNT(*) FROM network_records` with identical `WHERE` clauses as `getRecords()` for accurate pagination metadata.

</specifics>

<deferred>
## Deferred Ideas

- Full text search using SQLite FTS5 extension (deferred to v1.2.0 if LIKE substring search proves insufficient for extreme body sizes).

</deferred>

---

*Phase: 2-SQLite Persistence*  
*Context gathered: 2026-10-31*
