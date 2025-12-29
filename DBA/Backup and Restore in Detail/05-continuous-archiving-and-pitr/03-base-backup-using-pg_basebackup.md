<center>

# 03 Base Backup Using `pg_basebackup` (Foundation of PITR)
</center>

<br>
<br>

- [03 Base Backup Using `pg_basebackup` (Foundation of PITR)](#03-base-backup-using-pg_basebackup-foundation-of-pitr)
  - [In simple words](#in-simple-words)
  - [Why base backup is required](#why-base-backup-is-required)
  - [What `pg_basebackup` actually does](#what-pg_basebackup-actually-does)
  - [Role and permission requirements](#role-and-permission-requirements)
  - [Basic `pg_basebackup` command](#basic-pg_basebackup-command)
  - [WAL handling during base backup](#wal-handling-during-base-backup)
    - [Stream WAL (recommended)](#stream-wal-recommended)
    - [Fetch WAL after backup](#fetch-wal-after-backup)
  - [Compression and performance](#compression-and-performance)
  - [Using tar format](#using-tar-format)
  - [Impact on running database](#impact-on-running-database)
  - [Restoring from a base backup](#restoring-from-a-base-backup)
  - [Common `pg_basebackup` mistakes](#common-pg_basebackup-mistakes)
  - [When I use `pg_basebackup`](#when-i-use-pg_basebackup)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

- A base backup is **a full physical copy of the entire PostgreSQL cluster** taken at a specific point in time. 
- The `pg_basebackup` tool is used to create this backup safely while the database is still running. 
- WAL files by themselves cannot restore anything unless there is a base backup to start from.

---

<br>
<br>

## Why base backup is required

- A base backup is required because WAL files only contain the changes made to the database, not the original data. 
- To restore a database, PGSQL first needs a base backup as the starting point and then replays WAL files on top of it. 
- Without the base backup, WAL files have nothing to apply to, so recovery is impossible.

---

<br>
<br>

## What `pg_basebackup` actually does

**`pg_basebackup`:**
* connects to PGSQL as a replication client
* copies the entire data directory
* ensures consistency using WAL
* optionally streams WAL during backup

It is WAL-aware by design.

---

<br>
<br>

## Role and permission requirements

****`pg_basebackup` requires:**
* superuser, or
* role with REPLICATION and BACKUP privileges

A normal database user cannot take a base backup.

---

<br>
<br>

## Basic `pg_basebackup` command

```bash
pg_basebackup -D /backup/base -Fp -X stream -P
```

**Meaning:**
* `-D` → destination directory
* `-Fp` → plain file format
* `-X stream` → stream WAL during backup
* `-P` → show progress

This creates a consistent physical backup.

---

<br>
<br>

## WAL handling during base backup

**Two common options:**

### Stream WAL (recommended)

```bash
-X stream
```

* WAL is streamed live
* safest option
* avoids missing WAL segments

---

<br>
<br>

### Fetch WAL after backup

```bash
-X fetch
```

* WAL is copied after data files
* riskier if WAL is recycled too fast

Streaming is preferred in production.

---

<br>
<br>

## Compression and performance

`pg_basebackup` supports compression:

```bash
pg_basebackup -D /backup/base -Fp -X stream -Z 9
```

**Higher compression:**
* reduces disk usage
* increases CPU load

Balance based on system capacity.

---

<br>
<br>

## Using tar format

```bash
pg_basebackup -D /backup/base -Ft -X stream
```

**Tar format:**

* creates archive files
* easier to move
* slower to extract during restore

---

<br>
<br>

## Impact on running database

During `pg_basebackup`:
* read I/O increases
* WAL generation increases
* archive pressure rises

This must be monitored on production systems.

---

<br>
<br>

## Restoring from a base backup

**Restore steps:**
* stop PostgreSQL
* clean or replace PGDATA
* copy base backup into place
* configure recovery settings
* start PostgreSQL

WAL replay completes the restore.

---

<br>
<br>

## Common `pg_basebackup` mistakes
* running without WAL streaming
* insufficient disk space
* wrong permissions on destination
* forgetting tablespaces

Base backups must be tested.

---

<br>
<br>

## When I use `pg_basebackup`

**I use it when:**
* PITR is required
* physical backups are primary recovery
* downtime must be minimal

It is the backbone of serious recovery setups.

---

<br>
<br>

## Final mental model

* Base backup = starting snapshot
* pg_basebackup = safe physical copier
* WAL streaming = consistency guarantee
* Restore = base + WAL replay

---

<br>
<br>

## One-line explanation 

pg_basebackup takes a consistent physical snapshot of a PostgreSQL cluster, forming the base for WAL-based recovery and PITR.


<br>
<br>
<br>
<br>


