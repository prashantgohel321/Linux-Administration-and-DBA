<center>

# 04 WAL Archiving Flow and Internals (How PostgreSQL Moves WAL)
</center>

<br>
<br>

- [04 WAL Archiving Flow and Internals (How PostgreSQL Moves WAL)](#04-wal-archiving-flow-and-internals-how-postgresql-moves-wal)
  - [In simple words](#in-simple-words)
  - [WAL lifecycle at a high level](#wal-lifecycle-at-a-high-level)
  - [How a WAL segment is created](#how-a-wal-segment-is-created)
  - [When a WAL becomes archive-ready](#when-a-wal-becomes-archive-ready)
  - [`archive_command` execution flow](#archive_command-execution-flow)
  - [What happens on archive failure](#what-happens-on-archive-failure)
  - [How PGSQL knows WAL is archived](#how-pgsql-knows-wal-is-archived)
  - [WAL recycling vs archiving](#wal-recycling-vs-archiving)
  - [Timelines (basic concept)](#timelines-basic-concept)
  - [Why timelines matter](#why-timelines-matter)
  - [Where DBAs get confused](#where-dbas-get-confused)
  - [DBA debugging checklist](#dba-debugging-checklist)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

WAL archiving is not magic.

**PGSQL follows a strict lifecycle for every WAL segment:**
* create
* write
* close
* archive
* recycle

Understanding this flow is the key to debugging PITR issues.

---

<br>
<br>

## WAL lifecycle at a high level

**Each WAL segment goes through these stages:**

1. active in `pg_wal`
2. completed and ready to archive
3. archived successfully
4. recycled or removed

Archiving decides when a WAL is safe to delete.


<br>

- At a high level, each WAL segment has a simple life cycle. It is first actively **written inside `pg_wal`**, then it gets completed and **becomes ready for archiving**. Once it is successfully archived, PGSQL knows it is safe, and only after that the **segment is recycled or removed**. Archiving is what decides when a WAL file can be safely deleted.

---

<br>
<br>

## How a WAL segment is created

* PGSQL writes changes continuously
* WAL files are written sequentially
* default WAL segment size is **16MB**

**While a WAL file is active:**

* it cannot be archived
* PostgreSQL keeps writing to it

<br>

- PGSQL writes all changes continuously into WAL, and it always writes WAL files in a sequential order. Each WAL segment has a fixed size, which by default is 16 MB. 
- While a WAL file is active and still being written to, it cannot be archived, so PGSQL keeps appending changes to it until it becomes full and is closed.

---

<br>
<br>

## When a WAL becomes archive-ready

**A WAL segment becomes archive-ready when:**
* it is completely filled, or
* PGSQL switches to a new WAL file

**At this point:**
* PGSQL calls `archive_command`
* the WAL file is copied to archive storage

---

<br>
<br>

## `archive_command` execution flow

**For each completed WAL file:**
* PostgreSQL runs `archive_command`
* passes `%p` (path) and `%f` (filename)
* waits for success

**If the command fails:**
* WAL is retried
* WAL is not removed

This guarantees no WAL is lost silently.

---

<br>
<br>

## What happens on archive failure

**If archiving fails repeatedly:**
* WAL files accumulate in `pg_wal`
* disk usage grows
* database may stop accepting writes

This is one of the most common PITR-related outages.

---

<br>
<br>

## How PGSQL knows WAL is archived

**PGSQL tracks:**
* successful archive operations
* failed archive attempts

You can inspect this using:

```sql
SELECT * FROM pg_stat_archiver;
```

This view is your first stop during debugging.

---

<br>
<br>

## WAL recycling vs archiving

**Without archiving:**
* WAL files are reused when safe

**With archiving enabled:**
* WAL files are kept until archived
* recycling waits for archive success

Archiving changes WAL cleanup behavior.

---

<br>
<br>

## Timelines (basic concept)

Each recovery creates a new **timeline**.

**Timelines allow:**
* divergence from old history
* safe recovery without overwriting past states

WAL files belong to specific timelines.

---

<br>
<br>

## Why timelines matter

**During PITR:**
* PostgreSQL selects correct WAL timeline
* old timelines are preserved

Mixing WAL from different timelines causes restore failure.

---

<br>
<br>

## Where DBAs get confused

**Common confusion points:**
* WAL files not disappearing
* pg_wal growing endlessly
* archive directory filling up

These are symptoms, not bugs.

---

<br>
<br>

## DBA debugging checklist

**When WAL archiving issues occur, I chec**k:
* `pg_stat_archiver`
* archive_command exit behavior
* disk space on archive destination
* permissions

Most issues are operational, not PostgreSQL bugs.

---

<br>
<br>

## Final mental model

* WAL flows forward
* Archiving freezes history
* Recycling waits for safety
* Timelines protect recovery paths

---

<br>
<br>

## One-line explanation

PostgreSQL archives WAL segments only after they are completed, using `archive_command`, and manages retention through strict lifecycle and timeline rules.


<br>
<br>
<br>
<br>


