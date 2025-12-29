# 03 Restore Using psql – Complete Flow (PostgreSQL Logical Restore)

<br>
<br>

- [03 Restore Using psql – Complete Flow (PostgreSQL Logical Restore)](#03-restore-using-psql--complete-flow-postgresql-logical-restore)
  - [In simple words](#in-simple-words)
  - [What restore actually does](#what-restore-actually-does)
  - [Pre-restore checklist (very important)](#pre-restore-checklist-very-important)
  - [Step 1: Create an empty database](#step-1-create-an-empty-database)
  - [Step 2: Restore using `psql`](#step-2-restore-using-psql)
  - [Restore directly from compressed dump](#restore-directly-from-compressed-dump)
  - [Restore from a remote server](#restore-from-a-remote-server)
  - [Common restore errors and causes](#common-restore-errors-and-causes)
    - [Role does not exist](#role-does-not-exist)
    - [Permission denied](#permission-denied)
    - [Object already exists](#object-already-exists)
  - [Useful restore options](#useful-restore-options)
  - [Post-restore tasks (often forgotten)](#post-restore-tasks-often-forgotten)
  - [Why restore takes time](#why-restore-takes-time)
  - [When `psql` restore is the right choice](#when-psql-restore-is-the-right-choice)
  - [Common DBA mistake](#common-dba-mistake)
  - [Final mental model](#final-mental-model)
  - [One-line explanation (interview ready)](#one-line-explanation-interview-ready)

<br>
<br>

## In simple words

- Restoring a SQL dump means running SQL commands again to rebuild the database.
- PostgreSQL does not have a special “restore mode” for SQL dumps.
- Restore is simply **executing the dump file using psql**.

---

<br>
<br>

## What restore actually does

- A SQL dump contains:
  * CREATE statements
  * INSERT statements
  * GRANT and ownership commands

<br>

- When restoring:
  * PostgreSQL executes these commands one by one
  * objects are rebuilt logically
  * indexes are recreated, not copied

Restore is a **replay process**, not a file copy.

---

<br>
<br>

## Pre-restore checklist (very important)

- Before restoring, I always check:
  * target server is correct
  * PostgreSQL version is compatible
  * sufficient disk space exists
  * required roles already exist

- Most restore failures happen due to missing preparation.

---

<br>
<br>

## Step 1: Create an empty database

```bash
createdb newdb
```

> The target database must exist before restore.

<br>

Alternatively:

```bash
createdb -O app_user newdb

# This command creates a new database named newdb and sets app_user as the owner. In simple terms, app_user becomes the main user who controls this database and has full rights over it.
```

This sets correct ownership upfront.

---

<br>
<br>

## Step 2: Restore using `psql`

```bash
psql -d newdb -f backup.sql
```

- What happens internally:
  * `psql` reads SQL line by line
  * PostgreSQL executes each statement
  * errors are reported immediately

- Restore speed depends on dump size and indexes.

---

<br>
<br>

## Restore directly from compressed dump

```bash
gunzip -c backup.sql.gz | psql -d newdb
```

- This avoids extracting the file to disk.
- Useful when storage space is limited.

---

<br>
<br>

## Restore from a remote server

```bash
psql -h server_ip -U postgres -d newdb < backup.sql
```

> Restore works over network just like local execution.

---

<br>
<br>

## Common restore errors and causes

### Role does not exist

Error:

```bash
ERROR: role "app_user" does not exist
```

- **Fix:**
  * create role first
  * or restore with `--no-owner`

---

<br>
<br>

### Permission denied

- Occurs when restore role lacks privileges.

<br>

- **Fix:**
  * restore as superuser
  * or adjust ownership and grants

---

<br>
<br>

### Object already exists

- Occurs when restoring into a non-empty database.

<br>

- **Fix**:
  * drop and recreate database
  * or clean objects manually

---

<br>
<br>

## Useful restore options

Skip ownership:

```bash
psql -d newdb -f backup.sql --set ON_ERROR_STOP=on

# This command connects to the newdb database and runs all SQL commands from the backup.sql file. If any error occurs while executing the file, PostgreSQL immediately stops instead of continuing, which helps avoid ending up with a half-restored or broken database.
```

- **For controlled restores**:
  * run schema first
  * then data

---

<br>
<br>

## Post-restore tasks (often forgotten)

- After restore, I always run:

```bash
ANALYZE;

# This command tells PostgreSQL to scan the tables and update statistics about the data. These statistics help the query planner choose better and faster execution plans for future queries.
```

> This regenerates statistics and improves performance.

<br>

- I also verify:
  * row counts
  * application connectivity
  * basic queries

- Restore without verification is incomplete.

---

<br>
<br>

## Why restore takes time

- SQL restore:
  * executes millions of INSERTs
  * rebuilds indexes
  * processes constraints

- This is slower than physical restore by design.

---

<br>
<br>

## When `psql` restore is the right choice

- I use `psql` restore when:
  * restoring plain SQL dumps
  * migrating data
  * doing partial or selective rebuilds
  * debugging schema issues

- It gives full visibility and control.

---

<br>
<br>

## Common DBA mistake

- Assuming backup success means restore success.
- A backup is only valid if restore completes cleanly.

---

<br>
<br>

## Final mental model

* Restore = replay SQL
* psql = execution engine
* errors must be fixed immediately
* verification is mandatory

---

<br>
<br>

## One-line explanation (interview ready)

Restoring a SQL dump means executing the exported SQL commands using psql to rebuild the database logically.
