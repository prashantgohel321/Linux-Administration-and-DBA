# 07 pg_dumpall and Cluster-Level Backups in PostgreSQL

<br>
<br>

- [07 pg\_dumpall and Cluster-Level Backups in PostgreSQL](#07-pg_dumpall-and-cluster-level-backups-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why `pg_dumpall` exists](#why-pg_dumpall-exists)
  - [What `pg_dumpall` actually backs up](#what-pg_dumpall-actually-backs-up)
  - [How `pg_dumpall` works internally](#how-pg_dumpall-works-internally)
  - [Basic `pg_dumpall` usage](#basic-pg_dumpall-usage)
  - [Role requirements (very important)](#role-requirements-very-important)
  - [Restoring from `pg_dumpall`](#restoring-from-pg_dumpall)
  - [Common `pg_dumpall` problems](#common-pg_dumpall-problems)
  - [`pg_dumpall` vs `pg_dump` (real difference)](#pg_dumpall-vs-pg_dump-real-difference)
  - [When I actually use `pg_dumpall`](#when-i-actually-use-pg_dumpall)
  - [Best practice (important)](#best-practice-important)
  - [Security warning](#security-warning)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)

<br>
<br>

## In simple words

`pg_dumpall` is used to back up **the entire PostgreSQL cluster**, not just one database.

It captures:
* all databases
* all roles and users
* role memberships
* global objects

If `pg_dump` backs up *data*, `pg_dumpall` backs up the *identity of the cluster*.

---

<br>
<br>

## Why `pg_dumpall` exists

Backing up only databases is not enough.

Real restores fail because:
* roles do not exist
* ownership is missing
* permissions break

`pg_dumpall` exists to solve this by capturing **global objects**.

---

<br>
<br>

## What `pg_dumpall` actually backs up

`pg_dumpall` includes:
* CREATE ROLE statements
* role passwords (hashed)
* role memberships
* CREATE DATABASE statements
* all databases (as SQL)

<br>

It does NOT back up:
* server configuration files
* physical WAL or data files

---

<br>
<br>

## How `pg_dumpall` works internally

* connects as a superuser
* reads global system catalogs
* dumps roles and privileges first
* dumps each database sequentially

All output is written as **plain SQL**.

---

<br>
<br>

## Basic `pg_dumpall` usage

```bash
pg_dumpall > cluster_backup.sql
```

This creates one large SQL file containing everything.

---

<br>
<br>

## Role requirements (very important)

`pg_dumpall` **must run as a superuser**.

<br>

Reason:
* global catalogs are restricted
* role passwords and memberships require superuser access

Non-superuser runs will fail.

---

<br>
<br>

## Restoring from `pg_dumpall`

Restore is done using psql:

```bash
psql -f cluster_backup.sql postgres
```

What happens:
* roles are created first
* databases are created
* database contents are restored

Restore should be done on a clean cluster.

---

<br>
<br>

## Common `pg_dumpall` problems

* extremely large output files
* slow restore
* no parallel restore support
* hard to debug failures

Because everything is in one file, recovery is all-or-nothing.

---

<br>
<br>

## `pg_dumpall` vs `pg_dump` (real difference)

`pg_dump`:

* single database
* flexible formats
* selective restore

<br>

`pg_dumpall`:

* entire cluster
* plain SQL only
* no selective restore

They serve different purposes.

---

<br>
<br>

## When I actually use `pg_dumpall`

I use `pg_dumpall` mainly for:

* backing up roles and global objects
* disaster recovery documentation
* rebuilding a cluster from scratch

For data backups, I still prefer pg_dump.

---

<br>
<br>

## Best practice (important)

Instead of using `pg_dumpall` alone:

* back up databases with `pg_dump`
* back up roles separately with `pg_dumpall --globals-only`

Example:

```bash
pg_dumpall --globals-only > globals.sql

# This command backs up only the global objects of the PostgreSQL cluster, such as roles and tablespaces. It does not include any database data, making it useful when you want to preserve users and permissions separately from databases.
```

This gives more control during restore.

---

<br>
<br>

## Security warning

`pg_dumpall` output contains:
* role definitions
* password hashes

<br>

Backup files must be:
* protected
* access-controlled
* stored securely

---

<br>
<br>

## Final mental model

* `pg_dump` = database-level backup
* `pg_dumpall` = cluster identity backup
* roles matter as much as data

---

<br>
<br>

## One-line explanation 

`pg_dumpall` creates a logical backup of all databases and global objects in a PostgreSQL cluster using plain SQL.
