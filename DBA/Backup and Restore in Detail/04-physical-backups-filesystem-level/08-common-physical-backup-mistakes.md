<center>

# 08 Common Physical Backup Mistakes in PostgreSQL (Real-World Failures)
</center>

<br>
<br>

- [08 Common Physical Backup Mistakes in PostgreSQL (Real-World Failures)](#08-common-physical-backup-mistakes-in-postgresql-real-world-failures)
  - [In simple words](#in-simple-words)
  - [Mistake 1: Copying PGDATA while PostgreSQL is running](#mistake-1-copying-pgdata-while-postgresql-is-running)
  - [Mistake 2: Ignoring WAL during online backups](#mistake-2-ignoring-wal-during-online-backups)
  - [Mistake 3: Running out of disk due to WAL growth](#mistake-3-running-out-of-disk-due-to-wal-growth)
  - [Mistake 4: Forgetting tablespaces](#mistake-4-forgetting-tablespaces)
  - [Mistake 5: Inconsistent snapshots across filesystems](#mistake-5-inconsistent-snapshots-across-filesystems)
  - [Mistake 6: Restoring to different paths or permissions](#mistake-6-restoring-to-different-paths-or-permissions)
  - [Mistake 7: Mixing PostgreSQL versions](#mistake-7-mixing-postgresql-versions)
  - [Mistake 8: No restore testing](#mistake-8-no-restore-testing)
  - [Mistake 9: Deleting WAL files manually](#mistake-9-deleting-wal-files-manually)
  - [Mistake 10: Overconfidence in automation](#mistake-10-overconfidence-in-automation)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

- Physical backups are powerful, but also dangerous when done casually.
- Most PostgreSQL disaster stories happen not because physical backups are bad, but because **DBAs misunderstood or skipped critical steps**.
- This file lists the mistakes that actually cause data loss.

---

<br>
<br>

## Mistake 1: Copying PGDATA while PostgreSQL is running

**Some DBAs assume:**

> “`cp -r $PGDATA` is enough”

**If PGSQL is running:**
* files are changing
* pages may be half-written
* backup becomes inconsistent

This backup may restore but corrupt data silently.

**Correct approach:**
* stop PostgreSQL
* or use WAL-aware methods

---

<br>
<br>

## Mistake 2: Ignoring WAL during online backups

Online physical backups **require WAL**.

**Common wrong assumptions:**
* snapshot alone is enough
* crash recovery will fix everything

**Without required WAL:**
* restore fails
* or data corruption occurs

Never take online physical backups without WAL planning.

---

<br>
<br>

## Mistake 3: Running out of disk due to WAL growth

**During backup:**
* WAL retention increases
* archived WAL piles up

**If disk fills:**
* database may stop
* writes fail
* replication breaks

Monitoring WAL size during backups is mandatory.

---

<br>
<br>

## Mistake 4: Forgetting tablespaces

**Backing up only `PGDATA` while tablespaces exist:**
* misses real data
* breaks restore

This mistake is extremely common.

**Correct approach:**
* always inventory tablespaces
* back up all tablespace paths

---

<br>
<br>

## Mistake 5: Inconsistent snapshots across filesystems

**Snapshots taken at different times:**
* PGDATA snapshot now
* tablespace snapshot later

This creates mismatched states.

Restore may succeed but data will be wrong.

Snapshots must be coordinated.

---

## Mistake 6: Restoring to different paths or permissions

**Physical restore expects:**
* same directory layout
* correct ownership
* correct permissions

**Wrong paths or ownership:**
* PostgreSQL refuses to start
* recovery fails

Always match original environment.

---

<br>
<br>

## Mistake 7: Mixing PostgreSQL versions

Physical backups are version-specific.

**Restoring:**
* PG 14 backup into PG 15
* will fail

Upgrades require logical backups or pg_upgrade.

---

<br>
<br>

## Mistake 8: No restore testing

**Many teams:**
* take physical backups daily
* never test restore

Until the day recovery is needed.

Physical backups must be tested, especially with WAL replay.

---

<br>
<br>

## Mistake 9: Deleting WAL files manually

**Deleting WAL to free space:**
* breaks recovery chain
* makes backups unusable

WAL cleanup must be automated and controlled.

---

<br>
<br>

## Mistake 10: Overconfidence in automation

Automation hides failures.

**If:**
* scripts fail silently
* snapshot does not complete

You think backups exist, but they don’t.

Automation must include verification.

---

<br>
<br>

## Final mental model

* Physical backups are unforgiving
* WAL and tablespaces are critical
* Snapshots need coordination
* Testing is non-negotiable

---

<br>
<br>

## One-line explanation

Most physical backup failures in PostgreSQL occur due to WAL mishandling, missing tablespaces, inconsistent snapshots, or untested restore processes.
