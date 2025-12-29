<center>

# 01 What a SQL Dump Is and How It Works Internally in PostgreSQL
</center>

<br>
<br>

- [01 What a SQL Dump Is and How It Works Internally in PostgreSQL](#01-what-a-sql-dump-is-and-how-it-works-internally-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why SQL dumps exist](#why-sql-dumps-exist)
  - [Tool used: `pg_dump`](#tool-used-pg_dump)
  - [What `pg_dump` actually reads](#what-pg_dump-actually-reads)
  - [How `pg_dump` works internally (step-by-step)](#how-pg_dump-works-internally-step-by-step)
  - [Why `pg_dump` does not block users](#why-pg_dump-does-not-block-users)
  - [What consistency means in a SQL dump](#what-consistency-means-in-a-sql-dump)
  - [What a SQL dump contains](#what-a-sql-dump-contains)
  - [What a SQL dump does NOT contain](#what-a-sql-dump-does-not-contain)
  - [Why SQL dumps are slow for large databases](#why-sql-dumps-are-slow-for-large-databases)
  - [Restore behavior of SQL dumps](#restore-behavior-of-sql-dumps)
  - [When I prefer SQL dumps](#when-i-prefer-sql-dumps)
  - [Common misunderstanding](#common-misunderstanding)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)
- [02 pg\_dump Command – Deep Dive (PostgreSQL Logical Backup)](#02-pg_dump-command--deep-dive-postgresql-logical-backup)
  - [In simple words](#in-simple-words-1)
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
  - [Final mental model](#final-mental-model-1)
  - [One-line explanation](#one-line-explanation-1)
- [03 Restore Using psql – Complete Flow (PostgreSQL Logical Restore)](#03-restore-using-psql--complete-flow-postgresql-logical-restore)
  - [In simple words](#in-simple-words-2)
  - [What restore actually does](#what-restore-actually-does)
  - [Pre-restore checklist (very important)](#pre-restore-checklist-very-important)
  - [Step 1: Create an empty database](#step-1-create-an-empty-database)
  - [Step 2: Restore using `psql`](#step-2-restore-using-psql)
  - [Restore directly from compressed dump](#restore-directly-from-compressed-dump)
  - [Restore from a remote server](#restore-from-a-remote-server)
  - [Common restore errors and causes](#common-restore-errors-and-causes)
    - [Role does not exist](#role-does-not-exist)
    - [Permission denied](#permission-denied)
    - [Object already exists](#object-already-exists)
  - [Useful restore options](#useful-restore-options)
  - [Post-restore tasks (often forgotten)](#post-restore-tasks-often-forgotten)
  - [Why restore takes time](#why-restore-takes-time)
  - [When `psql` restore is the right choice](#when-psql-restore-is-the-right-choice)
  - [Common DBA mistake](#common-dba-mistake)
  - [Final mental model](#final-mental-model-2)
  - [One-line explanation](#one-line-explanation-2)
- [04 `pg_restore` and Selective Restore in PostgreSQL](#04-pg_restore-and-selective-restore-in-postgresql)
  - [In simple words](#in-simple-words-3)
  - [Why `pg_restore` exists](#why-pg_restore-exists)
  - [How `pg_restore` works internally](#how-pg_restore-works-internally)
  - [Basic `pg_restore` syntax](#basic-pg_restore-syntax)
  - [Creating a compatible dump for `pg_restore`](#creating-a-compatible-dump-for-pg_restore)
  - [Listing dump contents (very important)](#listing-dump-contents-very-important)
  - [Restoring specific objects](#restoring-specific-objects)
  - [Excluding objects during restore](#excluding-objects-during-restore)
  - [Restoring schema and data separately](#restoring-schema-and-data-separately)
  - [Parallel restore (big performance boost)](#parallel-restore-big-performance-boost)
  - [Handling ownership and permissions](#handling-ownership-and-permissions)
  - [Common `pg_restore` failures](#common-pg_restore-failures)
  - [When `pg_restore` is the right tool](#when-pg_restore-is-the-right-tool)
  - [When `pg_restore` is NOT useful](#when-pg_restore-is-not-useful)
  - [Final mental model](#final-mental-model-3)
  - [One-line explanation](#one-line-explanation-3)
- [05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)](#05-postgresql-dump-formats--fp--fc--fd--ft-explainable-guide)
  - [In simple words](#in-simple-words-4)
  - [Overview of available dump formats](#overview-of-available-dump-formats)
  - [Plain format (`-Fp`)](#plain-format--fp)
    - [What it is](#what-it-is)
    - [Characteristics](#characteristics)
    - [Pros](#pros)
    - [Cons](#cons)
    - [When I use it](#when-i-use-it)
  - [Custom format (`-Fc`)](#custom-format--fc)
    - [What it is](#what-it-is-1)
    - [Characteristics](#characteristics-1)
    - [Pros](#pros-1)
    - [Cons](#cons-1)
    - [When I use it](#when-i-use-it-1)
  - [Directory format (`-Fd`)](#directory-format--fd)
    - [What it is](#what-it-is-2)
    - [Characteristics](#characteristics-2)
    - [Pros](#pros-2)
    - [Cons](#cons-2)
    - [When I use it](#when-i-use-it-2)
  - [Tar format (`-Ft`)](#tar-format--ft)
    - [What it is](#what-it-is-3)
    - [Characteristics](#characteristics-3)
    - [Pros](#pros-3)
    - [Cons](#cons-3)
    - [When I use it](#when-i-use-it-3)
  - [Restore tool comparison](#restore-tool-comparison)
  - [Performance reality](#performance-reality)
  - [DBA recommendation (real world)](#dba-recommendation-real-world)
  - [Common mistakes to avoid](#common-mistakes-to-avoid)
  - [Final mental model](#final-mental-model-4)
  - [One‑line explanation](#oneline-explanation)
- [06 Streaming Backups Between Servers in PostgreSQL](#06-streaming-backups-between-servers-in-postgresql)
  - [In simple words](#in-simple-words-5)
  - [Why streaming backups exist](#why-streaming-backups-exist)
  - [Most common streaming pattern](#most-common-streaming-pattern)
  - [Streaming between two different servers](#streaming-between-two-different-servers)
  - [Why this works safely](#why-this-works-safely)
  - [When streaming is a good choice](#when-streaming-is-a-good-choice)
  - [Limitations of streaming backups](#limitations-of-streaming-backups)
  - [Streaming with compression](#streaming-with-compression)
  - [Handling errors during streaming](#handling-errors-during-streaming)
  - [Streaming vs file-based backups](#streaming-vs-file-based-backups)
  - [DBA checklist before streaming](#dba-checklist-before-streaming)
  - [Final mental model](#final-mental-model-5)
  - [One-line explanation](#one-line-explanation-4)
- [07 pg\_dumpall and Cluster-Level Backups in PostgreSQL](#07-pg_dumpall-and-cluster-level-backups-in-postgresql)
  - [In simple words](#in-simple-words-6)
  - [Why `pg_dumpall` exists](#why-pg_dumpall-exists)
  - [What `pg_dumpall` actually backs up](#what-pg_dumpall-actually-backs-up)
  - [How `pg_dumpall` works internally](#how-pg_dumpall-works-internally)
  - [Basic `pg_dumpall` usage](#basic-pg_dumpall-usage)
  - [Role requirements (very important)](#role-requirements-very-important)
  - [Restoring from `pg_dumpall`](#restoring-from-pg_dumpall)
  - [Common `pg_dumpall` problems](#common-pg_dumpall-problems)
  - [`pg_dumpall` vs `pg_dump` (real difference)](#pg_dumpall-vs-pg_dump-real-difference)
  - [When I actually use `pg_dumpall`](#when-i-actually-use-pg_dumpall)
  - [Best practice (important)](#best-practice-important)
  - [Security warning](#security-warning)
  - [Final mental model](#final-mental-model-6)
  - [One-line explanation](#one-line-explanation-5)
- [08 Post‑Restore Tasks: ANALYZE, VACUUM, and Verification](#08-postrestore-tasks-analyze-vacuum-and-verification)
  - [In simple words](#in-simple-words-7)
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
  - [Common DBA mistake](#common-dba-mistake-1)
  - [Final mental model](#final-mental-model-7)
  - [One‑line explanation](#oneline-explanation-1)
- [09 Common SQL Dump Mistakes and Failure Scenarios in PostgreSQL](#09-common-sql-dump-mistakes-and-failure-scenarios-in-postgresql)
  - [In simple words](#in-simple-words-8)
  - [Mistake 1: Assuming backup success means restore success](#mistake-1-assuming-backup-success-means-restore-success)
  - [Mistake 2: Not checking permissions before `pg_dump`](#mistake-2-not-checking-permissions-before-pg_dump)
  - [Mistake 3: Using plain SQL for very large databases](#mistake-3-using-plain-sql-for-very-large-databases)
  - [Mistake 4: Forgetting roles and global objects](#mistake-4-forgetting-roles-and-global-objects)
  - [Mistake 5: Restoring into a dirty database](#mistake-5-restoring-into-a-dirty-database)
  - [Mistake 6: Ignoring restore errors](#mistake-6-ignoring-restore-errors)
  - [Mistake 7: Skipping post-restore steps](#mistake-7-skipping-post-restore-steps)
  - [Mistake 8: Backups stored on same server](#mistake-8-backups-stored-on-same-server)
  - [Mistake 9: No monitoring of backup jobs](#mistake-9-no-monitoring-of-backup-jobs)
  - [Mistake 10: Never testing restore under pressure](#mistake-10-never-testing-restore-under-pressure)
  - [Final mental model](#final-mental-model-8)
  - [One-line explanation](#one-line-explanation-6)


<br>
<br>

## In simple words

- A SQL dump is a logical backup where PostgreSQL writes **SQL commands** that can rebuild the database later.

<br>

- **Think of it as instructions to recreate:**
  * database structure
  * data
  * permissions

> When I restore a SQL dump, PostgreSQL simply **replays those instructions**.

---

<br>
<br>

## Why SQL dumps exist

- SQL dumps solve portability and flexibility problems.

<br>

- **They are designed for:**
  * database migrations
  * PostgreSQL version upgrades
  * moving data across servers
  * partial restores (tables or schemas)

> They are not the fastest, but they are the most flexible.

---

<br>
<br>

## Tool used: `pg_dump`

- `pg_dump` is the standard tool used to create SQL dumps.

<br>

- **Important truth:**
  -  `pg_dump` is just a normal PostgreSQL client.
  - It connects to the database like any other application and follows all role permissions.

---

<br>
<br>

## What `pg_dump` actually reads

- `pg_dump` reads the database **logically**, not physically.

<br>

- **It reads:**
  * schemas
  * tables
  * indexes
  * sequences
  * views
  * functions
  * data

- It does not copy disk files. It reads data through SQL queries.

---

<br>
<br>

## How `pg_dump` works internally (step-by-step)

1. `pg_dump` connects to the database
2. PGSQL creates a transaction snapshot
3. `pg_dump` reads metadata (tables, schemas, objects)
4. `pg_dump` reads table data row by row
5. SQL commands are written to the dump file

> The snapshot guarantees consistency across all objects.

---

<br>
<br>

## Why `pg_dump` does not block users

- `pg_dump` uses a snapshot-based read.

<br>

- This means:
  * no exclusive locks
  * no write blocking
  * normal queries continue

> Users can keep inserting and updating data while the dump runs.

---

<br>
<br>

## What consistency means in a SQL dump

- All tables in the dump represent the **same point in time**.

<br>

- Data committed after the dump starts is ignored.
- Uncommitted data is never included.

<br>

- This prevents broken foreign keys or partial data.

---

<br>
<br>

## What a SQL dump contains

- **A SQL dump usually includes:**
  * CREATE DATABASE (optional)
  * CREATE TABLE statements
  * CREATE INDEX statements
  * INSERT data
  * GRANT and ownership statements

- It may also include comments and extensions if requested.

---

<br>
<br>

## What a SQL dump does NOT contain

- **SQL dumps do not include:**
  * server configuration files
  * running transactions
  * OS-level settings
  * WAL history

- They only capture logical database objects.

---

<br>
<br>

## Why SQL dumps are slow for large databases

- **SQL dumps:**
  * write data as INSERT statements
  * rebuild indexes during restore
  * execute commands one by one

- This makes them slower for very large databases compared to physical backups.

---

<br>
<br>

## Restore behavior of SQL dumps

- **Restore means:**
  * create a clean database
  * run the SQL file using psql
  * PostgreSQL executes commands sequentially

- Indexes are rebuilt, not copied.
- Statistics must be regenerated after restore.

---
<br>
<br>

## When I prefer SQL dumps

- I use SQL dumps when:
  * upgrading PostgreSQL versions
  * migrating between platforms
  * restoring individual tables
  * creating test or dev environments

- They give control, not speed.

---

<br>
<br>

## Common misunderstanding

- A SQL dump is not a snapshot of disk files.

<br>

- It is a **logical reconstruction recipe**.
- That is why it works across versions and architectures.

---

<br>
<br>

## Final mental model

* SQL dump = instructions
* `pg_dump` = reader and writer
* snapshot = consistency guarantee
* restore = replay SQL

---

## One-line explanation 

A SQL dump is a logical backup that stores SQL commands generated from a consistent snapshot to recreate a PostgreSQL database.


<br>
<br>
<br>
<br>

<center>

# 02 pg_dump Command – Deep Dive (PostgreSQL Logical Backup)
</center>

<br>
<br>

- [01 What a SQL Dump Is and How It Works Internally in PostgreSQL](#01-what-a-sql-dump-is-and-how-it-works-internally-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why SQL dumps exist](#why-sql-dumps-exist)
  - [Tool used: `pg_dump`](#tool-used-pg_dump)
  - [What `pg_dump` actually reads](#what-pg_dump-actually-reads)
  - [How `pg_dump` works internally (step-by-step)](#how-pg_dump-works-internally-step-by-step)
  - [Why `pg_dump` does not block users](#why-pg_dump-does-not-block-users)
  - [What consistency means in a SQL dump](#what-consistency-means-in-a-sql-dump)
  - [What a SQL dump contains](#what-a-sql-dump-contains)
  - [What a SQL dump does NOT contain](#what-a-sql-dump-does-not-contain)
  - [Why SQL dumps are slow for large databases](#why-sql-dumps-are-slow-for-large-databases)
  - [Restore behavior of SQL dumps](#restore-behavior-of-sql-dumps)
  - [When I prefer SQL dumps](#when-i-prefer-sql-dumps)
  - [Common misunderstanding](#common-misunderstanding)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)
- [02 pg\_dump Command – Deep Dive (PostgreSQL Logical Backup)](#02-pg_dump-command--deep-dive-postgresql-logical-backup)
  - [In simple words](#in-simple-words-1)
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
  - [Final mental model](#final-mental-model-1)
  - [One-line explanation](#one-line-explanation-1)
- [03 Restore Using psql – Complete Flow (PostgreSQL Logical Restore)](#03-restore-using-psql--complete-flow-postgresql-logical-restore)
  - [In simple words](#in-simple-words-2)
  - [What restore actually does](#what-restore-actually-does)
  - [Pre-restore checklist (very important)](#pre-restore-checklist-very-important)
  - [Step 1: Create an empty database](#step-1-create-an-empty-database)
  - [Step 2: Restore using `psql`](#step-2-restore-using-psql)
  - [Restore directly from compressed dump](#restore-directly-from-compressed-dump)
  - [Restore from a remote server](#restore-from-a-remote-server)
  - [Common restore errors and causes](#common-restore-errors-and-causes)
    - [Role does not exist](#role-does-not-exist)
    - [Permission denied](#permission-denied)
    - [Object already exists](#object-already-exists)
  - [Useful restore options](#useful-restore-options)
  - [Post-restore tasks (often forgotten)](#post-restore-tasks-often-forgotten)
  - [Why restore takes time](#why-restore-takes-time)
  - [When `psql` restore is the right choice](#when-psql-restore-is-the-right-choice)
  - [Common DBA mistake](#common-dba-mistake)
  - [Final mental model](#final-mental-model-2)
  - [One-line explanation](#one-line-explanation-2)
- [04 `pg_restore` and Selective Restore in PostgreSQL](#04-pg_restore-and-selective-restore-in-postgresql)
  - [In simple words](#in-simple-words-3)
  - [Why `pg_restore` exists](#why-pg_restore-exists)
  - [How `pg_restore` works internally](#how-pg_restore-works-internally)
  - [Basic `pg_restore` syntax](#basic-pg_restore-syntax)
  - [Creating a compatible dump for `pg_restore`](#creating-a-compatible-dump-for-pg_restore)
  - [Listing dump contents (very important)](#listing-dump-contents-very-important)
  - [Restoring specific objects](#restoring-specific-objects)
  - [Excluding objects during restore](#excluding-objects-during-restore)
  - [Restoring schema and data separately](#restoring-schema-and-data-separately)
  - [Parallel restore (big performance boost)](#parallel-restore-big-performance-boost)
  - [Handling ownership and permissions](#handling-ownership-and-permissions)
  - [Common `pg_restore` failures](#common-pg_restore-failures)
  - [When `pg_restore` is the right tool](#when-pg_restore-is-the-right-tool)
  - [When `pg_restore` is NOT useful](#when-pg_restore-is-not-useful)
  - [Final mental model](#final-mental-model-3)
  - [One-line explanation](#one-line-explanation-3)
- [05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)](#05-postgresql-dump-formats--fp--fc--fd--ft-explainable-guide)
  - [In simple words](#in-simple-words-4)
  - [Overview of available dump formats](#overview-of-available-dump-formats)
  - [Plain format (`-Fp`)](#plain-format--fp)
    - [What it is](#what-it-is)
    - [Characteristics](#characteristics)
    - [Pros](#pros)
    - [Cons](#cons)
    - [When I use it](#when-i-use-it)
  - [Custom format (`-Fc`)](#custom-format--fc)
    - [What it is](#what-it-is-1)
    - [Characteristics](#characteristics-1)
    - [Pros](#pros-1)
    - [Cons](#cons-1)
    - [When I use it](#when-i-use-it-1)
  - [Directory format (`-Fd`)](#directory-format--fd)
    - [What it is](#what-it-is-2)
    - [Characteristics](#characteristics-2)
    - [Pros](#pros-2)
    - [Cons](#cons-2)
    - [When I use it](#when-i-use-it-2)
  - [Tar format (`-Ft`)](#tar-format--ft)
    - [What it is](#what-it-is-3)
    - [Characteristics](#characteristics-3)
    - [Pros](#pros-3)
    - [Cons](#cons-3)
    - [When I use it](#when-i-use-it-3)
  - [Restore tool comparison](#restore-tool-comparison)
  - [Performance reality](#performance-reality)
  - [DBA recommendation (real world)](#dba-recommendation-real-world)
  - [Common mistakes to avoid](#common-mistakes-to-avoid)
  - [Final mental model](#final-mental-model-4)
  - [One‑line explanation](#oneline-explanation)
- [06 Streaming Backups Between Servers in PostgreSQL](#06-streaming-backups-between-servers-in-postgresql)
  - [In simple words](#in-simple-words-5)
  - [Why streaming backups exist](#why-streaming-backups-exist)
  - [Most common streaming pattern](#most-common-streaming-pattern)
  - [Streaming between two different servers](#streaming-between-two-different-servers)
  - [Why this works safely](#why-this-works-safely)
  - [When streaming is a good choice](#when-streaming-is-a-good-choice)
  - [Limitations of streaming backups](#limitations-of-streaming-backups)
  - [Streaming with compression](#streaming-with-compression)
  - [Handling errors during streaming](#handling-errors-during-streaming)
  - [Streaming vs file-based backups](#streaming-vs-file-based-backups)
  - [DBA checklist before streaming](#dba-checklist-before-streaming)
  - [Final mental model](#final-mental-model-5)
  - [One-line explanation](#one-line-explanation-4)
- [07 pg\_dumpall and Cluster-Level Backups in PostgreSQL](#07-pg_dumpall-and-cluster-level-backups-in-postgresql)
  - [In simple words](#in-simple-words-6)
  - [Why `pg_dumpall` exists](#why-pg_dumpall-exists)
  - [What `pg_dumpall` actually backs up](#what-pg_dumpall-actually-backs-up)
  - [How `pg_dumpall` works internally](#how-pg_dumpall-works-internally)
  - [Basic `pg_dumpall` usage](#basic-pg_dumpall-usage)
  - [Role requirements (very important)](#role-requirements-very-important)
  - [Restoring from `pg_dumpall`](#restoring-from-pg_dumpall)
  - [Common `pg_dumpall` problems](#common-pg_dumpall-problems)
  - [`pg_dumpall` vs `pg_dump` (real difference)](#pg_dumpall-vs-pg_dump-real-difference)
  - [When I actually use `pg_dumpall`](#when-i-actually-use-pg_dumpall)
  - [Best practice (important)](#best-practice-important)
  - [Security warning](#security-warning)
  - [Final mental model](#final-mental-model-6)
  - [One-line explanation](#one-line-explanation-5)
- [08 Post‑Restore Tasks: ANALYZE, VACUUM, and Verification](#08-postrestore-tasks-analyze-vacuum-and-verification)
  - [In simple words](#in-simple-words-7)
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
  - [Common DBA mistake](#common-dba-mistake-1)
  - [Final mental model](#final-mental-model-7)
  - [One‑line explanation](#oneline-explanation-1)
- [09 Common SQL Dump Mistakes and Failure Scenarios in PostgreSQL](#09-common-sql-dump-mistakes-and-failure-scenarios-in-postgresql)
  - [In simple words](#in-simple-words-8)
  - [Mistake 1: Assuming backup success means restore success](#mistake-1-assuming-backup-success-means-restore-success)
  - [Mistake 2: Not checking permissions before `pg_dump`](#mistake-2-not-checking-permissions-before-pg_dump)
  - [Mistake 3: Using plain SQL for very large databases](#mistake-3-using-plain-sql-for-very-large-databases)
  - [Mistake 4: Forgetting roles and global objects](#mistake-4-forgetting-roles-and-global-objects)
  - [Mistake 5: Restoring into a dirty database](#mistake-5-restoring-into-a-dirty-database)
  - [Mistake 6: Ignoring restore errors](#mistake-6-ignoring-restore-errors)
  - [Mistake 7: Skipping post-restore steps](#mistake-7-skipping-post-restore-steps)
  - [Mistake 8: Backups stored on same server](#mistake-8-backups-stored-on-same-server)
  - [Mistake 9: No monitoring of backup jobs](#mistake-9-no-monitoring-of-backup-jobs)
  - [Mistake 10: Never testing restore under pressure](#mistake-10-never-testing-restore-under-pressure)
  - [Final mental model](#final-mental-model-8)
  - [One-line explanation](#one-line-explanation-6)

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

- **It is a normal client program:**
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

- **What happens:**
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

- **Meaning**:
  * `-h` → server hostname or IP
  * `-p` → port (default 5432)
  * `-U` → database role

- This works locally or remotely.

---

<br>
<br>

## Authentication behavior

- **`pg_dump` uses the same authentication as any client:**
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

- **Useful when:**
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

- **`pg_dump` supports multiple formats:**
  * `-Fp` → plain SQL (default)
  * `-Fc` → custom (compressed)
  * `-Fd` → directory (parallel)
  * `-Ft` → tar

- Format choice affects restore method and speed.

---

<br>
<br>

## Why custom and directory formats matter

- **Custom and directory formats:**
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

- **`pg_dump`:**
  * reads data sequentially
  * uses MVCC snapshots
  * does not block writers

<br>

- **But:**
  * large dumps consume I/O
  * CPU usage increases

Scheduling matters in production.

---

<br>
<br>

## Common `pg_dump` failures

- **`pg_dump` often fails because:**
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

- **Avoid `pg_dump` when:**
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

## One-line explanation

`pg_dump` is a PostgreSQL client tool that creates transaction‑consistent logical backups by exporting database objects as SQL instructions.

<br>
<br>
<br>
<br>

<center>

# 03 Restore Using psql – Complete Flow (PostgreSQL Logical Restore)
</center>

<br>
<br>

- [01 What a SQL Dump Is and How It Works Internally in PostgreSQL](#01-what-a-sql-dump-is-and-how-it-works-internally-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why SQL dumps exist](#why-sql-dumps-exist)
  - [Tool used: `pg_dump`](#tool-used-pg_dump)
  - [What `pg_dump` actually reads](#what-pg_dump-actually-reads)
  - [How `pg_dump` works internally (step-by-step)](#how-pg_dump-works-internally-step-by-step)
  - [Why `pg_dump` does not block users](#why-pg_dump-does-not-block-users)
  - [What consistency means in a SQL dump](#what-consistency-means-in-a-sql-dump)
  - [What a SQL dump contains](#what-a-sql-dump-contains)
  - [What a SQL dump does NOT contain](#what-a-sql-dump-does-not-contain)
  - [Why SQL dumps are slow for large databases](#why-sql-dumps-are-slow-for-large-databases)
  - [Restore behavior of SQL dumps](#restore-behavior-of-sql-dumps)
  - [When I prefer SQL dumps](#when-i-prefer-sql-dumps)
  - [Common misunderstanding](#common-misunderstanding)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)
- [02 pg\_dump Command – Deep Dive (PostgreSQL Logical Backup)](#02-pg_dump-command--deep-dive-postgresql-logical-backup)
  - [In simple words](#in-simple-words-1)
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
  - [Final mental model](#final-mental-model-1)
  - [One-line explanation](#one-line-explanation-1)
- [03 Restore Using psql – Complete Flow (PostgreSQL Logical Restore)](#03-restore-using-psql--complete-flow-postgresql-logical-restore)
  - [In simple words](#in-simple-words-2)
  - [What restore actually does](#what-restore-actually-does)
  - [Pre-restore checklist (very important)](#pre-restore-checklist-very-important)
  - [Step 1: Create an empty database](#step-1-create-an-empty-database)
  - [Step 2: Restore using `psql`](#step-2-restore-using-psql)
  - [Restore directly from compressed dump](#restore-directly-from-compressed-dump)
  - [Restore from a remote server](#restore-from-a-remote-server)
  - [Common restore errors and causes](#common-restore-errors-and-causes)
    - [Role does not exist](#role-does-not-exist)
    - [Permission denied](#permission-denied)
    - [Object already exists](#object-already-exists)
  - [Useful restore options](#useful-restore-options)
  - [Post-restore tasks (often forgotten)](#post-restore-tasks-often-forgotten)
  - [Why restore takes time](#why-restore-takes-time)
  - [When `psql` restore is the right choice](#when-psql-restore-is-the-right-choice)
  - [Common DBA mistake](#common-dba-mistake)
  - [Final mental model](#final-mental-model-2)
  - [One-line explanation](#one-line-explanation-2)
- [04 `pg_restore` and Selective Restore in PostgreSQL](#04-pg_restore-and-selective-restore-in-postgresql)
  - [In simple words](#in-simple-words-3)
  - [Why `pg_restore` exists](#why-pg_restore-exists)
  - [How `pg_restore` works internally](#how-pg_restore-works-internally)
  - [Basic `pg_restore` syntax](#basic-pg_restore-syntax)
  - [Creating a compatible dump for `pg_restore`](#creating-a-compatible-dump-for-pg_restore)
  - [Listing dump contents (very important)](#listing-dump-contents-very-important)
  - [Restoring specific objects](#restoring-specific-objects)
  - [Excluding objects during restore](#excluding-objects-during-restore)
  - [Restoring schema and data separately](#restoring-schema-and-data-separately)
  - [Parallel restore (big performance boost)](#parallel-restore-big-performance-boost)
  - [Handling ownership and permissions](#handling-ownership-and-permissions)
  - [Common `pg_restore` failures](#common-pg_restore-failures)
  - [When `pg_restore` is the right tool](#when-pg_restore-is-the-right-tool)
  - [When `pg_restore` is NOT useful](#when-pg_restore-is-not-useful)
  - [Final mental model](#final-mental-model-3)
  - [One-line explanation](#one-line-explanation-3)
- [05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)](#05-postgresql-dump-formats--fp--fc--fd--ft-explainable-guide)
  - [In simple words](#in-simple-words-4)
  - [Overview of available dump formats](#overview-of-available-dump-formats)
  - [Plain format (`-Fp`)](#plain-format--fp)
    - [What it is](#what-it-is)
    - [Characteristics](#characteristics)
    - [Pros](#pros)
    - [Cons](#cons)
    - [When I use it](#when-i-use-it)
  - [Custom format (`-Fc`)](#custom-format--fc)
    - [What it is](#what-it-is-1)
    - [Characteristics](#characteristics-1)
    - [Pros](#pros-1)
    - [Cons](#cons-1)
    - [When I use it](#when-i-use-it-1)
  - [Directory format (`-Fd`)](#directory-format--fd)
    - [What it is](#what-it-is-2)
    - [Characteristics](#characteristics-2)
    - [Pros](#pros-2)
    - [Cons](#cons-2)
    - [When I use it](#when-i-use-it-2)
  - [Tar format (`-Ft`)](#tar-format--ft)
    - [What it is](#what-it-is-3)
    - [Characteristics](#characteristics-3)
    - [Pros](#pros-3)
    - [Cons](#cons-3)
    - [When I use it](#when-i-use-it-3)
  - [Restore tool comparison](#restore-tool-comparison)
  - [Performance reality](#performance-reality)
  - [DBA recommendation (real world)](#dba-recommendation-real-world)
  - [Common mistakes to avoid](#common-mistakes-to-avoid)
  - [Final mental model](#final-mental-model-4)
  - [One‑line explanation](#oneline-explanation)
- [06 Streaming Backups Between Servers in PostgreSQL](#06-streaming-backups-between-servers-in-postgresql)
  - [In simple words](#in-simple-words-5)
  - [Why streaming backups exist](#why-streaming-backups-exist)
  - [Most common streaming pattern](#most-common-streaming-pattern)
  - [Streaming between two different servers](#streaming-between-two-different-servers)
  - [Why this works safely](#why-this-works-safely)
  - [When streaming is a good choice](#when-streaming-is-a-good-choice)
  - [Limitations of streaming backups](#limitations-of-streaming-backups)
  - [Streaming with compression](#streaming-with-compression)
  - [Handling errors during streaming](#handling-errors-during-streaming)
  - [Streaming vs file-based backups](#streaming-vs-file-based-backups)
  - [DBA checklist before streaming](#dba-checklist-before-streaming)
  - [Final mental model](#final-mental-model-5)
  - [One-line explanation](#one-line-explanation-4)
- [07 pg\_dumpall and Cluster-Level Backups in PostgreSQL](#07-pg_dumpall-and-cluster-level-backups-in-postgresql)
  - [In simple words](#in-simple-words-6)
  - [Why `pg_dumpall` exists](#why-pg_dumpall-exists)
  - [What `pg_dumpall` actually backs up](#what-pg_dumpall-actually-backs-up)
  - [How `pg_dumpall` works internally](#how-pg_dumpall-works-internally)
  - [Basic `pg_dumpall` usage](#basic-pg_dumpall-usage)
  - [Role requirements (very important)](#role-requirements-very-important)
  - [Restoring from `pg_dumpall`](#restoring-from-pg_dumpall)
  - [Common `pg_dumpall` problems](#common-pg_dumpall-problems)
  - [`pg_dumpall` vs `pg_dump` (real difference)](#pg_dumpall-vs-pg_dump-real-difference)
  - [When I actually use `pg_dumpall`](#when-i-actually-use-pg_dumpall)
  - [Best practice (important)](#best-practice-important)
  - [Security warning](#security-warning)
  - [Final mental model](#final-mental-model-6)
  - [One-line explanation](#one-line-explanation-5)
- [08 Post‑Restore Tasks: ANALYZE, VACUUM, and Verification](#08-postrestore-tasks-analyze-vacuum-and-verification)
  - [In simple words](#in-simple-words-7)
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
  - [Common DBA mistake](#common-dba-mistake-1)
  - [Final mental model](#final-mental-model-7)
  - [One‑line explanation](#oneline-explanation-1)
- [09 Common SQL Dump Mistakes and Failure Scenarios in PostgreSQL](#09-common-sql-dump-mistakes-and-failure-scenarios-in-postgresql)
  - [In simple words](#in-simple-words-8)
  - [Mistake 1: Assuming backup success means restore success](#mistake-1-assuming-backup-success-means-restore-success)
  - [Mistake 2: Not checking permissions before `pg_dump`](#mistake-2-not-checking-permissions-before-pg_dump)
  - [Mistake 3: Using plain SQL for very large databases](#mistake-3-using-plain-sql-for-very-large-databases)
  - [Mistake 4: Forgetting roles and global objects](#mistake-4-forgetting-roles-and-global-objects)
  - [Mistake 5: Restoring into a dirty database](#mistake-5-restoring-into-a-dirty-database)
  - [Mistake 6: Ignoring restore errors](#mistake-6-ignoring-restore-errors)
  - [Mistake 7: Skipping post-restore steps](#mistake-7-skipping-post-restore-steps)
  - [Mistake 8: Backups stored on same server](#mistake-8-backups-stored-on-same-server)
  - [Mistake 9: No monitoring of backup jobs](#mistake-9-no-monitoring-of-backup-jobs)
  - [Mistake 10: Never testing restore under pressure](#mistake-10-never-testing-restore-under-pressure)
  - [Final mental model](#final-mental-model-8)
  - [One-line explanation](#one-line-explanation-6)

<br>
<br>

## In simple words

- Restoring a SQL dump means running SQL commands again to rebuild the database.
- PostgreSQL does not have a special “restore mode” for SQL dumps.
- Restore is simply **executing the dump file using psql**.

---

<br>
<br>

## What restore actually does

- A SQL dump contains:
  * CREATE statements
  * INSERT statements
  * GRANT and ownership commands

<br>

- When restoring:
  * PostgreSQL executes these commands one by one
  * objects are rebuilt logically
  * indexes are recreated, not copied

Restore is a **replay process**, not a file copy.

---

<br>
<br>

## Pre-restore checklist (very important)

- Before restoring, I always check:
  * target server is correct
  * PostgreSQL version is compatible
  * sufficient disk space exists
  * required roles already exist

- Most restore failures happen due to missing preparation.

---

<br>
<br>

## Step 1: Create an empty database

```bash
createdb newdb
```

> The target database must exist before restore.

<br>

Alternatively:

```bash
createdb -O app_user newdb

# This command creates a new database named newdb and sets app_user as the owner. In simple terms, app_user becomes the main user who controls this database and has full rights over it.
```

This sets correct ownership upfront.

---

<br>
<br>

## Step 2: Restore using `psql`

```bash
psql -d newdb -f backup.sql
```

- What happens internally:
  * `psql` reads SQL line by line
  * PostgreSQL executes each statement
  * errors are reported immediately

- Restore speed depends on dump size and indexes.

---

<br>
<br>

## Restore directly from compressed dump

```bash
gunzip -c backup.sql.gz | psql -d newdb
```

- This avoids extracting the file to disk.
- Useful when storage space is limited.

---

<br>
<br>

## Restore from a remote server

```bash
psql -h server_ip -U postgres -d newdb < backup.sql
```

> Restore works over network just like local execution.

---

<br>
<br>

## Common restore errors and causes

### Role does not exist

Error:

```bash
ERROR: role "app_user" does not exist
```

- **Fix:**
  * create role first
  * or restore with `--no-owner`

---

<br>
<br>

### Permission denied

- Occurs when restore role lacks privileges.

<br>

- **Fix:**
  * restore as superuser
  * or adjust ownership and grants

---

<br>
<br>

### Object already exists

- Occurs when restoring into a non-empty database.

<br>

- **Fix**:
  * drop and recreate database
  * or clean objects manually

---

<br>
<br>

## Useful restore options

**Skip ownership:**

```bash
psql -d newdb -f backup.sql --set ON_ERROR_STOP=on

# This command connects to the newdb database and runs all SQL commands from the backup.sql file. If any error occurs while executing the file, PostgreSQL immediately stops instead of continuing, which helps avoid ending up with a half-restored or broken database.
```

- **For controlled restores**:
  * run schema first
  * then data

---

<br>
<br>

## Post-restore tasks (often forgotten)

- **After restore, I always run:**

```bash
ANALYZE;

# This command tells PostgreSQL to scan the tables and update statistics about the data. These statistics help the query planner choose better and faster execution plans for future queries.
```

> This regenerates statistics and improves performance.

<br>

- **I also verify:**
  * row counts
  * application connectivity
  * basic queries

- Restore without verification is incomplete.

---

<br>
<br>

## Why restore takes time

- **SQL restore:**
  * executes millions of INSERTs
  * rebuilds indexes
  * processes constraints

- This is slower than physical restore by design.

---

<br>
<br>

## When `psql` restore is the right choice

- **I use `psql` restore when:**
  * restoring plain SQL dumps
  * migrating data
  * doing partial or selective rebuilds
  * debugging schema issues

- It gives full visibility and control.

---

<br>
<br>

## Common DBA mistake

- Assuming backup success means restore success.
- A backup is only valid if restore completes cleanly.

---

<br>
<br>

## Final mental model

* Restore = replay SQL
* psql = execution engine
* errors must be fixed immediately
* verification is mandatory

---

<br>
<br>

## One-line explanation

Restoring a SQL dump means executing the exported SQL commands using psql to rebuild the database logically.


<br>
<br>
<br>
<br>

<center>

# 04 `pg_restore` and Selective Restore in PostgreSQL
</center>

<br>
<br>

- [04 pg\_restore and Selective Restore in PostgreSQL](#04-pg_restore-and-selective-restore-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why `pg_restore` exists](#why-pg_restore-exists)
  - [How `pg_restore` works internally](#how-pg_restore-works-internally)
  - [Basic `pg_restore` syntax](#basic-pg_restore-syntax)
  - [Creating a compatible dump for `pg_restore`](#creating-a-compatible-dump-for-pg_restore)
  - [Listing dump contents (very important)](#listing-dump-contents-very-important)
  - [Restoring specific objects](#restoring-specific-objects)
  - [Excluding objects during restore](#excluding-objects-during-restore)
  - [Restoring schema and data separately](#restoring-schema-and-data-separately)
  - [Parallel restore (big performance boost)](#parallel-restore-big-performance-boost)
  - [Handling ownership and permissions](#handling-ownership-and-permissions)
  - [Common `pg_restore` failures](#common-pg_restore-failures)
  - [When `pg_restore` is the right tool](#when-pg_restore-is-the-right-tool)
  - [When `pg_restore` is NOT useful](#when-pg_restore-is-not-useful)
  - [Final mental model](#final-mental-model)
  - [One-line explanation (interview ready)](#one-line-explanation-interview-ready)

<br>
<br>

## In simple words

- `pg_restore` is used to restore logical backups that were created in **custom**, **directory**, or **tar** format.

<br>

- **Unlike plain SQL restore, `pg_restore` gives control**:
  * what to restore
  * how to restore
  * how fast to restore

- This makes it very powerful for real DBA work.

---

<br>
<br>

## Why `pg_restore` exists

- **Plain SQL dumps:**
  * must be restored fully
  * execute line by line
  * cannot skip objects easily

`pg_restore` exists to solve these problems.

<br>

- **It works only with **non-plain** dump formats:**
  * `-Fc` (custom)
  * `-Fd` (directory)
  * `-Ft` (tar)

---

<br>
<br>

## How `pg_restore` works internally

- **`pg_restore`:**
  * reads dump metadata
  * understands database objects
  * decides restore order
  * executes commands selectively

- It does **not** blindly replay SQL like `psql`.

---

## Basic `pg_restore` syntax

```bash
pg_restore -d target_db backup.dump
```

This restores everything from the dump into `target_db`.

---

<br>
<br>

## Creating a compatible dump for `pg_restore`

```bash
pg_dump -Fc dbname > dbname.dump
```

Without this format, `pg_restore` cannot be used.

---

<br>
<br>

## Listing dump contents (very important)

**Before restoring, I always inspect the dump:**

```bash
pg_restore -l dbname.dump

# This command lists the contents of the dbname.dump backup file. It lets you see what objects are inside the dump—like tables, schemas, functions—before you decide what or how to restore.
```

- **This shows:**
  * tables
  * schemas
  * indexes
  * functions
  * extensions

- It helps decide what to restore.

---

<br>
<br>

## Restoring specific objects

> Only one table:

```bash
pg_restore -t customers -d target_db dbname.dump
```

<br>

> Only one schema:

```bash
pg_restore -n sales -d target_db dbname.dump
```

> Selective restore is not possible with plain SQL dumps.

---

<br>
<br>

## Excluding objects during restore

> Exclude table:

```bash
pg_restore --exclude-table=logs -d target_db dbname.dump
```

<br>

> Exclude schema:

```bash
pg_restore --exclude-schema=test -d target_db dbname.dump
```

This is useful in debugging and migrations.

---

<br>
<br>

## Restoring schema and data separately

> Schema only:

```bash
pg_restore -s -d target_db dbname.dump
```

<br>

- **Data only:**

```bash
pg_restore -a -d target_db dbname.dump
```

This allows controlled restore sequences.

---

<br>
<br>

## Parallel restore (big performance boost)

```bash
pg_restore -j 4 -d target_db dbname.dump

# This command restores the dbname.dump file into the target_db database using 4 parallel jobs. It speeds up the restore process by loading multiple objects at the same time, which is especially useful for large databases.
```

<br>

- **Meaning:**
  * `-j 4` = use 4 parallel jobs

- Parallel restore:
  * speeds up large restores
  * requires directory or custom format

---

<br>
<br>

## Handling ownership and permissions

> Skip ownership:

```bash
pg_restore --no-owner -d target_db dbname.dump

# This command restores the dump into target_db without trying to set original object owners. It’s useful when restoring into a database where the original roles don’t exist or when you want all objects to belong to the current user.
```

<br>

> Skip privileges:

```bash
pg_restore --no-privileges -d target_db dbname.dump

# This command restores the dump into target_db without restoring GRANT and REVOKE permissions. It’s useful when you want to handle access control separately or avoid permission errors during restore.
```

Very common when restoring to test or staging.

---

<br>
<br>

## Common `pg_restore` failures

- **`pg_restore` fails when:**
  * roles do not exist
  * target database is missing
  * permissions are insufficient
  * objects already exist

- Most issues are environment-related, not tool-related.

---

<br>
<br>

## When `pg_restore` is the right tool

- **I use `pg_restore` when:**
  * restoring large databases
  * restoring selective objects
  * doing migrations
  * minimizing restore time

- It offers control and speed.

---

<br>
<br>

## When `pg_restore` is NOT useful

- **`pg_restore` cannot:**
  * restore plain SQL dumps
  * restore physical backups
  * bypass permission rules

- Tool choice must match dump format.

---

<br>
<br>

## Final mental model

* `pg_dump` creates structured dumps
* `pg_restore` understands dump structure
* selective restore saves time
* parallel restore improves performance

---

## One-line explanation

`pg_restore` restores custom-format logical backups with fine-grained control over objects, order, and performance.


<br>
<br>
<br>
<br>

<center>

# 05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)
</center>

<br>
<br>

- [05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)](#05-postgresql-dump-formats--fp--fc--fd--ft-explainable-guide)
  - [In simple words](#in-simple-words)
  - [Overview of available dump formats](#overview-of-available-dump-formats)
  - [Plain format (`-Fp`)](#plain-format--fp)
    - [What it is](#what-it-is)
    - [Characteristics](#characteristics)
    - [Pros](#pros)
    - [Cons](#cons)
    - [When I use it](#when-i-use-it)
  - [Custom format (`-Fc`)](#custom-format--fc)
    - [What it is](#what-it-is-1)
    - [Characteristics](#characteristics-1)
    - [Pros](#pros-1)
    - [Cons](#cons-1)
    - [When I use it](#when-i-use-it-1)
  - [Directory format (`-Fd`)](#directory-format--fd)
    - [What it is](#what-it-is-2)
    - [Characteristics](#characteristics-2)
    - [Pros](#pros-2)
    - [Cons](#cons-2)
    - [When I use it](#when-i-use-it-2)
  - [Tar format (`-Ft`)](#tar-format--ft)
    - [What it is](#what-it-is-3)
    - [Characteristics](#characteristics-3)
    - [Pros](#pros-3)
    - [Cons](#cons-3)
    - [When I use it](#when-i-use-it-3)
  - [Restore tool comparison](#restore-tool-comparison)
  - [Performance reality](#performance-reality)
  - [DBA recommendation (real world)](#dba-recommendation-real-world)
  - [Common mistakes to avoid](#common-mistakes-to-avoid)
  - [Final mental model](#final-mental-model)
  - [One‑line explanation (interview ready)](#oneline-explanation-interview-ready)

<br>
<br>


## In simple words

- When I take a logical backup with `pg_dump`, I must choose **how the backup is stored**.
- That choice is called the **dump format**.

<br>

- The format decides:
  * file structure
  * restore speed
  * flexibility
  * whether selective and parallel restore is possible

- Choosing the wrong format is a common DBA mistake.

---

<br>
<br>

## Overview of available dump formats

- PostgreSQL supports four main dump formats:
  * `-Fp` → Plain SQL (default)
  * `-Fc` → Custom format
  * `-Fd` → Directory format
  * `-Ft` → Tar format

- Each format has a specific purpose.

---

<br>
<br>

## Plain format (`-Fp`)

### What it is

A human‑readable SQL file containing CREATE, INSERT, and GRANT statements.

```bash
pg_dump -Fp mydb > mydb.sql
```

<br>
<br>

### Characteristics
* text file
* readable and editable
* restored using `psql`

<br>
<br>

### Pros
* very simple
* easy to inspect or modify
* no special restore tool needed

<br>
<br>

### Cons
* largest file size
* slow restore
* no selective restore
* no parallel restore

<br>
<br>

### When I use it
* small databases
* learning and debugging
* manual inspection needed

---

<br>
<br>

## Custom format (`-Fc`)

### What it is

A compressed binary dump designed specifically for PostgreSQL.

```bash
pg_dump -Fc mydb > mydb.dump
```

<br>
<br>

### Characteristics
* binary format
* requires `pg_restore`
* internally structured

<br>
<br>

### Pros
* smaller size
* faster restore
* supports selective restore
* supports parallel restore

<br>
<br>

### Cons
* not human‑readable
* cannot be edited manually

<br>
<br>

### When I use it
* production backups
* medium to large databases
* when restore speed matters

---

<br>
<br>

## Directory format (`-Fd`)

### What it is

A folder containing separate files for database objects.

```bash
pg_dump -Fd mydb -f mydb_dir
```

<br>
<br>

### Characteristics
* one directory, many files
* best for parallel restore

<br>
<br>

### Pros
* fastest restore
* highest flexibility
* ideal for very large databases

<br>
<br>

### Cons
* not a single file
* harder to move manually

<br>
<br>

### When I use it
* very large databases
* enterprise systems
* time‑critical restores

---

<br>
<br>

## Tar format (`-Ft`)

### What it is

A `tar` archive containing dump contents.

```bash
pg_dump -Ft mydb > mydb.tar
```

<br>
<br>

### Characteristics
* single archive file
* intermediate flexibility

<br>
<br>

### Pros
* single file
* supports `pg_restore`

<br>
<br>

### Cons
* slower than custom and directory formats
* less commonly used

<br>
<br>

### When I use it
* when I need a single file but want `pg_restore` features

---

<br>
<br>

## Restore tool comparison

| Dump Format | Restore Tool | Selective Restore | Parallel Restore |
| ----------- | ------------ | ----------------- | ---------------- |
| -Fp         | psql         | No                | No               |
| -Fc         | pg_restore   | Yes               | Yes              |
| -Fd         | pg_restore   | Yes               | Yes (Best)       |
| -Ft         | pg_restore   | Yes               | Limited          |

---

<br>
<br>

## Performance reality

* Backup speed is similar across formats
* Restore speed varies significantly
* Parallel restore makes the biggest difference

Format choice matters most during restore, not backup.

---

<br>
<br>

## DBA recommendation (real world)
* Small DB → `-Fp`
* Medium / Large DB → `-Fc`
* Very Large / Mission‑critical DB → `-Fd`

Avoid default plain format in production unless you know why you are using it.

---

<br>
<br>

## Common mistakes to avoid
* Using plain format for huge databases
* Not planning restore strategy
* Choosing format without testing restore

Backup format must match recovery expectations.

---

<br>
<br>

## Final mental model

* Dump format defines restore power
* pg_restore needs structured formats
* Parallel restore saves hours
* Production ≠ plain SQL

---

<br>
<br>

## One‑line explanation 

PostgreSQL dump formats define how backups are stored and restored, directly affecting flexibility, restore speed, and recovery options.


<br>
<br>
<br>
<br>

<center>

# 06 Streaming Backups Between Servers in PostgreSQL
</center>

<br>
<br>

- [06 Streaming Backups Between Servers in PostgreSQL](#06-streaming-backups-between-servers-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why streaming backups exist](#why-streaming-backups-exist)
  - [Most common streaming pattern](#most-common-streaming-pattern)
  - [Streaming between two different servers](#streaming-between-two-different-servers)
  - [Why this works safely](#why-this-works-safely)
  - [When streaming is a good choice](#when-streaming-is-a-good-choice)
  - [Limitations of streaming backups](#limitations-of-streaming-backups)
  - [Streaming with compression](#streaming-with-compression)
  - [Handling errors during streaming](#handling-errors-during-streaming)
  - [Streaming vs file-based backups](#streaming-vs-file-based-backups)
  - [DBA checklist before streaming](#dba-checklist-before-streaming)
  - [Final mental model](#final-mental-model)
  - [One-line explanation (interview ready)](#one-line-explanation-interview-ready)

<br>
<br>


## In simple words

- Streaming backup means copying data from one PostgreSQL server to another **without creating an intermediate dump file**.
- Data flows directly from source to target using a pipe.
- This is fast, clean, and very useful for migrations.

---

<br>
<br>

## Why streaming backups exist

- **Creating dump files:**
  * needs disk space
  * takes extra time
  * creates cleanup work

<br>

- **Streaming avoids this by:**
  * reading from source
  * writing to target immediately

No file sits in the middle.

---

<br>
<br>

## Most common streaming pattern

```bash
pg_dump source_db | psql -d target_db
```

**What happens internally:**
* `pg_dump` reads data from source
* output is sent through pipe
* psql receives and executes SQL
* target database is rebuilt live

---

<br>
<br>

## Streaming between two different servers

```bash
pg_dump -h source_ip -U src_user source_db \
| psql -h target_ip -U tgt_user -d target_db
```

**This works across:**
* different machines
* different data centers
* different PostgreSQL versions

---

<br>
<br>

## Why this works safely

* `pg_dump` uses a consistent snapshot
* `psql` executes commands in order
* data integrity is preserved

Users can keep working on source during streaming.

---

<br>
<br>

## When streaming is a good choice

**I use streaming when:**
* migrating databases
* cloning production to staging
* disk space is limited
* one-time transfers are needed

It is fast and simple.

---

<br>
<br>

## Limitations of streaming backups

**Streaming backups:**
* cannot be resumed if interrupted
* provide no backup file for reuse
* depend heavily on network stability

If network drops, restore fails.

---

<br>
<br>

## Streaming with compression

```bash
pg_dump source_db | gzip | gunzip | psql -d target_db

# This command takes a live backup of source_db, compresses it, immediately decompresses it, and pipes it straight into target_db. In simple words, it copies data from one database to another in a single flow without creating any dump file on disk.
```

- Used when network bandwidth is limited.
- CPU cost increases.

---

<br>
<br>

## Handling errors during streaming

**If error occurs:**
* streaming stops immediately
* partial data may exist

<br>

**Best practice:**
* restore into empty database
* drop and retry on failure

---

<br>
<br>

## Streaming vs file-based backups

**Streaming:**

* faster
* less disk usage
* single-use


<br>

**File-based:**

* reusable
* resumable
* safer for long-term storage

Choose based on situation.

---

<br>
<br>

## DBA checklist before streaming

**Before streaming I ensure:**

* target DB is empty
* required roles exist
* permissions are correct
* network is stable

Preparation prevents failures.

---

<br>
<br>

## Final mental model

* Streaming = pipe + live restore
* No files in between
* Fast but fragile
* Best for migrations

---

<br>
<br>

## One-line explanation 

Streaming backup transfers a logical dump directly from one PostgreSQL server to another using pipes, avoiding intermediate files.

<br>
<br>
<br>
<br>

<center>

# 07 pg_dumpall and Cluster-Level Backups in PostgreSQL
</center>

<br>
<br>

- [07 pg\_dumpall and Cluster-Level Backups in PostgreSQL](#07-pg_dumpall-and-cluster-level-backups-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why `pg_dumpall` exists](#why-pg_dumpall-exists)
  - [What `pg_dumpall` actually backs up](#what-pg_dumpall-actually-backs-up)
  - [How `pg_dumpall` works internally](#how-pg_dumpall-works-internally)
  - [Basic `pg_dumpall` usage](#basic-pg_dumpall-usage)
  - [Role requirements (very important)](#role-requirements-very-important)
  - [Restoring from `pg_dumpall`](#restoring-from-pg_dumpall)
  - [Common `pg_dumpall` problems](#common-pg_dumpall-problems)
  - [`pg_dumpall` vs `pg_dump` (real difference)](#pg_dumpall-vs-pg_dump-real-difference)
  - [When I actually use `pg_dumpall`](#when-i-actually-use-pg_dumpall)
  - [Best practice (important)](#best-practice-important)
  - [Security warning](#security-warning)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

`pg_dumpall` is used to back up **the entire PostgreSQL cluster**, not just one database.

**It captures:**
* all databases
* all roles and users
* role memberships
* global objects

If `pg_dump` backs up *data*, `pg_dumpall` backs up the *identity of the cluster*.

---

<br>
<br>

## Why `pg_dumpall` exists

Backing up only databases is not enough.

**Real restores fail because:**
* roles do not exist
* ownership is missing
* permissions break

`pg_dumpall` exists to solve this by capturing **global objects**.

---

<br>
<br>

## What `pg_dumpall` actually backs up

**`pg_dumpall` includes:**
* CREATE ROLE statements
* role passwords (hashed)
* role memberships
* CREATE DATABASE statements
* all databases (as SQL)

<br>

**It does NOT back up:**
* server configuration files
* physical WAL or data files

---

<br>
<br>

## How `pg_dumpall` works internally

* connects as a superuser
* reads global system catalogs
* dumps roles and privileges first
* dumps each database sequentially

All output is written as **plain SQL**.

---

<br>
<br>

## Basic `pg_dumpall` usage

```bash
pg_dumpall > cluster_backup.sql
```

This creates one large SQL file containing everything.

---

<br>
<br>

## Role requirements (very important)

`pg_dumpall` **must run as a superuser**.

<br>

**Reason:**
* global catalogs are restricted
* role passwords and memberships require superuser access

Non-superuser runs will fail.

---

<br>
<br>

## Restoring from `pg_dumpall`

**Restore is done using psql:**

```bash
psql -f cluster_backup.sql postgres
```

What happens:
* roles are created first
* databases are created
* database contents are restored

Restore should be done on a clean cluster.

---

<br>
<br>

## Common `pg_dumpall` problems

* extremely large output files
* slow restore
* no parallel restore support
* hard to debug failures

Because everything is in one file, recovery is all-or-nothing.

---

<br>
<br>

## `pg_dumpall` vs `pg_dump` (real difference)

**`pg_dump`:**

* single database
* flexible formats
* selective restore

<br>

**`pg_dumpall`:**

* entire cluster
* plain SQL only
* no selective restore

They serve different purposes.

---

<br>
<br>

## When I actually use `pg_dumpall`

**I use `pg_dumpall` mainly for:**

* backing up roles and global objects
* disaster recovery documentation
* rebuilding a cluster from scratch

For data backups, I still prefer pg_dump.

---

<br>
<br>

## Best practice (important)

**Instead of using `pg_dumpall` alone:**

* back up databases with `pg_dump`
* back up roles separately with `pg_dumpall --globals-only`

Example:

```bash
pg_dumpall --globals-only > globals.sql

# This command backs up only the global objects of the PostgreSQL cluster, such as roles and tablespaces. It does not include any database data, making it useful when you want to preserve users and permissions separately from databases.
```

This gives more control during restore.

---

<br>
<br>

## Security warning

**`pg_dumpall` output contains:**
* role definitions
* password hashes

<br>

**Backup files must be:**
* protected
* access-controlled
* stored securely

---

<br>
<br>

## Final mental model

* `pg_dump` = database-level backup
* `pg_dumpall` = cluster identity backup
* roles matter as much as data

---

<br>
<br>

## One-line explanation 

`pg_dumpall` creates a logical backup of all databases and global objects in a PostgreSQL cluster using plain SQL.


<center>


# 08 Post‑Restore Tasks: ANALYZE, VACUUM, and Verification

</center>


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


<br>
<br>
<br>
<br>

<center>


# 09 Common SQL Dump Mistakes and Failure Scenarios in PostgreSQL

</center>


<br>
<br>

- [09 Common SQL Dump Mistakes and Failure Scenarios in PostgreSQL](#09-common-sql-dump-mistakes-and-failure-scenarios-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Mistake 1: Assuming backup success means restore success](#mistake-1-assuming-backup-success-means-restore-success)
  - [Mistake 2: Not checking permissions before `pg_dump`](#mistake-2-not-checking-permissions-before-pg_dump)
  - [Mistake 3: Using plain SQL for very large databases](#mistake-3-using-plain-sql-for-very-large-databases)
  - [Mistake 4: Forgetting roles and global objects](#mistake-4-forgetting-roles-and-global-objects)
  - [Mistake 5: Restoring into a dirty database](#mistake-5-restoring-into-a-dirty-database)
  - [Mistake 6: Ignoring restore errors](#mistake-6-ignoring-restore-errors)
  - [Mistake 7: Skipping post-restore steps](#mistake-7-skipping-post-restore-steps)
  - [Mistake 8: Backups stored on same server](#mistake-8-backups-stored-on-same-server)
  - [Mistake 9: No monitoring of backup jobs](#mistake-9-no-monitoring-of-backup-jobs)
  - [Mistake 10: Never testing restore under pressure](#mistake-10-never-testing-restore-under-pressure)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

- Most backup failures are not tool problems.
- They are **human and process mistakes**.

---

<br>
<br>

## Mistake 1: Assuming backup success means restore success

Many DBAs run:

```bash
pg_dump mydb > backup.sql
```

If the command finishes, they assume everything is fine.

<br>

**Reality:**

* backup file may be incomplete
* restore may fail due to roles, permissions, or dependencies

**Correct approach:**

> A backup is valid only after a successful restore test.

---

<br>
<br>

## Mistake 2: Not checking permissions before `pg_dump`

`pg_dump` fails if it cannot read **any single object**.

<br>

**Common causes:**

* missing access to one schema
* view referencing inaccessible table
* extension privilege issue

<br>

**Correct approach:**

* run `pg_dump` as database owner or superuser
* verify permissions in advance

---

<br>
<br>

## Mistake 3: Using plain SQL for very large databases

**Plain format:**

* generates huge files
* restores slowly
* cannot run in parallel

<br>

**Using it for multi-GB databases leads to:**

* long downtime
* restore failures

<br>

**Correct approach:**

* use custom or directory formats
* enable parallel restore

---

<br>
<br>

## Mistake 4: Forgetting roles and global objects

**Database restore fails silently when:**

* roles are missing
* ownership cannot be assigned

<br>

**Symptoms:**

* restore completes with warnings
* application fails later

<br>

**Correct approach:**

* restore roles first
* use `pg_dumpall --globals-only`

---

<br>
<br>

## Mistake 5: Restoring into a dirty database

**Restoring into a database that already contains objects leads to:**

* object already exists errors
* partial restore
* inconsistent state

<br>

**Correct approach:**

* always restore into a clean database
* drop and recreate if unsure

---

<br>
<br>

## Mistake 6: Ignoring restore errors

During restore, errors scroll quickly.

<br>

**Ignoring them results in:**

* missing tables
* broken foreign keys
* silent data loss

<br>

**Correct approach:**

* stop on error
* fix root cause
* restart restore

---

<br>
<br>

## Mistake 7: Skipping post-restore steps

**After restore:**

* statistics are missing
* sequences may be wrong

<br>

**Skipping `ANALYZE` causes:**

* slow queries
* wrong plans

<br>

**Correct approach:**

* always run `ANALYZE`
* verify sequences and counts

---

<br>
<br>

## Mistake 8: Backups stored on same server

**Storing backups on the same server means:**

* disk failure = data + backup lost

<br>

**Correct approach:**

* store backups off-host
* use separate storage or remote systems

---

<br>
<br>

## Mistake 9: No monitoring of backup jobs

**Backups may:**

* silently fail
* stop due to disk full
* hang for hours

<br>

**Correct approach:**

* log backup output
* monitor duration and size
* alert on failures

---

<br>
<br>

## Mistake 10: Never testing restore under pressure

**Real disaster recoveries fail because:**

* restore steps were never practiced
* documentation is missing
* decisions are made in panic

<br>

**Correct approach:**

* schedule restore drills
* document recovery steps

---

<br>
<br>

## Final mental model

* Tools rarely fail
* Process failures cause data loss
* Restore testing is non-negotiable
* Preparation beats panic

---

<br>
<br>

## One-line explanation 

Most SQL dump failures happen due to permission issues, wrong formats, missing roles, or untested restore processes rather than tool limitations.
