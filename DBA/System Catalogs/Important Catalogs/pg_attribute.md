# PGSQL pg_attribute – Step-By-Step Real Scenario Guide (DBA Focused)

<br>
<br>

- [PGSQL pg\_attribute – Step-By-Step Real Scenario Guide (DBA Focused)](#pgsql-pg_attribute--step-by-step-real-scenario-guide-dba-focused)
  - [What is `pg_attribute`?](#what-is-pg_attribute)
  - [Scenario Overview](#scenario-overview)
  - [Step 1: A Table Is Created](#step-1-a-table-is-created)
  - [Step 2: **`pg_attribute`** Is Column Metadata Storage](#step-2-pg_attribute-is-column-metadata-storage)
  - [Step 3: How PGSQL Knows Which Table a Column Belongs To](#step-3-how-pgsql-knows-which-table-a-column-belongs-to)
  - [Step 4: Column Identity – Name, Position, Type](#step-4-column-identity--name-position-type)
  - [Step 5: NOT NULL and DEFAULT Behavior](#step-5-not-null-and-default-behavior)
  - [Step 6: Column Statistics and Performance](#step-6-column-statistics-and-performance)
  - [Step 7: Dropped Columns and Why Tables Do Not Shrink](#step-7-dropped-columns-and-why-tables-do-not-shrink)
  - [Step 8: Identity and Generated Columns](#step-8-identity-and-generated-columns)
  - [Step 9: Column-Level Permissions](#step-9-column-level-permissions)
  - [Step 10: Why DBAs Never Modify **`pg_attribute`**](#step-10-why-dbas-never-modify-pg_attribute)
  - [Final Understanding Through This Flow](#final-understanding-through-this-flow)


<br>
<br>

## What is `pg_attribute`?
- stores column-level details for every table in PGSQL.
- It is the place where PGSQL remembers 
  - which columns exist
  - their names,
  - data types,
  - and other properties for every table. 

<br>
<br>

## Scenario Overview

A PGSQL database is running normally. A table exists, queries work, indexes are used, ANALYZE runs, and permissions behave correctly. All of this depends on PGSQL knowing one basic thing:
- What columns exist, what type they are, and how they behave.

That information lives in **`pg_attribute`**. 

---

<br>
<br>

## Step 1: A Table Is Created

A DBA runs:

```bash
CREATE TABLE orders (
  id bigint PRIMARY KEY,
  customer_name text NOT NULL,
  amount numeric(10,2),
  created_at timestamp
);
```

- At this moment, PGSQL does not think in terms of SQL anymore. Internally, it records metadata.
- For every column in this table, PGSQL inserts one row into **`pg_attribute`**.
- So orders has four rows in **`pg_attribute`**, one per column.

---

<br>
<br>

## Step 2: **`pg_attribute`** Is Column Metadata Storage

- Each row in **`pg_attribute`** represents exactly one column.

PGSQL uses it to answer questions like:
* which columns belong to a table
* what is the column name
* what is the data type
* is NULL allowed
* does it have a default
* should statistics be collected

If **`pg_attribute`** is wrong, PGSQL cannot interpret table rows correctly.

---

<br>
<br>

## Step 3: How PGSQL Knows Which Table a Column Belongs To

- Every **`pg_attribute`** row has a reference called **`attrelid`**.
- **`attrelid`** points to the table entry inside **`pg_class`**.
- This is how PGSQL links columns to tables.
- When a query touches a table, PGSQL first reads **`pg_class`** to find the table, then reads **`pg_attribute`** to know its columns.

---

<br>
<br>

## Step 4: Column Identity – Name, Position, Type

- PGSQL stores three critical column identifiers:
  - **`attname`** stores the column name.
  - **`attnum`** stores the column position. Normal columns start from **`1`**. System columns like **`ctid`** use negative numbers.
  - **`atttypid`** stores the data type reference.

- If attnum ordering is broken, PGSQL reads wrong values from disk pages.
- This is why **`pg_attribute`** is never modified manually.

---

<br>
<br>

## Step 5: NOT NULL and DEFAULT Behavior

When NOT NULL is defined:

```bash
customer_name text NOT NULL
```

**`pg_attribute`** records this using **`attnotnull`**.

When a default exists:

```bash
created_at timestamp DEFAULT now()
```

- **`pg_attribute`** marks **`atthasdef`** as true, and the actual default expression lives in **`pg_attrdef`**.

- During inserts, PGSQL checks **`pg_attribute`** first to decide whether NULL is allowed or a default must be applied.

---

## Step 6: Column Statistics and Performance

- When ANALYZE runs, PGSQL collects statistics for columns.
- **`attstattarget`** controls how detailed those statistics should be.
- If **`attstattarget`** is zero, PGSQL collects no statistics for that column.

This matters when:

* queries use WHERE conditions
* indexes are ignored
* planner chooses bad plans

DBAs sometimes increase statistics targets for problematic columns to improve query planning.

---

<br>
<br>

## Step 7: Dropped Columns and Why Tables Do Not Shrink

A DBA runs:

```bash
ALTER TABLE orders DROP COLUMN amount;
```

- The column is not physically removed from disk immediately.
- Instead, **`pg_attribute`** marks the column as dropped using **`attisdropped`**.
- The data still exists inside table pages, but PGSQL ignores it.
- This explains why dropping columns does not reduce table size.
- Vacuum and rewrite operations are required to reclaim space.

---

<br>
<br>

## Step 8: Identity and Generated Columns

If a column is defined as identity:

```bash
id bigint GENERATED ALWAYS AS IDENTITY
```

**`pg_attribute`** records this in **`attidentity`**.

If a column is generated:

```bash
total numeric GENERATED ALWAYS AS (amount * 1.18) STORED
```

**`pg_attribute`** records this in **`attgenerated`**.

PGSQL checks these flags during **`INSERT`** and **`UPDATE`** to enforce correct behavior.

<br>
<details>
<summary><mark><b>Query Breakdown</b></mark></summary>
<br>

```bash
id bigint GENERATED ALWAYS AS IDENTITY
```

- **`id bigint`**: Defines a column named **`id`** with data type **`bigint`**.
- **`GENERATED ALWAYS AS IDENTITY`**: Tells PGSQL to automatically generate values for this column, and never allow manual inserts into it.

**In simple words:** PGSQL takes full control of the **`id`** value and auto-increments it safely, like a modern replacement for **`SERIAL`**.

---

```bash
total numeric GENERATED ALWAYS AS (amount * 1.18) STORED
```

- **`total numeric`**: Defines a column named total with data type numeric.
- **`GENERATED ALWAYS AS (amount * 1.18)`**: Makes this a generated column, where PGSQL automatically calculates the value using the expression.
- **`STORED`**: Tells PGSQL to store the calculated result on disk, not recompute it every time.

**In simple words:** **`total`** is auto-calculated from amount, saved permanently, and you never insert or update it manually.

</details>
<br>

---

<br>
<br>

## Step 9: Column-Level Permissions

A DBA grants access to a specific column:

```bash
GRANT SELECT (customer_name) ON orders TO reporting_user;
```

- This permission is stored inside **`pg_attribute`** using **`attacl`**.
- At query time, PGSQL checks column-level ACLs before returning data.
- If permissions behave strangely, **`pg_attribute`** is part of the investigation.

---

<br>
<br>

## Step 10: Why DBAs Never Modify **`pg_attribute`**

**`pg_attribute`** directly controls how PGSQL reads and writes table rows.

A wrong change here means:

* corrupted reads
* wrong column mapping
* silent data corruption

That is why all column changes must go through **`ALTER TABLE`**.

PGSQL updates **`pg_attribute`** safely and consistently.

---

<br>
<br>

## Final Understanding Through This Flow

- **`pg_attribute`** is PGSQL’s column dictionary.

- Every column in every table exists because **`pg_attribute`** says it does.

- When tables behave strangely, statistics look wrong, dropped columns waste space, or defaults act unexpectedly, **`pg_attribute`** explains why.

- For a DBA, understanding **`pg_attribute`** means understanding how PGSQL interprets table structure at the lowest safe level.
