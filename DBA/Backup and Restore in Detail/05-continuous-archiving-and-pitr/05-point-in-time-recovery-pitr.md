<center>

# 05 Point-in-Time Recovery (PITR) in PostgreSQL
</center>

<br>
<br>

- [05 Point-in-Time Recovery (PITR) in PostgreSQL](#05-point-in-time-recovery-pitr-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why PITR exists](#why-pitr-exists)
  - [What PITR actually needs](#what-pitr-actually-needs)
  - [How PITR works (high-level flow)](#how-pitr-works-high-level-flow)
  - [Choosing a recovery target](#choosing-a-recovery-target)
  - [Timestamp-based recovery example](#timestamp-based-recovery-example)
  - [What happens during WAL replay](#what-happens-during-wal-replay)
  - [Recovery targets and safety](#recovery-targets-and-safety)
  - [After recovery completes](#after-recovery-completes)
  - [Common PITR mistakes](#common-pitr-mistakes)
  - [Testing PITR](#testing-pitr)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

Point-in-Time Recovery (PITR) allows PGSQL to **rewind the database to an exact moment in time**.

**Instead of restoring only to the time of the last backup, PITR lets me restore to:**
* a specific timestamp
* just before a bad transaction
* the last known good state

This is the **real power** of WAL archiving.

---

<br>
<br>

## Why PITR exists

Backups alone restore databases to fixed points.

**Real incidents happen between backups**:
* accidental DELETE
* bad deployment
* faulty script

PITR exists so I can recover data **without losing hours of work**.

---

<br>
<br>

## What PITR actually needs

**PITR requires two things:**
1. a base backup
2. continuous WAL archive

If either is missing, PITR is impossible.

---

<br>
<br>

## How PITR works (high-level flow)

1. Restore base backup
2. PostgreSQL starts in recovery mode
3. WAL files are replayed sequentially
4. Replay stops at chosen recovery point
5. Database becomes usable

Recovery is deterministic and repeatable.

---

<br>
<br>

## Choosing a recovery target

**PostgreSQL allows recovery based on:**
* timestamp
* transaction ID
* named restore point

Most commonly, timestamp-based recovery is used.

---

<br>
<br>

## Timestamp-based recovery example

**If accident happened at `2025-02-10 11:37:00`, I recover to:**

```conf
recovery_target_time = '2025-02-10 11:36:59'
```

This restores the database to just before the mistake.

---

<br>
<br>

## What happens during WAL replay

**During recovery:**
* WAL changes are applied
* committed transactions are replayed
* uncommitted ones are skipped

PostgreSQL ensures consistency automatically.

---

<br>
<br>

## Recovery targets and safety

**Recovery stops when:**

* target time is reached
* or required WAL is missing

**If WAL is missing:**

* recovery fails
* data loss occurs

This is why WAL retention is critical.

---

<br>
<br>

## After recovery completes

**Once recovery stops:**
* PostgreSQL creates a new timeline
* old WAL history is preserved
* database starts accepting writes

Recovery cannot continue past this point unless re-restored.

---

<br>
<br>

## Common PITR mistakes

* missing WAL files
* wrong recovery target
* restoring into dirty PGDATA
* forgetting to switch to new timeline

Most PITR failures are procedural errors.

---

<br>
<br>

## Testing PITR

**A PITR setup must be tested:**

* simulate bad deletes
* recover to a time before error
* verify data correctness

Untested PITR is false confidence.

---

<br>
<br>

## Final mental model

* Base backup = starting point
* WAL archive = full history
* PITR = controlled rewind
* Testing = real safety

---

<br>
<br>

## One-line explanation 

Point-in-Time Recovery allows PostgreSQL to restore a database to an exact moment using a base backup and archived WAL files.



<br>
<br>
<br>
<br>


