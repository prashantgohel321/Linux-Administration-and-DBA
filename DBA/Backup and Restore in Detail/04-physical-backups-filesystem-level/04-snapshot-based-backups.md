<center>

# 04 Snapshot-Based Backups in PostgreSQL (LVM / Cloud Snapshots)
</center>

<br>
<br>

- [04 Snapshot-Based Backups in PostgreSQL (LVM / Cloud Snapshots)](#04-snapshot-based-backups-in-postgresql-lvm--cloud-snapshots)
  - [In simple words](#in-simple-words)
  - [Why snapshot-based backups exist](#why-snapshot-based-backups-exist)
  - [Types of snapshots used](#types-of-snapshots-used)
  - [The BIG misconception (very important)](#the-big-misconception-very-important)
  - [Safe snapshot workflow (correct way)](#safe-snapshot-workflow-correct-way)
    - [Step 1: Force WAL consistency](#step-1-force-wal-consistency)
    - [Step 2: Take filesystem snapshot](#step-2-take-filesystem-snapshot)
    - [Step 3: End backup mode](#step-3-end-backup-mode)
  - [What pg\_start\_backup / pg\_stop\_backup actually do](#what-pg_start_backup--pg_stop_backup-actually-do)
  - [Restore from snapshot backup](#restore-from-snapshot-backup)
  - [Tablespaces and snapshots](#tablespaces-and-snapshots)
  - [Common snapshot mistakes](#common-snapshot-mistakes)
  - [Snapshot vs `pg_basebackup`](#snapshot-vs-pg_basebackup)
  - [When I use snapshot-based backups](#when-i-use-snapshot-based-backups)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

**Snapshot-based backup means:**

* I take a **filesystem or storage snapshot**
* instead of manually copying files

The snapshot freezes disk state instantly.

PostgreSQL keeps running.

This gives **fast backups with very low downtime** — if done correctly.

---

<br>
<br>

## Why snapshot-based backups exist

Copying large data directories takes time.

Stopping PostgreSQL is often not acceptable.

**Snapshots exist to:**

* freeze disk state in seconds
* reduce downtime to near-zero
* back up very large databases

This is common in enterprise and cloud setups.

---

<br>
<br>

## Types of snapshots used

**Snapshot backups are usually taken at:**

* LVM level (on Linux)
* Cloud storage level (AWS EBS, Azure Disk, GCP PD)
* Enterprise storage arrays

PostgreSQL does not create these snapshots itself.

It cooperates with them.

---

<br>
<br>

## The BIG misconception (very important)

> A filesystem snapshot alone is **NOT** enough.

**If PostgreSQL is writing data while snapshot is taken:**

* files can be inconsistent
* restore may fail

Snapshots must be coordinated with PostgreSQL.

---

<br>
<br>

## Safe snapshot workflow (correct way)

### Step 1: Force WAL consistency

**Before snapshot:**

```sql
SELECT pg_start_backup('snapshot_backup');
```

**This tells PostgreSQL:**

* I am about to take a filesystem snapshot
* make sure WAL protects all in-flight changes

---

<br>
<br>

### Step 2: Take filesystem snapshot

**At OS or cloud level:**

* create snapshot of all data volumes
* include tablespaces if present

This operation is usually instant.

---

<br>
<br>

### Step 3: End backup mode

**After snapshot:**

```sql
SELECT pg_stop_backup();
```

This releases WAL pressure and marks snapshot complete.

---

<br>
<br>

## What pg_start_backup / pg_stop_backup actually do

They do NOT stop writes.

**They ensure:**

* full-page writes are enabled
* WAL contains enough data to fix inconsistencies
* restore can recover safely

This is why WAL size often increases during snapshot backups.

---

<br>
<br>

## Restore from snapshot backup

**Restore process:**

* attach snapshot volume to server
* mount filesystem
* place data directory back
* start PostgreSQL
* WAL replay fixes partial pages

Restore is usually fast.

---

<br>
<br>

## Tablespaces and snapshots

**If tablespaces exist:**

* snapshot **every volume**
* snapshot them **at the same time**

Missing or mismatched snapshots cause restore failure.

---

<br>
<br>

## Common snapshot mistakes

* taking snapshot without `pg_start_backup`
* forgetting tablespace volumes
* restoring without required WAL
* assuming crash recovery is enough

These mistakes lead to silent corruption.

---

<br>
<br>

## Snapshot vs `pg_basebackup`

**Snapshots:**

* extremely fast
* storage dependent
* more operational risk

**`pg_basebackup`:**

* slower
* PostgreSQL-managed
* safer and simpler

Senior DBAs choose based on environment maturity.

---

<br>
<br>

## When I use snapshot-based backups

**I use them when:**

* database is very large
* downtime must be minimal
* storage supports snapshots well
* WAL archiving is reliable

Snapshots demand discipline.

---

<br>
<br>

## Final mental model

* Snapshot freezes disk, not PostgreSQL
* WAL ensures consistency
* Coordination is mandatory
* Speed comes with responsibility

---

<br>
<br>

## One-line explanation 

Snapshot-based backups use filesystem or storage snapshots coordinated with PostgreSQL WAL to enable fast, low-downtime physical backups.


<br>
<br>
<br>
<br>


