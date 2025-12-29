<center>

# 05 WAL Requirement and Consistency in Physical Backups
</center>

<br>
<br>

- [05 WAL Requirement and Consistency in Physical Backups](#05-wal-requirement-and-consistency-in-physical-backups)
  - [In simple words](#in-simple-words)
  - [Why WAL exists](#why-wal-exists)
  - [Why WAL is critical for physical backups](#why-wal-is-critical-for-physical-backups)
  - [What “consistency” really means](#what-consistency-really-means)
  - [WAL and offline physical backups](#wal-and-offline-physical-backups)
  - [WAL and online physical backups](#wal-and-online-physical-backups)
  - [Required WAL for restore](#required-wal-for-restore)
  - [WAL retention during backup](#wal-retention-during-backup)
  - [WAL archiving and physical backups](#wal-archiving-and-physical-backups)
  - [Common WAL‑related mistakes](#common-walrelated-mistakes)
  - [DBA best practices](#dba-best-practices)
  - [Final mental model](#final-mental-model)
  - [One‑line explanation](#oneline-explanation)

<br>
<br>

## In simple words

- WAL (Write‑Ahead Log) is the **safety net** of PostgreSQL.
- Without WAL, physical backups are unreliable.
- With WAL, PostgreSQL can repair half‑written pages and reach a consistent state after restore.

**If you remember one thing:**

> **Physical backup without WAL is incomplete.**

---

<br>
<br>

## Why WAL exists

PGSQL never writes data pages directly and blindly.

**Flow:**

* change is written to WAL first
* WAL is flushed to disk
* data pages are written later

This guarantees crash safety and recovery.

---

<br>
<br>

## Why WAL is critical for physical backups

**During online physical backups:**
* files are copied while PGSQL is running
* some pages may be copied mid‑write
* data directory snapshot may look inconsistent

**WAL allows PGSQL to:**
* replay changes
* fix partial writes
* make the backup usable

Without WAL, restore may fail or corrupt data silently.

---

<br>
<br>

## What “consistency” really means

**Consistency means:**
* all committed transactions are present
* no partial transactions exist
* database behaves like a real point in time

WAL is what enforces this during restore.

---

<br>
<br>

## WAL and offline physical backups

**When PostgreSQL is stopped:**
* no writes happen
* data files are consistent

**In this case:**
* WAL replay is minimal
* offline backup is naturally consistent

Still, WAL files are usually included for safety.

---

<br>
<br>

## WAL and online physical backups

**For online backups:**
* WAL is mandatory
* PostgreSQL increases WAL generation
* full‑page writes protect torn pages

Restore without required WAL segments will fail.

---

<br>
<br>

## Required WAL for restore

**To restore a physical backup, PGSQL needs:**
* WAL up to the backup end
* WAL required for crash recovery

**Missing WAL leads to:**
* startup failure
* recovery abort

---

<br>
<br>

## WAL retention during backup

**During backup:**
* PGSQL prevents WAL removal
* WAL accumulates until backup completes

**If disk space is insufficient:**
* WAL directory can fill
* database may stop

Monitoring WAL size is mandatory.

---

<br>
<br>

## WAL archiving and physical backups

**In production:**
* WAL archiving is usually enabled
* archived WALs support PITR

Physical backups + archived WAL = full recovery chain.

---

<br>
<br>

## Common WAL‑related mistakes

* deleting WAL files manually
* underestimating WAL growth during backup
* assuming snapshots don’t need WAL
* restoring backup without matching WAL timeline

These cause real outages.

---

<br>
<br>

## DBA best practices

* never touch `pg_wal` manually
* monitor WAL growth during backups
* ensure archive destination has space
* test restore with WAL replay

---

<br>
<br>

## Final mental model

* WAL = change history
* Physical backup = file snapshot
* Restore = file copy + WAL replay
* Consistency comes from WAL

---

<br>
<br>

## One‑line explanation 

WAL ensures physical backups can be restored to a consistent state by replaying changes and fixing incomplete writes.


<br>
<br>
<br>
<br>

