# 05 Continuous Archiving and PITR



- [05 Continuous Archiving and PITR](#05-continuous-archiving-and-pitr)
- [01 Why WAL Archiving Exists (Foundation of PITR)](#01-why-wal-archiving-exists-foundation-of-pitr)
  - [In simple words](#in-simple-words)
  - [The problem without WAL archiving](#the-problem-without-wal-archiving)
  - [What WAL already does internally](#what-wal-already-does-internally)
  - [What WAL archiving means](#what-wal-archiving-means)
  - [Base backup + WAL = full recovery chain](#base-backup--wal--full-recovery-chain)
  - [What PITR really allows](#what-pitr-really-allows)
  - [Why WAL archiving is mandatory in production](#why-wal-archiving-is-mandatory-in-production)
  - [Common misunderstanding](#common-misunderstanding)
  - [Storage requirements](#storage-requirements)
  - [What WAL archiving does NOT replace](#what-wal-archiving-does-not-replace)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)
- [02 WAL Level, archive\_mode, and archive\_command (How WAL Archiving Actually Works)](#02-wal-level-archive_mode-and-archive_command-how-wal-archiving-actually-works)
  - [In simple words](#in-simple-words-1)
  - [Why configuration matters](#why-configuration-matters)
  - [`wal_level` (how much information WAL stores)](#wal_level-how-much-information-wal-stores)
    - [What `wal_level` means](#what-wal_level-means)
    - [Which `wal_level` is required](#which-wal_level-is-required)
  - [archive\_mode (turns archiving on)](#archive_mode-turns-archiving-on)
    - [What archive\_mode does](#what-archive_mode-does)
  - [`archive_command` (how WAL is archived)](#archive_command-how-wal-is-archived)
    - [What `archive_command` is](#what-archive_command-is)
  - [A simple `archive_command` example](#a-simple-archive_command-example)
  - [Why `archive_command` failures are dangerous](#why-archive_command-failures-are-dangerous)
  - [Testing WAL archiving](#testing-wal-archiving)
  - [Reload vs restart](#reload-vs-restart)
  - [Security and permissions](#security-and-permissions)
  - [Common DBA mistakes](#common-dba-mistakes)
  - [Final mental model](#final-mental-model-1)
  - [One-line explanation](#one-line-explanation-1)
- [03 Base Backup Using `pg_basebackup` (Foundation of PITR)](#03-base-backup-using-pg_basebackup-foundation-of-pitr)
  - [In simple words](#in-simple-words-2)
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
  - [Final mental model](#final-mental-model-2)
  - [One-line explanation](#one-line-explanation-2)
- [04 WAL Archiving Flow and Internals (How PostgreSQL Moves WAL)](#04-wal-archiving-flow-and-internals-how-postgresql-moves-wal)
  - [In simple words](#in-simple-words-3)
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
  - [Final mental model](#final-mental-model-3)
  - [One-line explanation](#one-line-explanation-3)
- [05 Point-in-Time Recovery (PITR) in PostgreSQL](#05-point-in-time-recovery-pitr-in-postgresql)
  - [In simple words](#in-simple-words-4)
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
  - [Final mental model](#final-mental-model-4)
  - [One-line explanation](#one-line-explanation-4)
- [06 recovery.signal and restore\_command (How PostgreSQL Enters Recovery)](#06-recoverysignal-and-restore_command-how-postgresql-enters-recovery)
  - [In simple words](#in-simple-words-5)
  - [How PostgreSQL decides to start recovery](#how-postgresql-decides-to-start-recovery)
  - [What is `recovery.signal`](#what-is-recoverysignal)
  - [Why `recovery.signal` exists](#why-recoverysignal-exists)
  - [What is restore\_command](#what-is-restore_command)
  - [`restore_command` execution flow](#restore_command-execution-flow)
  - [Common `restore_command` mistakes](#common-restore_command-mistakes)
  - [Full recovery setup example](#full-recovery-setup-example)
  - [What happens after recovery completes](#what-happens-after-recovery-completes)
  - [When recovery does NOT stop](#when-recovery-does-not-stop)
  - [DBA verification during recovery](#dba-verification-during-recovery)
  - [Final mental model](#final-mental-model-5)
  - [One-line explanation](#one-line-explanation-5)
- [07 Recovery Target Time and Timeline (Deep PITR Behavior)](#07-recovery-target-time-and-timeline-deep-pitr-behavior)
  - [In simple words](#in-simple-words-6)
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
  - [Final mental model](#final-mental-model-6)
  - [One-line explanation](#one-line-explanation-6)
- [08 PITR – Real-Life Disaster Scenario (How DBAs Actually Use It)](#08-pitr--real-life-disaster-scenario-how-dbas-actually-use-it)
  - [In simple words](#in-simple-words-7)
  - [The real situation (very common)](#the-real-situation-very-common)
  - [Immediate reality check](#immediate-reality-check)
  - [First rule: stop the damage](#first-rule-stop-the-damage)
  - [Identify the recovery point](#identify-the-recovery-point)
  - [Choose recovery strategy](#choose-recovery-strategy)
  - [High-level recovery plan](#high-level-recovery-plan)
  - [Step 1: Restore base backup](#step-1-restore-base-backup)
  - [Step 2: Configure PITR](#step-2-configure-pitr)
  - [Step 3: Start PostgreSQL](#step-3-start-postgresql)
  - [Step 4: New timeline is created](#step-4-new-timeline-is-created)
  - [Step 5: Validate data](#step-5-validate-data)
  - [Outcome](#outcome)
  - [What would happen without PITR](#what-would-happen-without-pitr)
  - [Lessons every DBA must learn](#lessons-every-dba-must-learn)
  - [Final mental model](#final-mental-model-7)
  - [One-line explanation](#one-line-explanation-7)
- [09 Common PITR Failures and Debugging (PostgreSQL)](#09-common-pitr-failures-and-debugging-postgresql)
  - [In simple words](#in-simple-words-8)
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
  - [DBA debugging checklist](#dba-debugging-checklist-1)
  - [Final mental model](#final-mental-model-8)
  - [One-line explanation](#one-line-explanation-8)

<br>
<br>

<center>

# 01 Why WAL Archiving Exists (Foundation of PITR)
</center>


<br>
<br>

## In simple words

- WAL archiving exists so PostgreSQL can **go back in time**.
- A normal backup gives you one fixed restore point.
- WAL archiving gives you **every change after that point**.
- This is what enables **Point-In-Time Recovery (PITR)**.

---

<br>
<br>

## The problem without WAL archiving

**Imagine this:**
* Full backup taken at 01:00 AM
* Accident happens at 11:37 AM

**Without WAL archiving:**
* you can restore only till 01:00 AM
* you lose ~10 hours of data

For many businesses, this data loss is unacceptable.

---

<br>
<br>

## What WAL already does internally

**PostgreSQL always writes changes in this order:**
* change is written to WAL
* WAL is flushed to disk
* data pages are written later

So WAL already contains **complete change history**.

WAL archiving simply **preserves this history instead of deleting it**.

---

<br>
<br>

## What WAL archiving means

**WAL archiving means:**
* completed WAL files are copied
* copied to a safe external location
* before PostgreSQL removes them

This creates a continuous timeline of changes.

---

<br>
<br>

## Base backup + WAL = full recovery chain

**Think in two parts:**

**1. Base backup**
* gives starting point
* file-level snapshot of database

**2. Archived WAL files**
* describe every change after backup

Together, they allow recovery to **any moment after the base backup**.

---

<br>
<br>

## What PITR really allows

**With WAL archiving, I can:**
* recover to a specific timestamp
* recover before a bad transaction
* recover to last known good state

This is impossible with backups alone.

---

<br>
<br>

## Why WAL archiving is mandatory in production

**In real systems:**
* human mistakes happen
* scripts fail
* bugs delete data

**WAL archiving:**
* minimizes data loss
* gives DBAs confidence
* reduces panic during incidents

Senior DBAs treat it as mandatory.

---

<br>
<br>

## Common misunderstanding

**Myth:**
> “I have daily backups, that’s enough”

**Reality:**
* backups define recovery *points*
* WAL defines recovery *continuity*

Both are needed for real protection.

---

<br>
<br>

## Storage requirements

**WAL archiving requires:**
* reliable storage
* enough space
* cleanup/retention policy

If archive storage fails, PITR fails.

---

<br>
<br>

## What WAL archiving does NOT replace

**WAL archiving:**
* does NOT replace base backups
* does NOT replace logical backups
* does NOT store configuration files

It complements backups, it doesn’t replace them.

---

<br>
<br>

## Final mental model

* Base backup = starting line
* WAL files = change timeline
* PITR = choose your restore moment
* Archiving = safety guarantee

---

<br>
<br>

## One-line explanation 

WAL archiving preserves PostgreSQL change history so databases can be restored to any point in time after a base backup.


<br>
<br>
<br>
<br>


<center>

# 02 WAL Level, archive_mode, and archive_command (How WAL Archiving Actually Works)
</center>

<br>
<br>


- [05 Continuous Archiving and PITR](#05-continuous-archiving-and-pitr)
- [01 Why WAL Archiving Exists (Foundation of PITR)](#01-why-wal-archiving-exists-foundation-of-pitr)
  - [In simple words](#in-simple-words)
  - [The problem without WAL archiving](#the-problem-without-wal-archiving)
  - [What WAL already does internally](#what-wal-already-does-internally)
  - [What WAL archiving means](#what-wal-archiving-means)
  - [Base backup + WAL = full recovery chain](#base-backup--wal--full-recovery-chain)
  - [What PITR really allows](#what-pitr-really-allows)
  - [Why WAL archiving is mandatory in production](#why-wal-archiving-is-mandatory-in-production)
  - [Common misunderstanding](#common-misunderstanding)
  - [Storage requirements](#storage-requirements)
  - [What WAL archiving does NOT replace](#what-wal-archiving-does-not-replace)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)
- [02 WAL Level, archive\_mode, and archive\_command (How WAL Archiving Actually Works)](#02-wal-level-archive_mode-and-archive_command-how-wal-archiving-actually-works)
  - [In simple words](#in-simple-words-1)
  - [Why configuration matters](#why-configuration-matters)
  - [`wal_level` (how much information WAL stores)](#wal_level-how-much-information-wal-stores)
    - [What `wal_level` means](#what-wal_level-means)
    - [Which `wal_level` is required](#which-wal_level-is-required)
  - [archive\_mode (turns archiving on)](#archive_mode-turns-archiving-on)
    - [What archive\_mode does](#what-archive_mode-does)
  - [`archive_command` (how WAL is archived)](#archive_command-how-wal-is-archived)
    - [What `archive_command` is](#what-archive_command-is)
  - [A simple `archive_command` example](#a-simple-archive_command-example)
  - [Why `archive_command` failures are dangerous](#why-archive_command-failures-are-dangerous)
  - [Testing WAL archiving](#testing-wal-archiving)
  - [Reload vs restart](#reload-vs-restart)
  - [Security and permissions](#security-and-permissions)
  - [Common DBA mistakes](#common-dba-mistakes)
  - [Final mental model](#final-mental-model-1)
  - [One-line explanation](#one-line-explanation-1)
- [03 Base Backup Using `pg_basebackup` (Foundation of PITR)](#03-base-backup-using-pg_basebackup-foundation-of-pitr)
  - [In simple words](#in-simple-words-2)
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
  - [Final mental model](#final-mental-model-2)
  - [One-line explanation](#one-line-explanation-2)
- [04 WAL Archiving Flow and Internals (How PostgreSQL Moves WAL)](#04-wal-archiving-flow-and-internals-how-postgresql-moves-wal)
  - [In simple words](#in-simple-words-3)
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
  - [Final mental model](#final-mental-model-3)
  - [One-line explanation](#one-line-explanation-3)
- [05 Point-in-Time Recovery (PITR) in PostgreSQL](#05-point-in-time-recovery-pitr-in-postgresql)
  - [In simple words](#in-simple-words-4)
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
  - [Final mental model](#final-mental-model-4)
  - [One-line explanation](#one-line-explanation-4)
- [06 recovery.signal and restore\_command (How PostgreSQL Enters Recovery)](#06-recoverysignal-and-restore_command-how-postgresql-enters-recovery)
  - [In simple words](#in-simple-words-5)
  - [How PostgreSQL decides to start recovery](#how-postgresql-decides-to-start-recovery)
  - [What is `recovery.signal`](#what-is-recoverysignal)
  - [Why `recovery.signal` exists](#why-recoverysignal-exists)
  - [What is restore\_command](#what-is-restore_command)
  - [`restore_command` execution flow](#restore_command-execution-flow)
  - [Common `restore_command` mistakes](#common-restore_command-mistakes)
  - [Full recovery setup example](#full-recovery-setup-example)
  - [What happens after recovery completes](#what-happens-after-recovery-completes)
  - [When recovery does NOT stop](#when-recovery-does-not-stop)
  - [DBA verification during recovery](#dba-verification-during-recovery)
  - [Final mental model](#final-mental-model-5)
  - [One-line explanation](#one-line-explanation-5)
- [07 Recovery Target Time and Timeline (Deep PITR Behavior)](#07-recovery-target-time-and-timeline-deep-pitr-behavior)
  - [In simple words](#in-simple-words-6)
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
  - [Final mental model](#final-mental-model-6)
  - [One-line explanation](#one-line-explanation-6)
- [08 PITR – Real-Life Disaster Scenario (How DBAs Actually Use It)](#08-pitr--real-life-disaster-scenario-how-dbas-actually-use-it)
  - [In simple words](#in-simple-words-7)
  - [The real situation (very common)](#the-real-situation-very-common)
  - [Immediate reality check](#immediate-reality-check)
  - [First rule: stop the damage](#first-rule-stop-the-damage)
  - [Identify the recovery point](#identify-the-recovery-point)
  - [Choose recovery strategy](#choose-recovery-strategy)
  - [High-level recovery plan](#high-level-recovery-plan)
  - [Step 1: Restore base backup](#step-1-restore-base-backup)
  - [Step 2: Configure PITR](#step-2-configure-pitr)
  - [Step 3: Start PostgreSQL](#step-3-start-postgresql)
  - [Step 4: New timeline is created](#step-4-new-timeline-is-created)
  - [Step 5: Validate data](#step-5-validate-data)
  - [Outcome](#outcome)
  - [What would happen without PITR](#what-would-happen-without-pitr)
  - [Lessons every DBA must learn](#lessons-every-dba-must-learn)
  - [Final mental model](#final-mental-model-7)
  - [One-line explanation](#one-line-explanation-7)
- [09 Common PITR Failures and Debugging (PostgreSQL)](#09-common-pitr-failures-and-debugging-postgresql)
  - [In simple words](#in-simple-words-8)
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
  - [DBA debugging checklist](#dba-debugging-checklist-1)
  - [Final mental model](#final-mental-model-8)
  - [One-line explanation](#one-line-explanation-8)


<br>
<br>

## In simple words

**To make WAL archiving work, PostgreSQL needs three settings to cooperate**:
* `wal_level`
* `archive_mode`
* `archive_command`

If even one is wrong, WAL archiving silently fails.

---

<br>
<br>

## Why configuration matters

PostgreSQL never guesses your intention.

**Unless these settings are explicitly correct:**
* WAL files are recycled
* change history is lost
* PITR becomes impossible

That’s why WAL archiving failures are usually **configuration failures**.

---

<br>
<br>

## `wal_level` (how much information WAL stores)

### What `wal_level` means

`wal_level` defines **how much detail** PostgreSQL writes into WAL.

**Common values:**

* `minimal` (*just survive crashes*)
* `replica` (*backups + replicas*)
* `logical` (*stream changes outside PGSQL*)

<br>
<br>

- `wal_level` decides how much information PGSQL writes into WAL.
- More information = more features, but also more WAL size.

<br>

- **`minimal`**: This writes only the bare minimum WAL needed for crash recovery. It’s lightweight and fast, but you <mark><b>cannot use replication or PITR</b></mark>. This is fine for simple, standalone databases where you only care about basic safety.

<br>

- **`replica`**: This writes enough WAL data <mark><b>to support physical replication and PITR</b></mark>. It’s the most common setting in production systems. You get crash recovery, replicas, and backups, with acceptable overhead.

<br>

- **`logical`**: This writes the most detailed WAL. In addition to everything in replica, it <mark><b>includes information needed for logical decoding</b></mark>. This <u><b>allows logical</b></u> <u><b>replication</b></u>, <u><b>change data capture</b></u>, and <u><b>streaming changes to external systems</b></u>. It produces more WAL but enables advanced architectures.

---

<br>
<br>

### Which `wal_level` is required

**For WAL archiving:**

```conf
wal_level = replica
```

**Why:**

* `minimal` does not generate enough WAL
* `replica` guarantees crash recovery and PITR

Logical replication requires `logical`, but PITR does not.

---

<br>
<br>

## archive_mode (turns archiving on)

### What archive_mode does

**`archive_mode` tells PostgreSQL:**

> “Do not delete WAL until it is archived somewhere safe.”

**Enable it with:**

```conf
archive_mode = on
```

Without this, PGSQL reuses WAL files automatically.

---

<br>
<br>

## `archive_command` (how WAL is archived)

### What `archive_command` is

`archive_command` is a **shell command** executed every time a WAL segment is completed.

**PostgreSQL runs it like:**

```bash
archive_command %p %f
```

**Where:**

* `%p` = full path to WAL file
* `%f` = WAL file name

---

<br>
<br>

## A simple `archive_command` example

```conf
archive_command = 'cp %p /backup/wal_archive/%f'
```

**Meaning:**
* copy WAL file to archive directory
* only mark success if command exits with 0

If command fails, PostgreSQL retries.

---

<br>
<br>

## Why `archive_command` failures are dangerous

**If `archive_command`:**
* returns non-zero
* hangs
* writes to full disk

**Then:**
* WAL is not archived
* WAL cannot be recycled
* `pg_wal` directory grows
* database may stop

This is a classic production outage.

---

<br>
<br>

## Testing WAL archiving

**Always verify:**

```sql
SELECT * FROM pg_stat_archiver;
```

**Check:**
* `archived_count` increases
* `failed_count` stays zero

Never trust configuration blindly.

---

<br>
<br>

## Reload vs restart

**Changes to these parameters require:**
* `wal_level` → restart
* `archive_mode` → restart
* `archive_command` → reload

Restart planning is required.

---

<br>
<br>

## Security and permissions

**`archive_command` runs as:**
* PostgreSQL OS user

**Ensure:**
* archive directory permissions are correct
* command cannot be exploited

Security mistakes here leak data.

---

<br>
<br>

## Common DBA mistakes

* forgetting restart after `wal_level` change
* wrong archive path
* no monitoring of archive failures
* assuming archive = backup

WAL archiving is only as good as its validation.

---

<br>
<br>

## Final mental model

* `wal_level` = how much history
* `archive_mode` = keep history
* `archive_command` = where history goes

All three must work together.

---

<br>
<br>

## One-line explanation

PostgreSQL WAL archiving depends on `wal_level` for data detail, `archive_mode` to enable archiving, and `archive_command` to store WAL files safely.

<br>
<br>
<br>
<br>



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



<center>

# 06 recovery.signal and restore_command (How PostgreSQL Enters Recovery)
</center>

<br>
<br>

- [06 recovery.signal and restore\_command (How PostgreSQL Enters Recovery)](#06-recoverysignal-and-restore_command-how-postgresql-enters-recovery)
  - [In simple words](#in-simple-words)
  - [How PostgreSQL decides to start recovery](#how-postgresql-decides-to-start-recovery)
  - [What is `recovery.signal`](#what-is-recoverysignal)
  - [Why `recovery.signal` exists](#why-recoverysignal-exists)
  - [What is restore\_command](#what-is-restore_command)
  - [`restore_command` execution flow](#restore_command-execution-flow)
  - [Common `restore_command` mistakes](#common-restore_command-mistakes)
  - [Full recovery setup example](#full-recovery-setup-example)
  - [What happens after recovery completes](#what-happens-after-recovery-completes)
  - [When recovery does NOT stop](#when-recovery-does-not-stop)
  - [DBA verification during recovery](#dba-verification-during-recovery)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

PGSQL does **not guess** when to perform recovery.

It enters recovery mode only when I explicitly tell it to.

**That signal comes from two things:**
* `recovery.signal`
* `restore_command`

If either is missing or wrong, recovery does not work.

---

<br>
<br>

## How PostgreSQL decides to start recovery

When PostgreSQL starts, it checks the data directory.

**If it finds:**
* `recovery.signal` → start recovery mode

**If it does not find it:**
* PostgreSQL starts normally
* WAL replay stops

This small file controls everything.

---

<br>
<br>

## What is `recovery.signal`

`recovery.signal` is an **empty file** placed in `PGDATA`.

**Its presence means:**
- “This cluster must recover using archived WAL.”

It replaces older `recovery.conf` (pre-PostgreSQL 12).

---

<br>
<br>

## Why `recovery.signal` exists

**Before PostgreSQL 12:**
* recovery was controlled by `recovery.conf`

**Now:**
* recovery settings live in `postgresql.conf`
* `recovery.signal` only triggers recovery mode

This simplifies startup logic.

---

<br>
<br>

## What is restore_command

**`restore_command` tells PostgreSQL:**
- “Where and how to fetch archived WAL files.”

It is a shell command executed during recovery.

**Example:**

```conf
restore_command = 'cp /backup/wal_archive/%f %p'
```

**Meaning**:

* `%f` = WAL file name
* `%p` = path where PostgreSQL expects WAL

---

<br>
<br>

## `restore_command` execution flow

**During recovery:**

* PostgreSQL requests next WAL file
* runs `restore_command`
* expects the file to be placed at `%p`

**If command succeeds:**
* WAL is replayed

**If command fails:**
* recovery stops

---

<br>
<br>

## Common `restore_command` mistakes

* wrong archive path
* incorrect permissions
* command returns non-zero
* missing WAL file

Any one of these breaks recovery.

---

<br>
<br>

## Full recovery setup example

**Steps:**

1. Restore base backup into PGDATA
2. Place `recovery.signal` file
3. Configure restore_command
4. (Optional) set recovery_target_time
5. Start PostgreSQL

PostgreSQL handles the rest.

---

<br>
<br>

## What happens after recovery completes

**Once recovery reaches its target:**

* PostgreSQL removes `recovery.signal`
* creates a new timeline
* starts accepting writes

Recovery mode ends automatically.

---

## When recovery does NOT stop

**Recovery keeps waiting when:**

* target WAL is not available
* `restore_command` cannot fetch WAL

PostgreSQL will keep retrying until WAL appears.

---

<br>
<br>

## DBA verification during recovery

**I monitor:**

* PostgreSQL logs
* recovery progress messages
* WAL fetch activity

Logs tell exactly what is missing.

---

<br>
<br>

## Final mental model

* `recovery.signal` = enter recovery
* `restore_command` = fetch WAL
* WAL replay = rebuild state
* new timeline = safe future

---

## One-line explanation 

PostgreSQL enters recovery mode when recovery.signal is present and uses restore_command to fetch archived WAL files during PITR.


<br>
<br>
<br>
<br>





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





<center>

# 08 PITR – Real-Life Disaster Scenario (How DBAs Actually Use It)
</center>

<br>
<br>

- [08 PITR – Real-Life Disaster Scenario (How DBAs Actually Use It)](#08-pitr--real-life-disaster-scenario-how-dbas-actually-use-it)
  - [In simple words](#in-simple-words)
  - [The real situation (very common)](#the-real-situation-very-common)
  - [Immediate reality check](#immediate-reality-check)
  - [First rule: stop the damage](#first-rule-stop-the-damage)
  - [Identify the recovery point](#identify-the-recovery-point)
  - [Choose recovery strategy](#choose-recovery-strategy)
  - [High-level recovery plan](#high-level-recovery-plan)
  - [Step 1: Restore base backup](#step-1-restore-base-backup)
  - [Step 2: Configure PITR](#step-2-configure-pitr)
  - [Step 3: Start PostgreSQL](#step-3-start-postgresql)
  - [Step 4: New timeline is created](#step-4-new-timeline-is-created)
  - [Step 5: Validate data](#step-5-validate-data)
  - [Outcome](#outcome)
  - [What would happen without PITR](#what-would-happen-without-pitr)
  - [Lessons every DBA must learn](#lessons-every-dba-must-learn)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

PITR sounds theoretical until **something really bad happens**.

This section walks through a **real production-style disaster** and shows how PITR saves data step by step — exactly how a DBA thinks and acts.

---

<br>
<br>

## The real situation (very common)

* Production PostgreSQL database
* WAL archiving enabled
* Nightly base backups running

**At 11:42 AM**:
* A developer runs a wrong DELETE query
* Critical data is deleted
* Transaction is committed

This is **not a crash**.

This is **human error**.

---

<br>
<br>

## Immediate reality check

**What we know:**
* Database is still running
* Data is already committed
* Normal rollback is impossible

**What we fear:**
* Waiting longer will overwrite more WAL
* Panic actions may make recovery harder

This is where PITR matters.

---

<br>
<br>

## First rule: stop the damage

**Before recovery planning:**
* stop application access
* prevent further writes

**Why:**
* every new write creates WAL
* more WAL makes recovery slower and riskier

Freezing the system is critical.

---

<br>
<br>

## Identify the recovery point

**We need to answer one question**:
- “To what exact moment should I restore?”

**Inputs used:**
* application logs
* developer statement
* PostgreSQL logs

**We decide:**
* bad DELETE happened at **11:42:10 AM**
* safe recovery time = **11:42:09 AM**

One second matters.

---

<br>
<br>

## Choose recovery strategy

**Options:**
* logical restore → too slow
* manual data repair → unreliable
* PITR → safest and fastest

**Decision:**
- Use PITR and rewind the database

---

<br>
<br>

## High-level recovery plan

**The plan is clear:**
1. Restore last base backup
2. Replay WAL up to 11:42:09
3. Start database on new timeline

Everything else is noise.

---

<br>
<br>

## Step 1: Restore base backup

**Actions:**
* stop PostgreSQL
* clean PGDATA
* restore last base backup files

This brings database back to **backup time**, not to the final state.

---

<br>
<br>

## Step 2: Configure PITR

**Key settings:**

```conf
restore_command = 'cp /backup/wal_archive/%f %p'
recovery_target_time = '2025-02-15 11:42:09'
```

**And place:**

```
recovery.signal
```

**This tells PostgreSQL:**

- “Replay WAL, but stop before the damage.”

---

<br>
<br>

## Step 3: Start PostgreSQL

**Now PostgreSQL:**

* enters recovery mode
* fetches WAL sequentially
* replays changes
* stops exactly at target time

Logs confirm recovery stop.

---

<br>
<br>

## Step 4: New timeline is created

**After recovery:**
* PostgreSQL creates a new timeline
* old history is preserved
* database starts accepting writes

This prevents accidental replay of bad WAL again.

---

<br>
<br>

## Step 5: Validate data

**Before opening to users:**
* verify row counts
* validate critical tables
* confirm deleted data is back

Never trust recovery blindly.

---

<br>
<br>

## Outcome

* Data loss avoided
* Downtime limited
* No manual fixes needed
* Audit trail preserved

This is exactly why PITR exists.

---

<br>
<br>

## What would happen without PITR

**Without PITR:**
* restore last night backup
* lose hours of data
* manual data recreation
* business impact

PITR converts disasters into incidents.

---

<br>
<br>

## Lessons every DBA must learn

* WAL archiving is non-negotiable
* knowing *when* to stop recovery matters
* calm, structured steps win over panic

Experience is built here.

---

<br>
<br>

## Final mental model

* Disaster = committed mistake
* PITR = rewind button
* WAL = time machine
* DBA = decision maker

---

<br>
<br>

## One-line explanation 

In a real PITR disaster, a DBA restores a base backup and replays WAL up to just before the damaging transaction to recover lost data safely.


<br>
<br>
<br>
<br>



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
