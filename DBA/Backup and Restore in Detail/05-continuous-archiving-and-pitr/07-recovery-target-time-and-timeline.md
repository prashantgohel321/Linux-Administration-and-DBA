<center>

# 07 Recovery Target Time and Timeline (Deep PITR Behavior)
</center>

<br>
<br>

- [07 Recovery Target Time and Timeline (Deep PITR Behavior)](#07-recovery-target-time-and-timeline-deep-pitr-behavior)
  - [In simple words](#in-simple-words)
  - [What is a recovery target](#what-is-a-recovery-target)
  - [Types of recovery targets](#types-of-recovery-targets)
    - [recovery\_target\_time](#recovery_target_time)
    - [`recovery_target_xid`](#recovery_target_xid)
    - [`recovery_target_name`](#recovery_target_name)
  - [What happens during recovery replay](#what-happens-during-recovery-replay)
  - [What is a timeline](#what-is-a-timeline)
  - [Why timelines are necessary](#why-timelines-are-necessary)
  - [Timeline files in WAL archive](#timeline-files-in-wal-archive)
  - [Restoring multiple times (important behavior)](#restoring-multiple-times-important-behavior)
  - [Common mistakes with recovery targets](#common-mistakes-with-recovery-targets)
  - [DBA best practices](#dba-best-practices)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

**During Point‑in‑Time Recovery (PITR), PostgreSQL needs two decisions:**

1. **Where to stop recovery**
2. **Which history (timeline) to follow**

These are controlled by recovery targets and timelines.

Understanding this avoids accidental data loss during repeated restores.

---

<br>
<br>

## What is a recovery target

**A recovery target tells PostgreSQL:**
- “Stop replaying WAL at this exact point.”

**Without a recovery target:**
* PostgreSQL replays WAL until the latest available WAL
* database recovers to the most recent state

**With a recovery target:**
* recovery stops earlier, by choice

---

<br>
<br>

## Types of recovery targets

**PostgreSQL supports multiple recovery targets:**

### recovery_target_time

Recover to a specific timestamp.

```conf
recovery_target_time = '2025-02-10 11:36:59'
```

Most commonly used option.

---

<br>
<br>

### `recovery_target_xid`

Recover up to a specific transaction ID.

```conf
recovery_target_xid = '1234567'
```

Used when the exact failing transaction is known.

---

<br>
<br>

### `recovery_target_name`

Recover to a named restore point.

```sql
SELECT pg_create_restore_point('before_deploy');
```

```conf
recovery_target_name = 'before_deploy'
```

Useful during planned risky operations.

---

<br>
<br>

## What happens during recovery replay

**During recovery:**
* WAL is replayed sequentially
* PostgreSQL checks each record
* stops when the recovery target is reached

Committed transactions before target are applied.

Committed transactions after target are ignored.

---

<br>
<br>

## What is a timeline

A timeline represents a **history branch** of the database.

Every PostgreSQL cluster starts on timeline 1.

**Whenever recovery completes:**
* PostgreSQL creates a new timeline
* future WAL belongs to the new timeline

---

<br>
<br>

## Why timelines are necessary

Timelines prevent accidental overwriting of history.

**Example:**
* timeline 1 → original database
* timeline 2 → recovered version

Both histories coexist safely.

---

<br>
<br>

## Timeline files in WAL archive

**Timeline information is stored in:**
* `.history` files

**PostgreSQL reads these to:**
* choose correct WAL path
* avoid mixing histories

Missing history files cause recovery failure.

---

<br>
<br>

## Restoring multiple times (important behavior)

**If you restore again from the same base backup:**
* PostgreSQL creates another new timeline
* old timeline remains unchanged

This is expected behavior, not a bug.

---

<br>
<br>

## Common mistakes with recovery targets

* choosing wrong timestamp
* forgetting timezone differences
* missing WAL beyond target
* assuming restore can continue forward later

Recovery stops permanently at the target.

---

<br>
<br>

## DBA best practices

* always note incident time accurately
* prefer `recovery_target_time`
* keep full WAL history
* understand timeline branching

---

<br>
<br>

## Final mental model

* Recovery target = stopping point
* WAL replay = rewind mechanism
* Timeline = history branch
* New writes = new future

---

<br>
<br>

## One-line explanation

Recovery targets define where PITR stops, and timelines ensure PostgreSQL safely branches database history after recovery.



<br>
<br>
<br>
<br>



