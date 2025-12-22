# PostgreSQL Dump Formats Explained (Simple English)

When we use `pg_dump` to backup a database, we can choose different output formats with the `-F` option. Each format has its own benefits. Here are the main ones:

- [PostgreSQL Dump Formats Explained (Simple English)](#postgresql-dump-formats-explained-simple-english)
  - [1. `-Fp` → Plain Text SQL Format (Default)](#1--fp--plain-text-sql-format-default)
  - [2. `-Fc` → Custom Format](#2--fc--custom-format)
  - [3. `-Fd` → Directory Format](#3--fd--directory-format)
  - [4. -Ft → Tar Format](#4--ft--tar-format)
  - [Quick Recommendation](#quick-recommendation)


## 1. `-Fp` → Plain Text SQL Format (Default)

- **What it is**: Creates <mark><b>a simple readable text file</b></mark> full of SQL commands (CREATE TABLE, INSERT data, etc.).
- **Pros**: Easy to read/edit with any text editor. No special tools needed for restore.
- **Cons**: Largest file size, slow for big databases, no selective restore (everything or nothing).
- **When to use**: Small databases, or when we need to inspect/modify the SQL manually.

**Backup Example:**
```bash
pg_dump -Fp -U postgres mydb > mydb_plain.sql
```

**Restore Example (using psql):**
```bash
createdb newdb
psql -d newdb < mydb_plain.sql
```

<br>
<br>

## 2. `-Fc` → Custom Format

- **What it is**: <mark><b>Binary</b></mark>, compressed format made specially for PostgreSQL.
- **Pros**: Smaller file, much faster backup/restore, supports parallel restore, allows selective restore (only some tables/schemas).
- **Cons**: Not human-readable, needs <mark><b>pg_restore</b></mark> to restore.
- **When to use**: Most common choice for medium to large databases (recommended in production).

**Backup Example:**
```bash
pg_dump -Fc -U postgres mydb > mydb_custom.dump
```

**Restore Example (full or selective):**
```bash
# Full restore
pg_restore -d newdb mydb_custom.dump

# Only specific table
pg_restore -t customers -d newdb mydb_custom.dump

# Parallel (faster)
pg_restore -j 4 -d newdb mydb_custom.dump
```

<br>
<details>
<summary><b>-j 4</b></summary>
<br>

`-j 4` means run the restore using 4 parallel jobs (4 workers) at the same time.

- `-j` = parallel jobs flag

- `4` = number of simultaneous restore threads

</details>
<br>

<br>
<br>

## 3. `-Fd` → Directory Format

- **What it is**: Creates <mark><b>a folder with many separate files</b></mark> (one per object/table).
- **Pros**: Best for selective and parallel restores, very flexible, good for huge databases.
- **Cons**: Not a single file (folder instead), needs <mark><b>pg_restore</b></mark>.
- **When to use**: Very large databases where we want maximum speed and flexibility.

**Backup Example:**
```bash
pg_dump -Fd -U postgres mydb -f mydb_directory_backup
(This creates a folder called mydb_directory_backup)
```

**Restore Example:**
```bash
# Full restore
pg_restore -d newdb mydb_directory_backup

# Parallel restore (fastest)
pg_restore -j 8 -d newdb mydb_directory_backup
```

<br>
<br>

## 4. -Ft → Tar Format

- **What it is**: Packs everything into a single .tar file (like a zip).
- **Pros**: Single file, can extract manually if needed, supports selective restore.
- **Cons**: Slower than custom/directory, less common now.
- **When to use**: When we want a single archive file but still need some selective restore options.

**Backup Example:**
```bash
pg_dump -Ft -U postgres mydb > mydb_tar.tar
```

**Restore Example:**
```bash
pg_restore -d newdb mydb_tar.tar
```

<br>
<br>

## Quick Recommendation

- **Small DB**: Use -Fp (plain SQL) – simple and readable.
- **Medium/Large DB**: Use -Fc (custom) – best balance of size and speed.
- **Huge DB**: Use -Fd (directory) – fastest with parallel jobs.

We should always test our backups by restoring them on a test server! 