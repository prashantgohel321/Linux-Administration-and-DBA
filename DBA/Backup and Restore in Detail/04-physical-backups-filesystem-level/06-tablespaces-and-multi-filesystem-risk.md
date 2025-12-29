<center>

# 06 Tablespaces and Multi-Filesystem Risks in PostgreSQL Backups
</center>

<br>
<br>

- [06 Tablespaces and Multi-Filesystem Risks in PostgreSQL Backups](#06-tablespaces-and-multi-filesystem-risks-in-postgresql-backups)
  - [In simple words](#in-simple-words)
  - [What a tablespace really is](#what-a-tablespace-really-is)
  - [Why tablespaces complicate backups](#why-tablespaces-complicate-backups)
  - [How PostgreSQL tracks tablespaces](#how-postgresql-tracks-tablespaces)
  - [Offline backup with tablespaces](#offline-backup-with-tablespaces)
  - [Online backup and tablespaces](#online-backup-and-tablespaces)
  - [Snapshot backups and ordering risk](#snapshot-backups-and-ordering-risk)
  - [Cloud snapshot pitfalls](#cloud-snapshot-pitfalls)
  - [Common DBA mistakes](#common-dba-mistakes)
  - [Best practices for tablespace safety](#best-practices-for-tablespace-safety)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>



## In simple words

- Tablespaces allow PGSQL to store data **outside the main `PGDATA` directory**.
- This improves flexibility and performance, but it **greatly increases backup risk** if not handled carefully.
- Most broken physical backups involve tablespaces.

---

<br>
<br>

## What a tablespace really is

**A tablespace is:**
* a directory on disk
* located outside `PGDATA`
* linked internally via `pg_tblspc`

**PGDQL uses tablespaces to:**
* spread I/O across disks
* store large tables separately
* manage storage growth

---

<br>
<br>

## Why tablespaces complicate backups

**When tablespaces exist:**
* data is spread across multiple filesystems
* `PGDATA` alone is incomplete
* restoring only `PGDATA` breaks the database

Every tablespace directory is part of the physical backup.

---

<br>
<br>

## How PostgreSQL tracks tablespaces

**Inside PGDATA:**
* `pg_tblspc` contains symbolic links
* links point to external directories

**If these directories are missing during restore:**
* PostgreSQL fails to start

---

<br>
<br>

## Offline backup with tablespaces

**For offline backups:**
* stop PGSQL
* copy `PGDATA`
* copy **all tablespace directories**

**Restore requires:**
* same directory paths
* same ownership and permissions

Missing any tablespace is fatal.

---

<br>
<br>

## Online backup and tablespaces

**For online backups:**
* WAL must cover all tablespace writes
* snapshot or base backup must include every filesystem

Partial snapshots across filesystems cause corruption.

---

<br>
<br>

## Snapshot backups and ordering risk

Taking snapshots one volume at a time is dangerous.

**If:**
* `PGDATA` is snapshotted first
* tablespace disks snapshot later

**Then:**
* internal references mismatch
* restore may fail or corrupt

**Snapshots must be:**
* coordinated
* taken at the same moment

- A <mark><b>snapshot backup</b></mark> is a quick capture of data exactly as it looks at one moment in time. Instead of copying files, the storage system freezes the state and takes an instant point-in-time copy.

- A <mark><b>volume</b></mark> is a storage unit, like a disk or partition, where data lives. PGSQL can use multiple volumes, for example one for `PGDATA` and others for tablespaces.

The key idea is this: <mark><b>snapshots work at the volume level</b></mark>, not at the database level. If PGSQL data is spread across multiple volumes, all of them must be snapshotted at the same time, or the backup becomes unsafe.

- <mark><b>Snapshot backups are risky</b></mark> when volumes are snapshotted one by one instead of together. If `PGDATA` is captured first and tablespace disks are snapshotted later, internal references can go out of sync, which can cause restore failures or silent corruption. To be safe, snapshots must always be coordinated and taken at the exact same moment.

---

<br>
<br>

## Cloud snapshot pitfalls

**In cloud environments:**
* volumes are snapshotted independently
* snapshot timing differences matter

**DBAs must ensure:**
* all volumes are frozen together
* PostgreSQL backup mode is active

Cloud convenience hides real risk.

- <mark><b>In cloud environments</b></mark>, snapshots are taken per volume, and <mark><b>each volume is snapshotted independently</b></mark>. Even small timing differences between these snapshots can break database consistency. That’s why a DBA must make sure all volumes are frozen together and PostgreSQL backup mode is active during the snapshot. Cloud platforms make snapshots look easy, but that convenience hides real and serious risk if not handled properly.

---

<br>
<br>

## Common DBA mistakes

* forgetting to back up tablespaces
* assuming `pg_basebackup` includes external mounts automatically
* restoring tablespaces to wrong paths
* mixing snapshots from different times

These mistakes surface only during restore.

---

<br>
<br>

## Best practices for tablespace safety

* document all tablespaces
* standardize mount points
* include tablespaces in backup scripts
* test restore with tablespaces present

Tablespaces require discipline.

---

<br>
<br>

## Final mental model

* Tablespaces live outside `PGDATA`
* Backups must include every filesystem
* Snapshots must be coordinated
* Restore paths must match

---

<br>
<br>

## One-line explanation 

Tablespaces store PostgreSQL data outside `PGDATA`, requiring coordinated backups across multiple filesystems to avoid restore failures.


<br>
<br>
<br>
<br>

