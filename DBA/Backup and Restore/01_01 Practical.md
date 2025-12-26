# PostgreSQL SQL Dump, Restore, pg_dumpall, and Large DB Handling – Step‑By‑Step Real Scenario Guide

<br>
<br>

## Scenario Background

A PostgreSQL server hosts a production database called `salesdb`. It contains customer records, product listings, and daily transactions. A DBA wants to:

1. Create SQL dumps of this database.
2. Restore the dump into a new server.
3. Dump the entire cluster including roles.
4. Handle a very large database efficiently.

This file walks through that full story step by step.

<br>
<details>
<summary><b>Commands to create DB, tables and insert records.</b></summary>
<br>

Create the DB:
```bash
CREATE DATABASE salesdb;
```

Connect to the new DB:
```bash
\c salesdb
```

Create tables:
```bash
# customers

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT
);
```

```bash
# products table

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name TEXT,
    price NUMERIC(10,2)
);
```

```bash
# transactiojn table

CREATE TABLE transactions (
    txn_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    product_id INT REFERENCES products(product_id),
    quantity INT,
    txn_date DATE
);
```

Insert Sample Records:
```bash
# customers

INSERT INTO customers (name, email)
VALUES 
('Amit Patel', 'amit@example.com'),
('Sneha Shah', 'sneha@example.com');
```

```bash
# products

INSERT INTO products (product_name, price)
VALUES
('Laptop', 55000),
('Mouse', 800);

```

```bash
# transactions

INSERT INTO transactions (customer_id, product_id, quantity, txn_date)
VALUES
(1, 1, 1, CURRENT_DATE),
(2, 2, 3, CURRENT_DATE);

```


</details>
<br>

---

<br>
<br>

## Step 1: Create a Simple SQL Dump of One Database

The production database salesdb is running normally. It must be backed up without stopping the service. The DBA connects to the server and runs:

```bash
pg_dump salesdb > salesdb.sql
```

- **`pg_dump`** connects to PostgreSQL using normal authentication and reads everything from the database—schemas, tables, functions, sequences, and data—and writes SQL commands into **`salesdb.sql`**.

- The database stays online the whole time. Users continue working. The dump captures a transaction‑consistent snapshot.

<br>
<details>
<summary><b>Breakdown of pg_dump salesdb > salesdb.sql</b></summary>
<br>

- **`pg_dump`**: Backup tool for dumping one PostgreSQL database.
- **`salesdb`**: Name of the database being backed up.
- **`>`**: Redirects output to a file.
- **`salesdb.sql`**: File where the SQL backup will be stored.

</details>
<br>

---

<br>
<br>

## Step 2: Dump a Database from a Remote Server

The database runs on a remote machine at **`10.10.5.25`**. The DBA wants to perform the dump from his laptop.

He runs:

```bash
pg_dump -h 10.10.5.25 -p 5432 -U postgres salesdb > salesdb.sql
```

- The dump works because **`pg_dump`** is a standard PostgreSQL client. As long as the user has permissions to read objects, the client machine can dump remotely.

- If the user lacks permission on even one schema or table, pg_dump will fail. Superuser or full access is safest.

<br>
<details>
<summary><b>Breakdown of pg_dump -h 10.10.5.25 -p 5432 -U postgres salesdb > salesdb.sql</b></summary>
<br>

- **`pg_dump`**: Backup tool to dump the salesdb database.
- **`-h 10.10.5.25`**: Connect to PostgreSQL server running on host IP 10.10.5.25.
- **`-p 5432`**: Use TCP port 5432 to connect.
- **`-U postgres`**: Login using PostgreSQL user postgres.
- **`salesdb`**: Name of the database being backed up.
- **`> salesdb.sql`**: Write the backup into file salesdb.sql.

**Think of it like:** “I am connecting to a remote PostgreSQL server at 10.10.5.25:5432 as user postgres, and dumping the salesdb database into a SQL file called salesdb.sql.”

</details>
<br>

---

<br>
<br>

## Step 3: Restore the Dump into a Fresh Database

- Later, the DBA prepares a new PostgreSQL server and needs to recreate **`salesdb`** there.

First, he creates an empty database using **`template0`**:

```bash
createdb -T template0 salesdb_new
```

<br>
<details>
<summary><b>Breakdown of above command</b></summary>
<br>

- **`createdb`**: Command to create a new PostgreSQL database.

- **`-T template0`**: Use template0 as the source template (a clean, untouched default database).

- **`salesdb_new`**: Name of the new database to be created.

**Think of it like:** “Create a completely fresh database called salesdb_new using the clean template0 instead of template1.”

