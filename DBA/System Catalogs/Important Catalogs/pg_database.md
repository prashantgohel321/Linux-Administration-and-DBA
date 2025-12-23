# PGSQL **`pg_database`** – Step-By-Step Real Scenario Guide (DBA Focused)

<br>
<br>

- [PGSQL **`pg_database`** – Step-By-Step Real Scenario Guide (DBA Focused)](#pgsql-pg_database--step-by-step-real-scenario-guide-dba-focused)
  - [What is `pg_database`?](#what-is-pg_database)
  - [Scenario Overview](#scenario-overview)
  - [Step 1: PGSQL Starts Before Any User Database](#step-1-pgsql-starts-before-any-user-database)
  - [Step 2: Creating a New Database](#step-2-creating-a-new-database)
  - [Step 3: How PGSQL Finds a Database During Connection](#step-3-how-pgsql-finds-a-database-during-connection)
  - [Step 4: Database Ownership and Control](#step-4-database-ownership-and-control)
  - [Step 7: Template Databases and Cloning](#step-7-template-databases-and-cloning)
  - [Step 7: Limiting Connections Per Database](#step-7-limiting-connections-per-database)
  - [Step 8: Default Tablespace Selection](#step-8-default-tablespace-selection)
  - [Step 9: Transaction ID Safety and Vacuum Pressure](#step-9-transaction-id-safety-and-vacuum-pressure)
  - [Step 10: Why a Database Can Become Invalid](#step-10-why-a-database-can-become-invalid)
  - [Step 11: Access Privileges at Database Level](#step-11-access-privileges-at-database-level)
  - [Step 12: Why DBAs Never Modify **`pg_database`** Directly](#step-12-why-dbas-never-modify-pg_database-directly)
  - [Final Understanding Through This Flow](#final-understanding-through-this-flow)

<br>
<br>

## What is `pg_database`?
- stores information about every database in the PGSQL cluster.
- **In simple words**: It’s the place where PGSQL keeps the list of all databases, their owners, encoding, locale, and connection settings.

<br>
<br>

## Scenario Overview

- A PGSQL cluster is running on a server. Inside this single cluster, multiple databases exist: appdb, reportingdb, testdb, and template databases. Clients connect, new databases are created, some databases are blocked, and occasionally PGSQL refuses connections or forces vacuum activity.

- All of this behavior is controlled by **pg_database**.

---

<br>
<br>

## Step 1: PGSQL Starts Before Any User Database

- When PGSQL starts, it does not open user tables first. It reads **`pg_database`**.
- **`pg_database`** is shared across the entire cluster. There is exactly **one **`pg_database`** catalog for the whole cluster**, not one per database.

- PGSQL uses **`pg_database`** to know:
  * which databases exist
  * which databases allow connections
  * where their default storage is
  * which transaction IDs are safe

If **`pg_database`** is damaged, the cluster cannot function.

---

<br>
<br>

## Step 2: Creating a New Database

A DBA runs:

```bash
CREATE DATABASE appdb;
```

- PGSQL inserts a new row into **`pg_database`**.

- That single row records:
  * database name
  * owner
  * encoding
  * locale
  * default tablespace

- From this moment, appdb becomes visible to the cluster.

---

<br>
<br>

## Step 3: How PGSQL Finds a Database During Connection

A client runs:

```bash
psql appdb
```

- PGSQL does not scan directories blindly.
- It looks up **`appdb`** inside **`pg_database`** using datname.
- If no row exists, the connection fails immediately.
- If **`datallowconn`** is false, the connection is rejected even if the database exists.
- This is how PGSQL blocks connections without deleting databases.

---

<br>
<br>

## Step 4: Database Ownership and Control

- The user who creates the database becomes the owner.
- This ownership is stored in **`datdba`**.

- Ownership controls:
  * who can drop the database
  * who can alter database-level settings

- If a DBA cannot drop a database, PGSQL checks **`datdba`** and permissions stored here.

---

<br>
<br>

## Step 7: Template Databases and Cloning

- Some databases are marked as templates.
- If **`datistemplate`** is true, PGSQL allows other databases to be cloned from it.
- **`template1`** exists for this reason.
- **`template0`** is protected by **`datallowconn = false`** so it cannot be modified.
- This mechanism allows PGSQL to create databases quickly and safely.

---

<br>
<br>

## Step 7: Limiting Connections Per Database

A DBA runs:

```bash
ALTER DATABASE reportingdb CONNECTION LIMIT 20;
```

- PGSQL records this in **`datconnlimit`**.
- When clients connect, PGSQL checks this value.
- If the limit is reached, new connections are refused for that database only.
- This is how DBAs protect critical databases from connection storms.

---

<br>
<br>

## Step 8: Default Tablespace Selection

If a table is created without specifying a tablespace:

```bash
CREATE TABLE logs (...);
```

- PGSQL uses the database’s default tablespace stored in **`dattablespace`**.
- This explains why tables suddenly appear on a specific disk even when the SQL does not mention tablespaces.

---

<br>
<br>

## Step 9: Transaction ID Safety and Vacuum Pressure

- Each database tracks transaction ID safety using datfrozenxid and datminmxid.
- These values represent the oldest safe transaction ID across all tables in that database.
- If these values lag behind, PGSQL forces aggressive vacuuming to prevent wraparound.
- When PGSQL logs warnings about wraparound risk, **`pg_database`** is where those thresholds are tracked.

---

<br>
<br>

## Step 10: Why a Database Can Become Invalid
- If **`datconnlimit`** is set to -2, PGSQL treats the database as invalid.
- Clients cannot connect.
- This happens during certain internal failures or administrative actions.

The database still exists, but PGSQL refuses access until corrected.

---

<br>
<br>

## Step 11: Access Privileges at Database Level

- Database-level privileges are stored in **`datacl`**.

When a user runs:

```bash
GRANT CONNECT ON DATABASE appdb TO app_user;
```

- PGSQL updates **`datacl`**.
- Before any session is established, PGSQL checks this field.
- This is why database-level permission issues block connections before any table access happens.

---

<br>
<br>

## Step 12: Why DBAs Never Modify **`pg_database`** Directly

**`pg_database`** controls cluster-wide behavior.

A wrong change here can:
* block all connections
* corrupt database cloning
* break transaction safety

All changes must happen through **`CREATE DATABASE`**, **`ALTER DATABASE`**, or **`DROP DATABASE`**.

---

<br>
<br>

## Final Understanding Through This Flow

- **`pg_database`** is PGSQL’s **cluster-level directory**.
- Every connection, every database creation, and every wraparound safety decision passes through it.
- For a DBA, understanding **`pg_database`** explains:
  * why connections fail
  * why databases clone or refuse cloning
  * why vacuum pressure suddenly increases
  * why tables appear in certain tablespaces

If **`pg_database`** makes sense, database-level behavior stops being mysterious.
