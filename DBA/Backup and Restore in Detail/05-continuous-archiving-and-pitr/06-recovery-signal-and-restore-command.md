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


