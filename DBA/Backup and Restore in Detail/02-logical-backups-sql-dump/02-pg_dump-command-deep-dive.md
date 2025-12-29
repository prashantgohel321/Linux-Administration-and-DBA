# 02 pg_dump Command – Deep Dive (PostgreSQL Logical Backup)

<br>
<br>

- [02 pg\_dump Command – Deep Dive (PostgreSQL Logical Backup)](#02-pg_dump-command--deep-dive-postgresql-logical-backup)
  - [In simple words](#in-simple-words)
  - [Important truth about `pg_dump`](#important-truth-about-pg_dump)
  - [Basic `pg_dump` syntax](#basic-pg_dump-syntax)
  - [Connecting to a specific server](#connecting-to-a-specific-server)
  - [Authentication behavior](#authentication-behavior)
  - [Dumping schema only or data only](#dumping-schema-only-or-data-only)
  - [Dumping specific objects](#dumping-specific-objects)
  - [Excluding objects](#excluding-objects)
  - [Dump formats (overview)](#dump-formats-overview)
  - [Why custom and directory formats matter](#why-custom-and-directory-formats-matter)
  - [Compression with `pg_dump`](#compression-with-pg_dump)
  - [Performance impact during dump](#performance-impact-during-dump)
  - [Common `pg_dump` failures](#common-pg_dump-failures)
  - [Best practices for `pg_dump`](#best-practices-for-pg_dump)
  - [When `pg_dump` is the wrong tool](#when-pg_dump-is-the-wrong-tool)
  - [Final mental model](#final-mental-model)
  - [One-line explanation (interview ready)](#one-line-explanation-interview-ready)

<br>
<br>

## In simple words

- `pg_dump` is the tool PostgreSQL provides to take **logical backups** of a single database.
- It reads database objects through SQL and writes instructions that can rebuild the database later.
- It is safe, online, and transaction‑consistent.

---

<br>
<br>

## Important truth about `pg_dump`

- `pg_dump` is **not a server-side tool**.

<br>

- It is a normal client program:
  * it connects like any application
  * it follows role permissions
  * it can run from any machine with network access

- If permissions are wrong, `pg_dump` fails.

---

<br>
<br>

## Basic `pg_dump` syntax

```bash
pg_dump dbname > backup.sql
```

- What happens:
  * `pg_dump` connects to `dbname`
  * takes a snapshot
  * reads schema and data
  * writes SQL into `backup.sql`

- The database stays online.

---

## Connecting to a specific server

```bash
pg_dump -h server_ip -p 5432 -U postgres dbname > backup.sql
```

<br>

- Meaning:
  * `-h` → server hostname or IP
  * `-p` → port (default 5432)
  * `-U` → database role

- This works locally or remotely.

---

<br>
<br>

## Authentication behavior

- `pg_dump` uses the same authentication as any client:
  * password
  * .pgpass
  * environment variables
  * peer or trust (OS‑based)

- There is no special authentication bypass.

---

<br>
<br>

## Dumping schema only or data only

> Schema only:

```bash
pg_dump -s dbname > schema.sql
```

<br>

> Data only:

```bash
pg_dump -a dbname > data.sql
```

<br>

- Useful when:
  * rebuilding structures first
  * loading data separately

---

<br>
<br>

## Dumping specific objects

> Only one table:

```bash
pg_dump -t customers dbname > customers.sql
```

<br>

- Only one schema:

```bash
pg_dump -n public dbname > public_schema.sql
```

> These are common in partial restores and debugging.

---

## Excluding objects

> Exclude a table:

```bash
pg_dump --exclude-table=logs dbname > backup.sql
```

<br>

> Exclude schema:

```bash
pg_dump --exclude-schema=test dbname > backup.sql
```

- Used to skip temporary or irrelevant data.

---

<br>
<br>

## Dump formats (overview)

- `pg_dump` supports multiple formats:
  * `-Fp` → plain SQL (default)
  * `-Fc` → custom (compressed)
  * `-Fd` → directory (parallel)
  * `-Ft` → tar

- Format choice affects restore method and speed.

---

<br>
<br>

## Why custom and directory formats matter

- Custom and directory formats:
  * are compressed
  * restore faster
  * allow selective restore
  * support parallel restore

- Plain SQL does not support parallelism.

---

<br>
<br>

## Compression with `pg_dump`

```bash
pg_dump dbname | gzip > backup.sql.gz
```

- This reduces disk usage but adds CPU cost.
- Custom format has built‑in compression.

---

<br>
<br>

## Performance impact during dump

- `pg_dump`:
  * reads data sequentially
  * uses MVCC snapshots
  * does not block writers

<br>

- But:
  * large dumps consume I/O
  * CPU usage increases

Scheduling matters in production.

---

<br>
<br>

## Common `pg_dump` failures

- `pg_dump` often fails because:
  * role lacks permission on one object
  * view references missing table
  * extension dependency issues
  * network interruptions

- Always read the error message carefully.

---

<br>
<br>

## Best practices for `pg_dump`

* run backups as a dedicated role
* store dumps on separate storage
* monitor dump duration and size
* always test restore

`pg_dump` success is measured at restore time.

---

<br>
<br>

## When `pg_dump` is the wrong tool

- Avoid `pg_dump` when:
  * database is extremely large
  * fast restore is critical
  * point‑in‑time recovery is required

- Physical backups are better in those cases.

---

## Final mental model

* `pg_dump` reads logically
* snapshot guarantees consistency
* permissions decide success
* format decides restore strategy

---

## One-line explanation (interview ready)

`pg_dump` is a PostgreSQL client tool that creates transaction‑consistent logical backups by exporting database objects as SQL instructions.
