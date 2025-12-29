# 04 pg_restore and Selective Restore in PostgreSQL

<br>
<br>

- [04 pg\_restore and Selective Restore in PostgreSQL](#04-pg_restore-and-selective-restore-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why `pg_restore` exists](#why-pg_restore-exists)
  - [How `pg_restore` works internally](#how-pg_restore-works-internally)
  - [Basic `pg_restore` syntax](#basic-pg_restore-syntax)
  - [Creating a compatible dump for `pg_restore`](#creating-a-compatible-dump-for-pg_restore)
  - [Listing dump contents (very important)](#listing-dump-contents-very-important)
  - [Restoring specific objects](#restoring-specific-objects)
  - [Excluding objects during restore](#excluding-objects-during-restore)
  - [Restoring schema and data separately](#restoring-schema-and-data-separately)
  - [Parallel restore (big performance boost)](#parallel-restore-big-performance-boost)
  - [Handling ownership and permissions](#handling-ownership-and-permissions)
  - [Common `pg_restore` failures](#common-pg_restore-failures)
  - [When `pg_restore` is the right tool](#when-pg_restore-is-the-right-tool)
  - [When `pg_restore` is NOT useful](#when-pg_restore-is-not-useful)
  - [Final mental model](#final-mental-model)
  - [One-line explanation (interview ready)](#one-line-explanation-interview-ready)

<br>
<br>

## In simple words

- `pg_restore` is used to restore logical backups that were created in **custom**, **directory**, or **tar** format.

<br>

- **Unlike plain SQL restore, `pg_restore` gives control**:
  * what to restore
  * how to restore
  * how fast to restore

- This makes it very powerful for real DBA work.

---

<br>
<br>

## Why `pg_restore` exists

- Plain SQL dumps:
  * must be restored fully
  * execute line by line
  * cannot skip objects easily

`pg_restore` exists to solve these problems.

<br>

- It works only with **non-plain** dump formats:
  * `-Fc` (custom)
  * `-Fd` (directory)
  * `-Ft` (tar)

---

<br>
<br>

## How `pg_restore` works internally

- `pg_restore`:
  * reads dump metadata
  * understands database objects
  * decides restore order
  * executes commands selectively

- It does **not** blindly replay SQL like `psql`.

---

## Basic `pg_restore` syntax

```bash
pg_restore -d target_db backup.dump
```

This restores everything from the dump into `target_db`.

---

<br>
<br>

## Creating a compatible dump for `pg_restore`

```bash
pg_dump -Fc dbname > dbname.dump
```

Without this format, `pg_restore` cannot be used.

---

<br>
<br>

## Listing dump contents (very important)

Before restoring, I always inspect the dump:

```bash
pg_restore -l dbname.dump

# This command lists the contents of the dbname.dump backup file. It lets you see what objects are inside the dump—like tables, schemas, functions—before you decide what or how to restore.
```

- This shows:
  * tables
  * schemas
  * indexes
  * functions
  * extensions

- It helps decide what to restore.

---

<br>
<br>

## Restoring specific objects

> Only one table:

```bash
pg_restore -t customers -d target_db dbname.dump
```

<br>

> Only one schema:

```bash
pg_restore -n sales -d target_db dbname.dump
```

> Selective restore is not possible with plain SQL dumps.

---

<br>
<br>

## Excluding objects during restore

> Exclude table:

```bash
pg_restore --exclude-table=logs -d target_db dbname.dump
```

<br>

> Exclude schema:

```bash
pg_restore --exclude-schema=test -d target_db dbname.dump
```

This is useful in debugging and migrations.

---

<br>
<br>

## Restoring schema and data separately

> Schema only:

```bash
pg_restore -s -d target_db dbname.dump
```

<br>

- Data only:

```bash
pg_restore -a -d target_db dbname.dump
```

This allows controlled restore sequences.

---

<br>
<br>

## Parallel restore (big performance boost)

```bash
pg_restore -j 4 -d target_db dbname.dump

# This command restores the dbname.dump file into the target_db database using 4 parallel jobs. It speeds up the restore process by loading multiple objects at the same time, which is especially useful for large databases.
```

<br>

- Meaning:
  * `-j 4` = use 4 parallel jobs

- Parallel restore:
  * speeds up large restores
  * requires directory or custom format

---

<br>
<br>

## Handling ownership and permissions

> Skip ownership:

```bash
pg_restore --no-owner -d target_db dbname.dump

# This command restores the dump into target_db without trying to set original object owners. It’s useful when restoring into a database where the original roles don’t exist or when you want all objects to belong to the current user.
```

<br>

> Skip privileges:

```bash
pg_restore --no-privileges -d target_db dbname.dump

# This command restores the dump into target_db without restoring GRANT and REVOKE permissions. It’s useful when you want to handle access control separately or avoid permission errors during restore.
```

Very common when restoring to test or staging.

---

<br>
<br>

## Common `pg_restore` failures

- `pg_restore` fails when:
  * roles do not exist
  * target database is missing
  * permissions are insufficient
  * objects already exist

- Most issues are environment-related, not tool-related.

---

<br>
<br>

## When `pg_restore` is the right tool

- I use `pg_restore` when:
  * restoring large databases
  * restoring selective objects
  * doing migrations
  * minimizing restore time

- It offers control and speed.

---

<br>
<br>

## When `pg_restore` is NOT useful

- `pg_restore` cannot:
  * restore plain SQL dumps
  * restore physical backups
  * bypass permission rules

- Tool choice must match dump format.

---

<br>
<br>

## Final mental model

* `pg_dump` creates structured dumps
* `pg_restore` understands dump structure
* selective restore saves time
* parallel restore improves performance

---

## One-line explanation (interview ready)

`pg_restore` restores custom-format logical backups with fine-grained control over objects, order, and performance.
