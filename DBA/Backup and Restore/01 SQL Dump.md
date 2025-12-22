# PostgreSQL Backup & Restore – SQL Dump, Restore, pg_dumpall, and Large DB Handling (Practical Flow)

<br>
<br>

## Starting Point: What a SQL Dump Actually Is

- We can use a SQL dump as a backup file that contains lots of SQL commands. When we need to restore, we can run those commands again – they will rebuild our database tables, objects, and load all the data back. We should think of it as taking a simple snapshot of our database in the form of easy-to-read SQL instructions.

- When we want to create a dump, we can let PostgreSQL connect to our running database, read everything – the structure and the data – and turn it into those SQL commands. Later, if we need to, we can run this file on another PostgreSQL server to recreate the exact same database state.

<br>
<br>

## The Basic Dump Command (pg_dump)

When we need to create a simple backup of one database, we can run a command like:
```bash
pg_dump mydb > mydb.sql
```

- Here, `pg_dump` connects to our database called `"mydb"` and writes all the SQL commands into the file `mydb.sql`.
- We should remember that `pg_dump` is just a normal PostgreSQL client tool. It connects using the standard PostgreSQL protocol, so we can run it from any machine that has network access to the database server.
Since `pg_dump` only reads data (it doesn't change anything), we need proper permissions. To dump an entire database, we usually need to connect as a superuser or a role that can access every object.

If we want to control which server to connect to, we can use options like this:
```bash
pg_dump -h server_ip -p 5432 -U postgres mydb > mydb.sql
```

- `-h` lets us specify the host (server IP or name).
- `-p` lets us choose the port (default is 5432).
- `-U` lets us pick which PostgreSQL user to connect as.

We can run this safely while the database is online – no downtime needed!

<br>
<br>

## Why SQL Dumps Are So Useful

- We can restore SQL dumps into newer PostgreSQL versions without any issues. We can also move databases easily across different operating systems and even CPU architectures. Physical backups cannot do that, so we should rely on SQL dumps when we need to upgrade or migrate our database.

- Another important thing we should know: <mark><b>SQL dumps are transaction-consistent</b></mark>. They <mark><b>capture the exact state of our database at the moment the dump starts</b></mark>. While we run the dump, other users can keep working normally – it won't corrupt our backup at all.

<br>
<br>

## Restoring a SQL Dump

We can restore a SQL dump because it's just plain SQL text. To do it, we simply feed the file into the psql tool like this:

```bash
psql -X newdb < mydb.sql
```

<br>
<details>
<summary><b>What -X Does?</b></summary>
<br>

We can use `-X` with psql to ignore our personal config file (`.psqlrc`) during restore.

**Without -X (normal behavior):**
```bash
psql newdb < mydb.sql
```
- psql loads our ~/.psqlrc first.
- Our custom settings (like \timing, \set ON_ERROR_STOP, formatting) can mess up the restore.
- It might: show timing, stop on small errors, change output look, or even break the script.

**With -X (recommended):**
```bash
psql -X newdb < mydb.sql
```
- psql skips .psqlrc completely.
- Restore runs clean, fast, consistent, and exactly the same every time.
- Perfect and safe for automation/scripts.

**Quick Example Why -X Matters**
- Our .psqlrc has: \set ON_ERROR_STOP on
- **Without -X**: restore stops on the first tiny warning.
- **With -X**: restore ignores it and finishes smoothly.
That’s why we always use `-X` in production scripts!

**What is .psqlrc?**
- We can think of .psqlrc as our personal startup file for psql (located at ~/.psqlrc).
- It runs automatically every time we open psql interactively.

**Common things we put in it:**
- \timing on (show query time)
- \pset border 2 (nice table look)
- \pset pager off (no extra pager)
- Custom greetings or shortcuts


</details>
<br>

Before we run this, we need to make sure the target database already exists. For a clean restore, we should create it from `template0`:

```bash
createdb -T template0 newdb
```

- We can use `-X` to make sure psql ignores our personal configuration files (.psqlrc) and follows only what's in the dump.

- If the dump has objects owned by specific roles/users, we need to ensure those roles already exist in the target server. If they don't, PostgreSQL will give errors about ownership and permissions.

If we want the restore to stop immediately on the first error, we can add:

```bash
psql -X --set ON_ERROR_STOP=on newdb < mydb.sql
```

If we want everything to restore as a single transaction (all or nothing), we can use:

```bash
psql -X -1 newdb < mydb.sql
```

With the single transaction option (`-1` or `--single-transaction`), either the whole dump succeeds perfectly, or nothing gets applied – which helps keep our database consistent!

<br>
<br>

## Restoring Using pg_restore

If our dump file is not plain SQL text (for example, if we used custom format or directory format), we cannot use psql to restore it. In that case, we need to use pg_restore instead:

```
pg_restore -d newdb backup.dump
```

We should know that custom and directory formats give us great selective restore options. We can choose exactly which tables, schemas, or objects we want to restore – we don't have to restore everything at once.

**Some useful examples we can try:**

- Restore only one table: `pg_restore -t customers -d newdb backup.dump`
- Restore only schema (no data): `pg_restore -s -d newdb backup.dump`
- Restore only data (no schema): `pg_restore -a -d newdb backup.dump`
- Faster with parallel jobs: `pg_restore -j 4 -d newdb backup.dump`

This makes `pg_restore` super flexible when we need to recover just parts of the database!

<br>
<br>

## Dumping Directly Across Servers

We can move data from one server to another without creating any files in between. Because pg_dump sends output directly (to stdout) and psql can read input directly (from stdin), we can connect them with a pipe (|).

```
pg_dump -h old_host mydb | psql -X -h new_host mydb
```

This streams the backup straight from the old server and restores it on the new server – fast and no disk space used for temporary files.

**Useful tips we should remember:**

- We need to make sure the target database `"mydb"` already exists on the new host.
- We can add `-U` username if needed for both sides.
- Always use `-X` on psql side to avoid `.psqlrc` issues.
- Great for quick migrations or copying between servers!

This streaming method saves time and space when we need to transfer databases directly!

<br>
<br>

## Important Detail About Template Databases

SQL dumps are based on template0. If `template1` has custom changes like languages or extensions, they will appear in the dump. When restoring, you must create databases from template0 to avoid duplication problems.

<br>
<br>

## Why ANALYZE Matters After a Restore

After loading data into a fresh database, PostgreSQL has no statistics for the planner. Running ANALYZE fills these statistics:

```bash
vacuumdb --analyze newdb
```

Without it, queries may perform poorly.

<br>
<br>

## Using pg_dumpall for Full Cluster Backups

- We can use `pg_dump` when we need to back up just one database – it handles tables, data, and schema inside that database. But it does not include global objects like roles (users) and tablespaces.

If we want to capture everything in the entire PostgreSQL cluster, we should use pg_dumpall:

```bash
pg_dumpall > entire_cluster.sql
```

**This single file will contain:**
- All roles (users and their privileges)
- Tablespaces
- All databases (with CREATE DATABASE commands)

To restore the cluster:

```bash
psql -X -f entire_cluster.sql postgres
```

- We need to run this as a superuser because creating roles and tablespaces requires superuser privileges.
- **How `pg_dumpall` works**: It first dumps the global objects (roles, tablespaces), then automatically calls `pg_dump` for each database in the cluster.

If we only want global objects (roles and tablespaces, no database data):

```bash
pg_dumpall --globals-only > globals.sql
```

This is super useful when we set up a new server and need to recreate users/roles before restoring individual databases!

<br>
<br>

## Handling Very Large Databases

When our database is very large, the dump file can become huge – sometimes too big for some filesystems to handle. PostgreSQL gives us several smart ways to solve this problem.

### 1. Compression

We can compress the dump on the fly to make the file much smaller:

```bash
pg_dump mydb | gzip > mydb.sql.gz
```

To restore:

```bash
gunzip -c mydb.sql.gz | psql newdb
```

> This keeps the file size manageable and saves disk space.

### 2. Splitting Output Files

We can split the dump into smaller chunks (e.g., 2GB each):

```bash
pg_dump mydb | split -b 2G - part_
```
This creates files like part_aa, part_ab, etc.

To Restore:

```bash
cat part_* | psql newdb
```
> Perfect when our filesystem has file size limits.

### 3. Custom Format Dumps

We should use custom format for big databases – it's compressed by default and very efficient:

```bash
pg_dump -Fc mydb > mydb.dump
```

Restore selectively:

```bash
pg_restore -d newdb mydb.dump
```

> Great size reduction and flexibility.

### Parallel Dumps

- We can speed up backup and restore a lot by using multiple jobs (only works with directory format `-Fd`):

Parallel dumping speeds up extraction:

```bash
pg_dump -j 4 -F d -f outdir mydb
```
> (This creates a directory called outdir with many files)

Parallel restore:

```bash
p pg_restore -j 4 -d newdb outdir
```

- We should use `-j` with the number of CPU cores we have – it makes huge databases dump and restore much faster!
- **Quick Tip**: For very large databases, we should combine parallel + directory format. It's the fastest and most reliable way!

<br>
<br>

## What Matters Most in Real Work

A dump and restore workflow must be tested on non‑production servers. Real backups become useful only when you have proven that a restore works. Always monitor:

* dump size
* dump time
* restore time
* disk space for dumps
* user existence before restore

With these commands and flow in hand, PostgreSQL backup and restore becomes predictable rather than mysterious.
