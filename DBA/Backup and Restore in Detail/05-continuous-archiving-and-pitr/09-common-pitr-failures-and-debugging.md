<center>

# 09 Common PITR Failures and Debugging (PostgreSQL)
</center>

<br>
<br>

- [09 Common PITR Failures and Debugging (PostgreSQL)](#09-common-pitr-failures-and-debugging-postgresql)
  - [In simple words](#in-simple-words)
  - [Failure 1: Recovery does not start at all](#failure-1-recovery-does-not-start-at-all)
    - [Symptom](#symptom)
    - [Root cause](#root-cause)
    - [Fix](#fix)
  - [Failure 2: Recovery starts but stops immediately](#failure-2-recovery-starts-but-stops-immediately)
    - [Symptom](#symptom-1)
    - [Root cause](#root-cause-1)
    - [Fix](#fix-1)
  - [Failure 3: Recovery waits forever](#failure-3-recovery-waits-forever)
    - [Symptom](#symptom-2)
    - [Root cause](#root-cause-2)
    - [Debug](#debug)
  - [Failure 4: restore\_command fails silently](#failure-4-restore_command-fails-silently)
    - [Symptom](#symptom-3)
    - [Root cause](#root-cause-3)
    - [Debug](#debug-1)
  - [Failure 5: Wrong recovery target time](#failure-5-wrong-recovery-target-time)
    - [Symptom](#symptom-4)
    - [Root cause](#root-cause-4)
    - [Fix](#fix-2)
  - [Failure 6: Missing timeline history file](#failure-6-missing-timeline-history-file)
    - [Symptom](#symptom-5)
    - [Root cause](#root-cause-5)
    - [Fix](#fix-3)
  - [Failure 7: WAL archive filled disk](#failure-7-wal-archive-filled-disk)
    - [Symptom](#symptom-6)
    - [Root cause](#root-cause-6)
    - [Fix](#fix-4)
  - [Failure 8: Restoring into dirty PGDATA](#failure-8-restoring-into-dirty-pgdata)
    - [Symptom](#symptom-7)
    - [Root cause](#root-cause-7)
    - [Fix](#fix-5)
  - [Failure 9: PITR works once, fails later](#failure-9-pitr-works-once-fails-later)
    - [Symptom](#symptom-8)
    - [Root cause](#root-cause-8)
    - [Fix](#fix-6)
  - [DBA debugging checklist](#dba-debugging-checklist)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

Most PITR failures are not PostgreSQL bugs.

They are **missing files, wrong configs, or bad assumptions**.

This file lists the failures DBAs actually hit and how to debug them calmly.

---

## Failure 1: Recovery does not start at all

### Symptom

* PostgreSQL starts normally
* No WAL replay
* Database opens immediately

<br>
<br>

### Root cause

* `recovery.signal` file missing

<br>
<br>

### Fix

* Place an empty `recovery.signal` file in PGDATA
* Restart PostgreSQL

PostgreSQL does not guess recovery intent.

---

<br>
<br>

## Failure 2: Recovery starts but stops immediately

### Symptom

* Recovery messages appear
* Recovery exits very fast

<br>
<br>

### Root cause

* No recovery target set
* Or WAL archive empty

<br>
<br>

### Fix

* Verify WAL files exist
* Set proper `recovery_target_*`

---

<br>
<br>

## Failure 3: Recovery waits forever

### Symptom

* PostgreSQL stays in recovery
* Repeats WAL fetch attempts

<br>
<br>

### Root cause

* Missing required WAL file
* restore_command cannot fetch WAL

<br>
<br>

### Debug

* Check PostgreSQL logs
* Validate archive path
* Test restore_command manually

---

<br>
<br>

## Failure 4: restore_command fails silently

### Symptom

* `pg_wal` requests WAL
* archive directory has files
* recovery still fails

<br>
<br>

### Root cause

* restore_command returns non-zero
* permission or path issue

<br>
<br>

### Debug

```bash
# test manually
cp /backup/wal_archive/WALFILE /tmp/test
```

Fix permissions or command syntax.

---

<br>
<br>

## Failure 5: Wrong recovery target time

### Symptom

* Data still missing
* Or bad data still present

<br>
<br>

### Root cause

* Wrong timestamp
* Timezone confusion

<br>
<br>

### Fix

* Check `timezone` setting
* Confirm application log time

One-minute mistake = wrong recovery.

---

<br>
<br>

## Failure 6: Missing timeline history file

### Symptom

* Recovery aborts with timeline error

<br>
<br>

### Root cause

* `.history` file missing in archive

<br>
<br>

### Fix

* Ensure timeline history files are archived
* Never delete `.history` files

---

<br>
<br>

## Failure 7: WAL archive filled disk

### Symptom

* Archiving stops
* Database slows or stops

<br>
<br>

### Root cause

* No retention policy
* Archive destination full

<br>
<br>

### Fix

* Clean old WAL safely
* Implement retention automation

---

<br>
<br>

## Failure 8: Restoring into dirty PGDATA

### Symptom

* Random startup errors
* Inconsistent state

<br>
<br>

### Root cause

* Old files mixed with restored files

<br>
<br>

### Fix

* Always restore into empty PGDATA
* Never overlay restore

---

<br>
<br>

## Failure 9: PITR works once, fails later

### Symptom

* First restore works
* Second restore fails

<br>
<br>

### Root cause

* Wrong timeline selected
* Old WAL reused incorrectly

<br>
<br>

### Fix

* Restore from base backup again
* Respect timeline branching

---

<br>
<br>

## DBA debugging checklist

**When PITR fails, I check:**
* PostgreSQL logs (first)
* `pg_stat_archiver`
* WAL archive content
* recovery settings
* timestamps and timeline

Logs always tell the truth.

---

<br>
<br>

## Final mental model

* PITR failures are procedural
* WAL and timelines are fragile
* Logs are your guide
* Calm debugging wins

---

<br>
<br>

## One-line explanation

Most PITR failures occur due to missing WAL files, incorrect recovery configuration, or timeline mismatches rather than PostgreSQL bugs.
