# PostgreSQL Administration Commands (Simplified Guide)

This markdown explains essential PostgreSQL administration commands, covering OS-level, psql meta-commands, SQL admin commands, and backup/restore usage.

---

- [PostgreSQL Administration Commands (Simplified Guide)](#postgresql-administration-commands-simplified-guide)
  - [General Server Management (Shell Commands)](#general-server-management-shell-commands)
  - [psql Meta-Commands (Run inside psql)](#psql-meta-commands-run-inside-psql)
  - [SQL Administration Commands (Inside psql)](#sql-administration-commands-inside-psql)
  - [Backup and Restore (Shell Level)](#backup-and-restore-shell-level)


## General Server Management (Shell Commands)

These commands run in the operating system terminal.

**Log in as postgres user:**

```bash
sudo -u postgres psql
```

**Check PostgreSQL service status (Linux):**

```bash
systemctl status postgresql
```

**Start PostgreSQL service:**

```bash
sudo systemctl start postgresql
```

**Restart PostgreSQL service:**

```bash
sudo systemctl restart postgresql
```

**Reload configuration without restart:**

```sql
SELECT pg_reload_conf();
```

Or from shell:

```bash
pg_ctl reload
```

**Check PostgreSQL version:**

```bash
psql -V
```

Inside psql:

```sql
SELECT version();
```

**Show config file path:**

```sql
SHOW config_file;
```

---

## psql Meta-Commands (Run inside psql)

Prefix = `\` (no semicolon).

**List all databases:**

```bash
\l
```

**Connect to database:**

```bash
\c dbname
```

**List tables:**

```bash
\dt
```

**Describe a table:**

```bash
\d table_name
```

**List all users/roles:**

```bash
\du
```

**List schemas:**

```bash
\dn
```

**List functions:**

```bash
\df
```

**Meta-command help:**

```bash
\?
```

**Exit psql:**

```bash
\q
```

---

## SQL Administration Commands (Inside psql)

End each with `;`.

**Create database:**

```sql
CREATE DATABASE dbname;
```

**Drop database:**

```sql
DROP DATABASE dbname;
```

**Create user:**

```sql
CREATE USER username WITH PASSWORD 'pass';
```

**Change user password:**

```sql
ALTER ROLE username WITH PASSWORD 'newpass';
```

**Grant permissions on database:**

```sql
GRANT ALL PRIVILEGES ON DATABASE dbname TO username;
```

**Reclaim storage and update stats:**

```sql
VACUUM ANALYZE table_name;
```

**Monitor running sessions:**

```sql
SELECT * FROM pg_stat_activity;
```

**Cancel a running backend query:**

```sql
SELECT pg_cancel_backend(PID);
```

Retrieve PID using pg_stat_activity.

---

## Backup and Restore (Shell Level)

Run these in OS terminal.

**Backup database:**

```bash
pg_dump -d dbname -U username > backupfile.sql
```

**Restore database:**

```bash
psql -U username -f backupfile.sql dbname
```
