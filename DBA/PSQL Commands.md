# PostgreSQL psql Command Guide

`psql` is PostgreSQL's command-line interface. It supports two types of commands:

1. **Meta-commands (start with )** – handled by psql itself.
2. **Standard SQL commands** – executed by PostgreSQL engine.

---

- [PostgreSQL psql Command Guide](#postgresql-psql-command-guide)
  - [Common Meta-Commands](#common-meta-commands)
    - [Help \& Assistance](#help--assistance)
    - [Connection \& Session](#connection--session)
  - [Structure \& Information Commands](#structure--information-commands)
  - [Input / Output Commands](#input--output-commands)
  - [SQL Commands Inside psql](#sql-commands-inside-psql)
  - [Command-Line Startup Options](#command-line-startup-options)
- [Quick Summary](#quick-summary)



## Common Meta-Commands

### Help & Assistance

**?** – Show help for all psql commands.

### Connection & Session

**\l** – List all databases.

**\c [database_name]** – Connect to database.

**\conninfo** – Show current connection information.

**\q** – Exit psql.

---

## Structure & Information Commands

**\dt** – List tables in current database.

**\d [table_name]** – Describe table structure.
Use `\d+ [table_name]` for extended detail.

**\du** – List database roles/users.

**\dn** – List schemas.

**\df** – List functions.

**\dv** – List views.

**\dx** – List extensions installed.

---

## Input / Output Commands

**\i [filename]** – Run SQL commands from file.

**\o [filename]** – Send query output to file.
Run `\o` again to disable.

**\copy** – Import/export data using local file paths.

**\e** – Open editor to modify current SQL buffer.

**! [OS command]** – Run shell command without leaving psql.
Example: `\! ls`

---

## SQL Commands Inside psql

You can run SQL normally:

**Create Database:**

```sql
CREATE DATABASE dbname;
```

**Create Table:**

```sql
CREATE TABLE t (id INT, name TEXT);
```

**Insert Data:**

```sql
INSERT INTO t VALUES (1, 'abc');
```

**Select Query:**

```sql
SELECT * FROM t;
```

**Update Data:**

```sql
UPDATE t SET name='xyz' WHERE id=1;
```

**Delete Data:**

```sql
DELETE FROM t WHERE id=1;
```

---

## Command-Line Startup Options

Run psql with connection flags:

```bash
psql -d dbname -U username -h hostname -p port
```

**Password prompt:**

```bash
psql -W dbname
```

**Run one command and exit:**

```bash
psql -c "SELECT now();" dbname
```

---

# Quick Summary

* `psql` meta-commands simplify database interactions.
* SQL queries work like any standard DB console.
* Command-line flags control how psql connects.

This file is a compact reference to essential psql usage.
