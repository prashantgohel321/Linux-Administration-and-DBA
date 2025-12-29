<center>

# 03 Offline Filesystem Backup – Step by Step (PostgreSQL)
</center>

<br>
<br>

- [03 Offline Filesystem Backup – Step by Step (PostgreSQL)](#03-offline-filesystem-backup--step-by-step-postgresql)
  - [In simple words](#in-simple-words)
  - [Why offline backups still matter](#why-offline-backups-still-matter)
  - [What makes offline backup safe](#what-makes-offline-backup-safe)
  - [Step-by-step offline backup process](#step-by-step-offline-backup-process)
    - [Step 1: Notify users and applications](#step-1-notify-users-and-applications)
    - [Step 2: Stop PostgreSQL cleanly](#step-2-stop-postgresql-cleanly)
    - [Step 3: Copy the data directory](#step-3-copy-the-data-directory)
    - [Step 4: Verify backup completeness](#step-4-verify-backup-completeness)
    - [Step 5: Start PostgreSQL again](#step-5-start-postgresql-again)
  - [Restoring from an offline backup](#restoring-from-an-offline-backup)
  - [Handling tablespaces](#handling-tablespaces)
  - [Common mistakes during offline backup](#common-mistakes-during-offline-backup)
  - [Pros and cons of offline backups](#pros-and-cons-of-offline-backups)
  - [When I choose offline backup](#when-i-choose-offline-backup)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

**An offline filesystem backup means:**

* PostgreSQL is **completely stopped**
* no users, no writes, no WAL activity
* data files are copied in a stable state

This is the **safest and simplest** form of physical backup.

---

<br>
<br>

## Why offline backups still matter

**Even though online backups exist, offline backups are still used when:**

* database is small or medium
* maintenance window is available
* absolute safety is required
* environment is simple

With PostgreSQL stopped, there is zero consistency risk.

---

<br>
<br>

## What makes offline backup safe

**When PostgreSQL is stopped:**

* no transactions are running
* no dirty buffers exist
* no WAL is being generated
* files are internally consistent

This removes the need for WAL replay during restore.

---

<br>
<br>

## Step-by-step offline backup process

### Step 1: Notify users and applications

**Before stopping PostgreSQL:**

* inform application teams
* stop background jobs
* ensure no active connections

Never stop PostgreSQL blindly in production.

---

<br>
<br>

### Step 2: Stop PostgreSQL cleanly

```bash
sudo systemctl stop postgresql
```

**Or:**

```bash
pg_ctl stop -D $PGDATA
```

**Verify:**

```bash
ps aux | grep postgres
```

No postgres process should be running.

---

<br>
<br>

### Step 3: Copy the data directory

```bash
cp -a $PGDATA /backup/pgdata_backup
```

**Important:**

* use recursive copy
* preserve ownership and permissions
* include hidden files

If tablespaces exist, back them up separately.

---

<br>
<br>

### Step 4: Verify backup completeness

**Check:**

* directory size
* number of files
* backup logs

A half-copied backup is dangerous.

---

<br>
<br>

### Step 5: Start PostgreSQL again

```bash
sudo systemctl start postgresql
```

**Verify:**

* database starts normally
* applications reconnect

Downtime ends here.

---

<br>
<br>

## Restoring from an offline backup

**Restore process:**

* stop PostgreSQL
* replace PGDATA with backup copy
* ensure ownership and permissions
* start PostgreSQL

No WAL replay is needed.

---

<br>
<br>

## Handling tablespaces

**If tablespaces exist:**

* copy tablespace directories separately
* restore them to the same paths
* ensure symlinks in pg_tblspc are intact

Missing tablespaces cause startup failure.

---

<br>
<br>

## Common mistakes during offline backup

* copying data while PostgreSQL is still running
* forgetting tablespaces
* insufficient disk space
* wrong file permissions

Most failures are operational errors.

---

<br>
<br>

## Pros and cons of offline backups

**Pros:**

* simplest method
* highest safety
* easiest restore

**Cons:**

* requires downtime
* not suitable for 24x7 systems

---

<br>
<br>

## When I choose offline backup

**I choose offline backup when:**

* database is non-critical
* downtime is acceptable
* environment is small
* simplicity matters more than availability

---

<br>
<br>

## Final mental model

* Offline = stop DB, copy files
* Zero consistency risk
* Downtime is the cost
* Restore is simple

---

<br>
<br>

## One-line explanation

An offline filesystem backup copies PostgreSQL data files after stopping the server, ensuring maximum consistency at the cost of downtime.


<br>
<br>
<br>
<br>