</details>
<br>

Next, he restores:

```bash
psql -X salesdb_new < salesdb.sql
```

<br>
<details>
<summary><b>Breakdown of above command</b></summary>
<br>

- **`psql`**: PostgreSQL command-line client used to run SQL.
- **`-X`**: Do not load .psqlrc settings—run clean.
- **`salesdb_new`**: Target database where we want to restore data.
- **`< salesdb.sql`**: Feed (import) the SQL backup file into the database.

**Think of it like:** “Load the salesdb.sql backup file into the new database salesdb_new, without letting personal psql settings interfere.”

</details>
<br>

The restore reads every SQL statement and rebuilds:

* schemas
* tables
* indexes
* views
* data

If any users referenced inside the dump do not exist on the target server, the restore prints ownership errors. The DBA must create those roles first.

To stop on the first error, he could have run:

```bash
psql -X --set ON_ERROR_STOP=on salesdb_new < salesdb.sql
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`-X`**: Ignore .psqlrc and run with a clean environment.
- **`--set ON_ERROR_STOP=on`**: Stop the restore immediately if an SQL error occurs (no silent failures).
- **`salesdb_new`**: DB receiving the restore.
- **`< salesdb.sql`**: Feed the salesdb_new file into psql for execution.

**Think of it like:** Restore the backup into salesdb_new, and if even one SQL error happens, stop instantly instead of continuing.

</details>
<br>

To apply everything as a single transaction:

```bash
psql -X -1 salesdb_new < salesdb.sql
```

If an error appears in single‑transaction mode, the entire restore rolls back.

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`-X`**: Ignore .psqlrc and run with a clean environment.
- **`-1`**: Wrap the entire restore in a single transaction - if anything fails, everything rolls back.
- **`salesdb_new`**: DB that will receive the restored data.
- **`< salesdb.sql`**: Feed the SQL backup file into psql for execution.

**Think of it like:** Restore salesdb_new in one big transaction, so if one statement fails, nothing gets partially restored.

</details>
<br>

---

<br>
<br>

## Step 4: Using pg_restore for Custom/Directory Dumps

A different team member dumped another database using custom format:

```bash
pg_dump -Fc inventorydb > inventory.dump
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`-Fc`**: Format = custom binary dump (not plain SQL).
- **`inventorydb`**: Name of the database being backed up.
- **`>`**: Redirect output to a file.
- **`inventory.dump`**: File that will store the custom-format backup.

**Think of it like:** “Create a custom binary backup of inventorydb and store it in a file called inventory.dump.”

</details>
<br>

This file is binary and cannot be restored using psql. The DBA restores it using:

```bash
pg_restore -d inventory_new inventory.dump
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`pg_restore`**: Tool used to restore a custom-format postgresql backup.
- **`-d inventory_new`**: Target DB where the dump will be stored.
- **`inventory.dump`**: The custom format backup file being restored.

**Think of it like:** “Load the contents of inventory.dump into the database inventory_new.”

</details>
<br>

Selective restore happens easily:

Restore one table:

```bash
pg_restore -t products -d inventory_new inventory.dump
```

Restore schema only:

```bash
pg_restore -s -d inventory_new inventory.dump
```

Restore data only:

```bash
pg_restore -a -d inventory_new inventory.dump
```

Large restores run faster in parallel:

```bash
pg_restore -j 4 -d inventory_new inventory.dump
```

---

<br>
<br>

## Step 5: Streaming a Database Between Two Servers

The company migrates from server A to server B with minimal downtime. Instead of writing a file, data streams directly:

```bash
pg_dump -h old_server salesdb | psql -X -h new_server salesdb
```

- This dumps from old_server and feeds directly to new_server. No disk storage required.

- The destination database must already exist.


<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`pg_dump -h old_server salesdb`**: Dump the salesdb database from the PostgreSQL server running on old_server.
- **`|`**: Pipe the dump output directly into the next command (no file created).
- **`psql -X -h new_server salesdb`**: Import that dump into the salesdb database on the PostgreSQL server running on new_server, ignoring .psqlrc.

**Think of it like**:“Copy salesdb straight from the old server to the new server through a pipe, without saving a dump file in the middle.”

</details>
<br>

---

<br>
<br>

## Step 6: Restore Requirements – Template Databases and Roles

- After multiple restores, the DBA notices duplicate objects. The reason: template1 includes custom extensions.
- To avoid duplication, empty databases for restore must come from template0.
- Also, SQL dumps do not include cluster‑wide users. These must be restored separately.

---

<br>
<br>

## Step 7: Why ANALYZE Is Required After Restore

Once a large restore finishes, PostgreSQL has no statistics for the optimizer. Queries run slowly.

The DBA fixes it using:

```bash
vacuumdb --analyze salesdb_new
```

Within minutes, execution speed returns to normal.

---

<br>
<br>

## Step 8: Back Up the Entire Cluster Using pg_dumpall

A new requirement arrives: full cluster backup including roles and tablespaces.

The DBA runs:

```bash
pg_dumpall > full_cluster.sql
```

This dump contains:

* CREATE ROLE commands
* CREATE TABLESPACE commands
* CREATE DATABASE commands
* and pg_dump output for each database

To restore the cluster later:

```bash
psql -X -f full_cluster.sql postgres
```

The postgres database is used only as an entry point.

If only roles and tablespaces are needed:

```bash
pg_dumpall --globals-only > globals.sql
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`pg_dumpall`**: Tool to dump the entire PostgreSQL cluster metadata.
- **`--globals-only`**: Dump only global objects (roles, tablespaces), not databases.
- **`>`**: Redirect the output to a file.
- **`globals.sql`**: File where global SQL definitions will be saved.

