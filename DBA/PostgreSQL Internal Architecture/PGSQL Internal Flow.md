# PostgreSQL Internal Flow — End-to-End Story (Single Example)

This file explains the entire PostgreSQL internal architecture in one continuous flow, using a simple example query, and connecting every component: client → backend process → parsing → planning → shared buffers → WAL → background processes → MVCC → locks → checkpoint → archiver → autovacuum → stats.

Example we will follow throughout:

```sql
UPDATE accounts SET balance = balance - 100 WHERE id = 10;
```

---

## Client Connects → Backend Spawns

When our application connects to PostgreSQL, the Postmaster creates a **backend process** dedicated to that session. This backend will handle everything for this user: authentication, SQL execution, memory usage, locks, WAL, and communication.

Diagram:

```
Client → Postmaster → Backend process (per session)
```

---

## SQL Enters → Parsing + Rewriting

The backend receives the SQL as plain text.
It must first check: is this valid SQL? Are the table and column names correct? If views are involved, PostgreSQL rewrites them into real table references.

Flow:

```bash
SQL Text → Parser → Validator → Rewriter → Query Tree
```

---

## Planning Phase → Statistics + Index Decision

Next, PostgreSQL decides the best way to run this query. It checks statistics gathered earlier by the **stats collector**: table size, index usage, row counts, activity history.

Based on this info, PostgreSQL may pick:

```bash
Index Scan on accounts.id
```

This planning step only happens once per query execution; it produces the final execution plan.

Diagram:

```bash
Stats Collector → Statistics → Planner → Execution Plan
```

---

## Execution Starts → Shared Buffers + MVCC Versioning

The backend now executes the plan:

* It looks for the required data page inside **shared buffers**.
* If it is not there, PostgreSQL reads the page from disk and inserts it into shared buffers.
* MVCC rules ensure correct visibility.

When the UPDATE occurs, PostgreSQL **does not overwrite the old row**. It creates a new version with balance reduced by 100. The previous version stays visible to other sessions based on their snapshots.

Diagram:

```bash
shared_buffers (read/write cache)
Old row → dead
New row → live
```

---

## Locks Engage → Row Lock

To avoid two writers updating same row simultaneously, PostgreSQL applies a **row-level lock**. Readers do not block because MVCC lets them see historical versions.

Flow:

```bash
UPDATE → Row lock → Modify page in memory
```

---

## WAL Creation → WAL Buffers → Durability

Before the database can commit this change, PostgreSQL writes the redo record into **wal_buffers**:

* operation type
* table id
* block number
* old/new version details

This WAL record exists only in memory for now.

Diagram:

```bash
Row change → WAL record → wal_buffers
```

---

## COMMIT → WAL Writer Flushes to Disk

When the user issues COMMIT:

* WAL writer flushes WAL buffers to WAL files on disk.
* Only after WAL hits disk is the transaction officially committed.
* The updated data page still remains in **shared buffers**, dirty and not yet written to table files.

Flow:

```bash
COMMIT → WAL writer → WAL file on disk → Success returned
```

---

## Background Writer → Slow Page Flushing

Dirty pages remain in shared buffers until either:

* background writer slowly flushes them, or
* memory needs space.

This prevents backend processes from being forced to write pages directly.

Diagram:

```bash
Dirty page → background writer → table file
```

---

## Checkpointer → Recovery Safe Point

Checkpointer occasionally forces dirty pages to disk and inserts a checkpoint record into WAL so PostgreSQL knows: "Recovery starts from here."

Trigger cases:

* time interval
* WAL size growth
* manual CHECKPOINT

Flow:

```bash
All dirty pages → flushed
WAL checkpoint record → created
```

---

## Archiver → Long-term WAL Storage (If Enabled)

If archive_mode = on, finished WAL segments are copied out by the **archiver** to external storage for:

* PITR
* standby setups
* disaster recovery

Flow:

```
Completed WAL segment → Archiver → Archive directory
```

---

## Autovacuum → MVCC Cleanup

Because MVCC keeps old versions, dead tuples accumulate. Autovacuum workers remove dead rows, update statistics, and control table bloat to maintain long-term performance.

Flow:

```bash
Dead tuples → Autovacuum → Space reclaimed
```

---

## Stats Collector → Future Planning Support

Each execution updates usage stats:

* table scans
* tuple counts
* index hits
* query time

Planner uses these stats later to make faster decisions.

Flow:

```bash
Execution info → Stats collector → Planner feedback
```

---

## Final Continuous Flow Diagram

```bash
Client
 │
 ▼
Backend (Per connection)
 │
 ▼
Parse → Rewrite → Plan
 │
 ▼
Stats → Execution Plan
 │
 ▼
Shared Buffers (modify data)
 │        │
 │        └─ Locks + MVCC for safe concurrency
 │
 ▼
WAL Buffers → WAL Writer → WAL Files (Commit durability)
 │
 ▼
Shared Buffers hold dirty pages
 │
 ├→ Background Writer (slow flushing)
 └→ Checkpointer (force flush + WAL checkpoint)

Archiver (if enabled) → save WAL segments for PITR
Autovacuum → remove dead tuples, control bloat
Stats Collector → improve future planning
```

---

# One Human Sentence Summary

> PostgreSQL takes SQL from clients, parses it, plans it, executes it inside shared buffers using MVCC and locks, logs it in WAL for safety, commits through WAL writer, flushes data pages later with background writer and checkpointer, archives WAL for recovery, and constantly cleans and tunes itself through aut
