<center>

# 02 PGDATA Directory Structure (What Actually Gets Backed Up)
</center>

<br>
<br>

- [02 PGDATA Directory Structure (What Actually Gets Backed Up)](#02-pgdata-directory-structure-what-actually-gets-backed-up)
  - [In simple words](#in-simple-words)
  - [What `PGDATA` represents](#what-pgdata-represents)
  - [High-level layout of `PGDATA`](#high-level-layout-of-pgdata)
  - [`base/` directory (user databases)](#base-directory-user-databases)
  - [`global/` directory (cluster metadata)](#global-directory-cluster-metadata)
  - [`pg_wal/` directory (write-ahead log)](#pg_wal-directory-write-ahead-log)
  - [`pg_xact/` (transaction status)](#pg_xact-transaction-status)
  - [`pg_multixact/`](#pg_multixact)
  - [`pg_commit_ts/`](#pg_commit_ts)
  - [`pg_tblspc/` (tablespaces)](#pg_tblspc-tablespaces)
  - [Configuration files inside `PGDATA`](#configuration-files-inside-pgdata)
  - [Files you should never touch](#files-you-should-never-touch)
  - [Common DBA mistake](#common-dba-mistake)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

- `$PGDATA` is the **heart of PostgreSQL**.
- Every physical backup is basically a copy of this directory.
- If you don’t understand what lives here, physical backups will always feel risky.

---

<br>
<br>

## What `PGDATA` represents

**`PGDATA` is the directory where PostgreSQL stores:**
* all databases
* system catalogs
* transaction metadata
* WAL files (or links)

When PostgreSQL starts, it reads `PGDATA` first.

---

<br>
<br>

## High-level layout of `PGDATA`

**Inside `PGDATA`, you will usually see:**

* `base/`
* `global/`
* `pg_wal/`
* `pg_multixact/`
* `pg_xact/`
* `pg_commit_ts/`
* `pg_tblspc/`
* `postgresql.conf`
* `pg_hba.conf`
* `pg_ident.conf`

Each directory has a very specific job.

---

<br>
<br>

## `base/` directory (user databases)

This directory contains **actual table and index files**.

* each database has its own subdirectory
* filenames are numeric OIDs
* data is stored in 8KB pages

This is where most disk space is consumed.

---

<br>
<br>

## `global/` directory (cluster metadata)

**This stores cluster-wide information:**

* roles
* databases list
* shared system catalogs

**If `global/` is missing or corrupted:**

* PostgreSQL will not start

---

<br>
<br>

## `pg_wal/` directory (write-ahead log)

This is the **most critical directory for recovery**.

**It stores WAL segments that:**

* record every data change
* ensure crash safety
* enable PITR

**If `pg_wal` fills up:**

* database can stop accepting writes

---

<br>
<br>

## `pg_xact/` (transaction status)

**Tracks:**

* committed transactions
* aborted transactions

PostgreSQL uses this to decide which rows are visible.

Missing or corrupted pg_xact leads to data inconsistency.

---

<br>
<br>

## `pg_multixact/`

**Used when:**

* multiple transactions lock the same row

Common in systems with heavy concurrent updates.

This directory must be included in physical backups.

---

<br>
<br>

## `pg_commit_ts/`

- Stores commit timestamps (if enabled).
- Not always active, but must be backed up if present.

---

<br>
<br>

## `pg_tblspc/` (tablespaces)

Contains symbolic links to tablespaces located outside `PGDATA`.

**Important rule:**

- Backing up `PGDATA` alone is NOT enough when tablespaces exist.
- Tablespace directories must be backed up separately.

---

<br>
<br>

## Configuration files inside `PGDATA`

**Usually includes:**

* `postgresql.conf`
* `pg_hba.conf`
* `pg_ident.conf`

Depending on setup, these may be outside `PGDATA`.

Do not assume configs are always included in backups.

---

<br>
<br>

## Files you should never touch

**Never manually edit:**

* files inside `base/`
* WAL files
* transaction metadata

PostgreSQL expects full control over these.

---

<br>
<br>

## Common DBA mistake

**Copying only `base/` and ignoring:**

* `global/`
* `pg_wal/`
* `pg_xact/`

This leads to broken restores.

---

<br>
<br>

## Final mental model

* `PGDATA` = database brain
* `base` = user data
* `pg_wal` = recovery engine
* `global` = cluster identity
* tablespaces need extra care

---

<br>
<br>

## One-line explanation 

`PGDATA` contains all PostgreSQL data files, WAL, and metadata required for physical backup and recovery.



<br>
<br>
<br>
<br>

