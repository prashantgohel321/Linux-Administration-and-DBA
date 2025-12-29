# 08 Post‑Restore Tasks: ANALYZE, VACUUM, and Verification

<br>
<br>

- [08 Post‑Restore Tasks: ANALYZE, VACUUM, and Verification](#08-postrestore-tasks-analyze-vacuum-and-verification)
  - [In simple words](#in-simple-words)
  - [Why performance is bad after restore](#why-performance-is-bad-after-restore)
  - [`ANALYZE` (most important step)](#analyze-most-important-step)
    - [What `ANALYZE` does](#what-analyze-does)
    - [When I run it](#when-i-run-it)
  - [`VACUUM` after restore](#vacuum-after-restore)
    - [What `VACUUM` does](#what-vacuum-does)
  - [Why VACUUM FULL is dangerous](#why-vacuum-full-is-dangerous)
  - [Refreshing sequence values](#refreshing-sequence-values)
  - [Validating data correctness](#validating-data-correctness)
  - [Checking application connectivity](#checking-application-connectivity)
  - [Autovacuum considerations](#autovacuum-considerations)
  - [Logging and monitoring](#logging-and-monitoring)
  - [Common DBA mistake](#common-dba-mistake)
  - [Final mental model](#final-mental-model)
  - [One‑line explanation](#oneline-explanation)

<br>
<br>


## In simple words

After a restore, the database *looks* fine but it usually **does not perform fine**.

Post‑restore tasks exist to:

* fix planner statistics
* clean internal states
* verify data correctness
* make the database production‑ready

Restore without post‑restore work is incomplete.

---

<br>
<br>

## Why performance is bad after restore

During logical restore:
* data is inserted in bulk
* indexes are rebuilt
* planner statistics are **empty or outdated**

- Without fresh statistics, PostgreSQL guesses wrong plans.
- That is why queries feel slow even though data is present.

---

<br>
<br>

## `ANALYZE` (most important step)

### What `ANALYZE` does

`ANALYZE` scans tables and builds statistics about:
* row counts
* data distribution
* column selectivity

The query planner depends on these stats to choose indexes.

<br>
<br>

### When I run it

Immediately after restore.

```bash
ANALYZE;

# This command tells PostgreSQL to scan the tables and update statistics about the data. These statistics help the query planner choose better and faster execution plans for future queries.
```

For large systems, this single command fixes most post‑restore issues.

---

<br>
<br>

## `VACUUM` after restore

### What `VACUUM` does

* cleans dead tuples
* updates visibility map (*The visibility map is an internal PostgreSQL structure that tracks which data pages contain only visible rows. It helps PostgreSQL skip unnecessary table scans during VACUUM and SELECT queries, making reads faster and reducing extra work.*)
* helps index‑only scans

After a fresh restore, heavy `VACUUM` is usually **not required**, <br>
but a light `vacuum` helps internal bookkeeping.

```bash
VACUUM;

# This command cleans up dead rows left behind by updates and deletes, freeing space and keeping the database healthy. It also helps PostgreSQL maintain good performance by preventing tables from becoming bloated.
```

Do **not** run aggressive `VACUUM FULL` right after restore.

---

<br>
<br>

## Why VACUUM FULL is dangerous

```bash
VACUUM FULL;

# This command completely rewrites the table to remove dead rows and reclaim disk space back to the operating system. It locks the table while running, so it’s used only when space recovery is more important than availability.

```

* locks tables
* rewrites data
* blocks concurrent access

After restore, it usually adds risk without benefit. <br>
Use it only when space reclaim is required.

---

<br>
<br>

## Refreshing sequence values

After restore, sequences may become out of sync.

Check:

```sql
SELECT last_value FROM my_table_id_seq;
```

<br>

Fix if needed:

```sql
SELECT setval('my_table_id_seq', MAX(id)) FROM my_table;
```

This prevents duplicate key errors.

<br>

- After a restore, sequence values can be out of sync with table data.
- The first query checks the current sequence value, and the second one resets the sequence to the highest `id` present in the table, so future inserts don’t fail with duplicate key errors.


---

<br>
<br>

## Validating data correctness

I always verify:
* table row counts
* critical business tables
* foreign key integrity

<br>

Example:

```sql
SELECT count(*) FROM important_table;
```

Never assume restore was perfect.

---

<br>
<br>

## Checking application connectivity

Before declaring success:
* connect application users
* run basic queries
* confirm permissions

Restore is successful only if applications work.

---

<br>
<br>

## Autovacuum considerations

Autovacuum may:
* start running after restore
* consume I/O unexpectedly

<br>

In large restores:
* monitor autovacuum
* avoid tuning changes immediately

Let the system stabilize first.

---

<br>
<br>

## Logging and monitoring

After restore, I check:
* PostgreSQL logs
* error messages
* slow queries

Hidden issues appear only in logs.

---

<br>
<br>

## Common DBA mistake

Declaring restore complete after SQL finishes.

Correct mindset:

> Restore ends only after performance and correctness are verified.

---

<br>
<br>

## Final mental model

* Restore builds data
* ANALYZE builds intelligence
* VACUUM maintains health
* Verification builds confidence

---

<br>
<br>

## One‑line explanation

After restore, a DBA must run ANALYZE, verify data, and check system health to ensure correct performance and consistency.