**Think of it like:** “Export only users, roles, and tablespaces into globals.sql without touching database data.”

</details>
<br>

---

<br>
<br>

## Step 9: Handling Very Large Databases

Now the DBA must dump a multi‑terabyte reporting database. A normal SQL dump becomes too large.

### Compression Approach

```bash
pg_dump reportingdb | gzip > reporting.sql.gz
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`pg_dump reportingdb:`** Dump the reportingdb database into plain SQL output.
- **`|`**: Pipe tha output to the next command.
- **`gzip`**: Compress the SQL output using gzip.
- **`> reporting.sql.gz`**: Write the compressed backup into a file named reporting.sql.gz.

**Think of it like:** “Create a dump of reportingdb and immediately compress it into a gzip file to save space.”

</details>
<br>

Restore:

```bash
gunzip -c reporting.sql.gz | psql reporting_new
```

<br>
<details>
<summary><b>Breakdown of this command.</b></summary>
<br>

- **`gunzip -c reporting.sql.gz`**: Decompress reporting.sql.gz and send the SQL output to stdout (without creating a file on disk).
- **`psql reporting_new`**: Restore the SQL data into the reporting_new database.

**Think of it like:** “Unzip the reporting backup and load it directly into reporting_new in one step—no temp file needed.”

</details>
<br>

The file size shrinks drastically.

### Splitting Output

Filesystem limits block large files over 2GB. The DBA splits the dump:

```bash
pg_dump reportingdb | split -b 2G - part_
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`pg_dump reportingdb`**: Dump the reportingdb database to standard output.
- **`|`**: Pipe the dump output to the next command.
- **`split -b 2G -`**: Split incoming data into 2-gigabyte chunks; - means read from STDIN.
- **`part_`**: Prefix used for naming the output chunk files (part_aa, part_ab, …).

**Think of it like:** “Dump reportingdb and break the backup into 2GB pieces named part_xx so they’re easier to move or store.”

</details>
<br>

Restore later:

```bash
cat part_* | psql reporting_new
```

### Custom Format + pg_restore

```bash
pg_dump -Fc reportingdb > reporting.dump
```

Restore selectively:

```bash
pg_restore -d reporting_new reporting.dump
```

### Directory Format + Parallel Jobs

For maximum speed:

```bash
pg_dump -j 8 -Fd -f outdir reportingdb
```

<br>
<details>
<summary><b>Breakdown of above command.</b></summary>
<br>

- **`pg_dump`** Backup tool for exporting a PostgreSQL database.
- **`-j 8`** Run the dump using 8 parallel jobs (faster on large DBs).
- **`-Fd`** Format = directory format (dump written into multiple files inside a folder).
- **`-f outdir`** Write the directory-format dump into a folder named outdir.
- **`reportingdb`** Name of the database being backed up.

**Think of it like:** “Take a directory-style backup of reportingdb using 8 parallel workers and store all dump files inside the outdir folder.”

</details>
<br>

Restore in parallel:

```bash
pg_restore -j 8 -d reporting_new outdir
```

Terabyte‑scale restore time drops dramatically.

---

<br>
<br>

## Final Understanding Through This Flow

SQL dumps are perfect for migrating across platforms, upgrading PostgreSQL versions, restoring logical objects, and selectively restoring data. pg_dumpall captures the entire cluster including roles. Large database techniques keep backups practical.

This scenario shows exactly how SQL dumps solve real production backup and migration needs.
