<center>

# 01 What Is a Physical Backup in PostgreSQL
</center>

<br>
<br>

- [01 What Is a Physical Backup in PostgreSQL](#01-what-is-a-physical-backup-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why physical backups exist](#why-physical-backups-exist)
  - [What a physical backup actually includes](#what-a-physical-backup-actually-includes)
  - [What physical backups do NOT include](#what-physical-backups-do-not-include)
  - [Offline vs online physical backups](#offline-vs-online-physical-backups)
    - [Offline physical backup](#offline-physical-backup)
    - [Online physical backup](#online-physical-backup)
  - [The role of WAL in physical backups](#the-role-of-wal-in-physical-backups)
  - [Common tools for physical backups](#common-tools-for-physical-backups)
  - [Why physical backups are fast to restore](#why-physical-backups-are-fast-to-restore)
  - [Limitations of physical backups](#limitations-of-physical-backups)
  - [When I use physical backups](#when-i-use-physical-backups)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

- A physical backup is a **byte-by-byte copy of PostgreSQL’s data files**.
- It does not rebuild the database using SQL.
- It **clones the database exactly as it exists on disk**.
- This is why physical backups restore much faster than logical backups.

---

<br>
<br>

## Why physical backups exist

Logical backups rebuild databases.
That is slow for large systems.

**Physical backups exist to:**

* restore very fast
* preserve exact on-disk state
* support point-in-time recovery (PITR)
* handle large databases reliably

At scale, physical backups become mandatory.

---

<br>
<br>

## What a physical backup actually includes

**A physical backup copies:**

* table and index files
* system catalogs
* visibility maps and FSM
* control files
* required WAL files

Everything under `$PGDATA` matters.

This is a **cluster-level backup**, not database-level.

---

<br>
<br>

## What physical backups do NOT include

**Physical backups do not include:**

* OS packages
* PostgreSQL config outside PGDATA (sometimes)
* external scripts
* monitoring tools

DBAs must back these up separately if needed.

---

<br>
<br>

## Offline vs online physical backups

### Offline physical backup

* PostgreSQL is stopped
* files are copied
* consistency is guaranteed

This is simple but causes downtime.

---

<br>
<br>

### Online physical backup

* PostgreSQL keeps running
* files are copied while users work
* WAL ensures consistency

This avoids downtime but needs careful planning.

---

<br>
<br>

## The role of WAL in physical backups

**When PostgreSQL runs:**

* data pages may be half-written
* files can be inconsistent during copy

WAL solves this.

**During restore:**

* PostgreSQL replays WAL
* fixes partial writes
* reaches a consistent state

Without WAL, online physical backups are unusable.

---

<br>
<br>

## Common tools for physical backups

* `pg_basebackup`
* filesystem snapshot tools (LVM, cloud snapshots)
* custom rsync-based scripts (carefully)

Each tool relies on WAL for safety.

---

<br>
<br>

## Why physical backups are fast to restore

**Restore steps:**

* place files back into PGDATA
* start PostgreSQL
* replay WAL

No table rebuilds.
No index recreation.

Speed is the biggest advantage.

---

<br>
<br>

## Limitations of physical backups

**Physical backups:**

* must match PostgreSQL major version
* require similar architecture
* cannot restore single tables

They trade flexibility for speed.

---

<br>
<br>

## When I use physical backups

**I use physical backups when:**

* database is large
* fast recovery is required
* PITR is needed
* downtime must be minimal

They are the backbone of production recovery.

---

<br>
<br>

## Final mental model

* Physical backup = exact clone
* WAL = safety net
* Restore = file copy + WAL replay
* Speed beats flexibility

---

<br>
<br>

## One-line explanation

A physical backup copies PostgreSQL’s data files directly and restores them quickly using WAL replay for consistency.



<br>
<br>
<br>
<br>


