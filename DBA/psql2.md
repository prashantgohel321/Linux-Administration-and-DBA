# PostgreSQL Commands Handbook: The DBA Edition

A comprehensive, deep-dive guide to PostgreSQL commands for Developers and Database Administrators. This guide covers connecting, querying, optimizing, securing, and maintaining a PostgreSQL cluster.

## Table of Contents

- [PostgreSQL Commands Handbook: The DBA Edition](#postgresql-commands-handbook-the-dba-edition)
  - [Table of Contents](#table-of-contents)
  - [1. Connecting \& psql Power Tools](#1-connecting--psql-power-tools)
    - [`psql` Connection Flags](#psql-connection-flags)
    - [Essential Meta Commands (`\`)](#essential-meta-commands-)
  - [2. User \& Role Management (Security)](#2-user--role-management-security)
    - [`CREATE ROLE` / `CREATE USER`](#create-role--create-user)
    - [`GRANT` / `REVOKE` (Permissions)](#grant--revoke-permissions)
    - [`ALTER ROLE`](#alter-role)
  - [3. Database \& Schema Administration](#3-database--schema-administration)
    - [Database Management](#database-management)
    - [Schema Management](#schema-management)
  - [4. Table Management, Constraints \& Partitioning](#4-table-management-constraints--partitioning)
    - [Advanced `CREATE TABLE`](#advanced-create-table)
    - [Table Partitioning](#table-partitioning)
    - [`UNLOGGED` Tables](#unlogged-tables)
  - [5. Advanced Data Manipulation (DML)](#5-advanced-data-manipulation-dml)
    - [`INSERT` with `ON CONFLICT` (Upsert)](#insert-with-on-conflict-upsert)
    - [`RETURNING` Clause](#returning-clause)
    - [`COPY` (Bulk Loading)](#copy-bulk-loading)
  - [6. Advanced Querying (Window Functions \& CTEs)](#6-advanced-querying-window-functions--ctes)
    - [Common Table Expressions (CTEs)](#common-table-expressions-ctes)
    - [Window Functions](#window-functions)
  - [7. Performance Tuning \& Indexing Strategies](#7-performance-tuning--indexing-strategies)
    - [Advanced Indexing](#advanced-indexing)
    - [`EXPLAIN` \& `ANALYZE`](#explain--analyze)
  - [8. Maintenance \& System Configuration](#8-maintenance--system-configuration)
    - [`VACUUM`](#vacuum)
    - [Configuration (`ALTER SYSTEM`)](#configuration-alter-system)
  - [9. Monitoring, Locks \& Troubleshooting](#9-monitoring-locks--troubleshooting)
    - [Active Queries \& Sessions](#active-queries--sessions)
    - [Checking Locks](#checking-locks)

---

## 1. Connecting & psql Power Tools

### `psql` Connection Flags
- **Description**: Connecting to remote servers, specific ports, or running scripts.
- **DBA Scenarios**: Connecting to production servers securely or executing migration scripts.

**Examples**:
```bash
# Connect to a remote host (-h) on a custom port (-p) with a specific user (-U)
psql -h db.prod.server.com -p 5432 -U postgres -d app_db

# Execute a SQL file and exit (useful for CI/CD or migrations)
psql -U postgres -d app_db -f migration_script.sql

# Execute a single command and exit
psql -c "SELECT count(*) FROM users;" -d app_db
```

### Essential Meta Commands (`\`)
- **Description**: Internal `psql` commands for formatting and information.
- **DBA Scenarios**: Formatting unreadable output, timing queries for performance checks, or editing queries.

**Examples**:
```sql
-- Toggle Expanded Display (great for tables with many columns)
\x on
SELECT * FROM complex_table LIMIT 1;

-- Turn on query timing (shows execution time in ms)
\timing on

-- Edit the last query in your default text editor (vim/nano)
\e

-- List all tables including size and description
\dt+

-- List all indexes
\di+
```

---

## 2. User & Role Management (Security)

### `CREATE ROLE` / `CREATE USER`
- **Description**: Creating identities with specific permissions.
- **DBA Scenarios**: Creating a read-only reporting user, an application user, or a superuser.

**Examples**:
```sql
-- Create a standard login user with a password
CREATE USER app_user WITH PASSWORD 'secure_pass_123';

-- Create a Superuser (Use with caution!)
CREATE ROLE admin_user WITH LOGIN SUPERUSER PASSWORD 'admin_pass';

-- Create a role that cannot login (used for grouping permissions)
CREATE ROLE readonly_group;
```

### `GRANT` / `REVOKE` (Permissions)
- **Description**: Managing access control lists (ACLs).
- **DBA Scenarios**: Giving a reporting tool read-access to specific schemas, but no write access.

**Examples**:
```sql
-- Grant usage on a schema (required before accessing tables)
GRANT USAGE ON SCHEMA public TO app_user;

-- Grant SELECT, INSERT, UPDATE on ALL tables in public schema
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;

-- Grant ALL privileges on a specific table
GRANT ALL PRIVILEGES ON users TO admin_user;

-- Revoke write access (make read-only)
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM readonly_group;

-- Grant membership (add user to a group role)
GRANT readonly_group TO reporting_user;
```

### `ALTER ROLE`
- **Description**: Modifying user attributes.
- **DBA Scenarios**: Rotating passwords, setting connection limits, or overriding configuration for specific users.

**Examples**:
```sql
-- Change password
ALTER USER app_user WITH PASSWORD 'new_password_2024';

-- Set a connection limit to prevent resource exhaustion
ALTER USER app_user CONNECTION LIMIT 50;

-- Force a specific search_path or timezone for a specific user
ALTER ROLE app_user SET search_path TO app_schema, public;
ALTER ROLE app_user SET timezone TO 'UTC';
```

---

## 3. Database & Schema Administration

### Database Management
- **Description**: Creating and modifying database containers.
- **DBA Scenarios**: Creating isolated environments or cloning databases for testing.

**Examples**:
```sql
-- Create a database with specific encoding and locale
CREATE DATABASE analytics_db WITH ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8';

-- Clone a database (using it as a template)
-- Note: 'source_db' must have no active connections
CREATE DATABASE test_db WITH TEMPLATE source_db;

-- Rename a database
ALTER DATABASE test_db RENAME TO dev_db;
```

### Schema Management
- **Description**: Logical namespaces to organize tables.
- **DBA Scenarios**: Separating 'hr' data from 'sales' data within the same database, or implementing multi-tenancy.

**Examples**:
```sql
-- Create a new schema
CREATE SCHEMA sales;

-- Create a schema owned by a specific user
CREATE SCHEMA private_data AUTHORIZATION secure_user;

-- Drop a schema and everything inside it (Careful!)
DROP SCHEMA sales CASCADE;
```

---

## 4. Table Management, Constraints & Partitioning

### Advanced `CREATE TABLE`
- **Description**: Creating tables with strict data integrity rules.
- **DBA Scenarios**: Ensuring email uniqueness, defaulting timestamps, and enforcing foreign key relationships.

**Examples**:
```sql
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE, -- Delete order if user is deleted
    order_ref UUID DEFAULT gen_random_uuid(),
    total_amount NUMERIC(10, 2) CHECK (total_amount >= 0), -- Constraint: No negative prices
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);
```

### Table Partitioning
- **Description**: Splitting large tables into smaller, manageable pieces (physically separate files).
- **DBA Scenarios**: Managing a log table with billions of rows by partitioning it by date (Range Partitioning).

**Examples**:
```sql
-- 1. Create the parent table
CREATE TABLE logs (
    log_id SERIAL,
    log_date DATE NOT NULL,
    message TEXT
) PARTITION BY RANGE (log_date);

-- 2. Create partitions for specific ranges
CREATE TABLE logs_2023 PARTITION OF logs 
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE logs_2024 PARTITION OF logs 
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- 3. Detach old partition (Archiving strategy)
ALTER TABLE logs DETACH PARTITION logs_2023;
```

### `UNLOGGED` Tables
- **Description**: Tables that bypass the Write-Ahead Log (WAL).
- **DBA Scenarios**: Temporary data processing or caching where performance is critical and data loss on crash is acceptable.

**Examples**:
```sql
-- Faster writes, but data is lost on server crash
CREATE UNLOGGED TABLE cache_data (
    id SERIAL PRIMARY KEY,
    payload JSONB
);
```

---

## 5. Advanced Data Manipulation (DML)

### `INSERT` with `ON CONFLICT` (Upsert)
- **Description**: Handling duplicate key errors gracefully.
- **DBA Scenarios**: Syncing data where you want to update existing records or insert new ones.

**Examples**:
```sql
-- Try to insert; if ID exists, update the email instead
INSERT INTO users (id, email) VALUES (1, 'new@test.com')
ON CONFLICT (id) 
DO UPDATE SET email = EXCLUDED.email;

-- Try to insert; if ID exists, do nothing
INSERT INTO users (id, email) VALUES (1, 'exists@test.com')
ON CONFLICT (id) DO NOTHING;
```

### `RETURNING` Clause
- **Description**: Getting data back immediately after a modification.
- **DBA Scenarios**: Getting the auto-generated ID of a newly inserted row without running a second SELECT query.

**Examples**:
```sql
-- Insert and immediately get the generated ID and created_at timestamp
INSERT INTO users (username) VALUES ('jdoe') RETURNING id, created_at;

-- Delete rows and see what was deleted
DELETE FROM inactive_users WHERE last_login < '2022-01-01' RETURNING user_id, email;
```

### `COPY` (Bulk Loading)
- **Description**: The fastest way to load/export data.
- **DBA Scenarios**: Importing CSV dumps or exporting reports.

**Examples**:
```sql
-- Import from CSV (Server-side)
COPY users FROM '/path/to/users.csv' WITH (FORMAT csv, HEADER true);

-- Export query results to CSV (Client-side using \copy in psql)
\copy (SELECT * FROM users WHERE active = true) TO 'active_users.csv' WITH CSV HEADER
```

---

## 6. Advanced Querying (Window Functions & CTEs)

### Common Table Expressions (CTEs)
- **Description**: Temporary result sets (`WITH` clause) for readable, modular queries.
- **DBA Scenarios**: breaking down complex logic or handling hierarchical data (Recursive CTEs).

**Examples**:
```sql
-- Standard CTE
WITH regional_sales AS (
    SELECT region, SUM(amount) as total_sales
    FROM orders
    GROUP BY region
)
SELECT * FROM regional_sales WHERE total_sales > 100000;

-- Recursive CTE (e.g., fetching an organizational chart)
WITH RECURSIVE subordinates AS (
    SELECT employee_id, manager_id, name FROM employees WHERE employee_id = 1
    UNION
    SELECT e.employee_id, e.manager_id, e.name
    FROM employees e
    INNER JOIN subordinates s ON s.employee_id = e.manager_id
)
SELECT * FROM subordinates;
```

### Window Functions
- **Description**: Performing calculations across a set of table rows that are somehow related to the current row.
- **DBA Scenarios**: Running totals, ranking items, or finding the "previous" value.

**Examples**:
```sql
-- Rank employees by salary within their department
SELECT name, department, salary,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) as rank
FROM employees;

-- Calculate a running total
SELECT order_date, amount,
       SUM(amount) OVER (ORDER BY order_date) as running_total
FROM orders;

-- Compare current row with previous row (LAG)
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) as previous_month_revenue
FROM monthly_sales;
```

---

## 7. Performance Tuning & Indexing Strategies

### Advanced Indexing
- **Description**: Going beyond standard B-Tree indexes.
- **DBA Scenarios**: Full-text search, JSON indexing, or geospatial data.

**Examples**:
```sql
-- GIN Index (Great for JSONB and Arrays)
CREATE INDEX idx_products_data ON products USING GIN (data);

-- Partial Index (Index only a subset of rows to save space)
CREATE INDEX idx_active_users ON users(email) WHERE status = 'active';

-- Unique Index on multiple columns
CREATE UNIQUE INDEX idx_user_org ON memberships (user_id, organization_id);

-- Concurrent Indexing (Create index without locking the table for writes - Critical for Prod)
CREATE INDEX CONCURRENTLY idx_logs_date ON logs(created_at);
```

### `EXPLAIN` & `ANALYZE`
- **Description**: Understanding how PostgreSQL executes a query.
- **DBA Scenarios**: Debugging slow queries.

**Examples**:
```sql
-- View the query plan (does not run the query)
EXPLAIN SELECT * FROM big_table WHERE id = 500;

-- Run the query and see actual execution times and buffer usage
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM big_table WHERE id = 500;
```

---

## 8. Maintenance & System Configuration

### `VACUUM`
- **Description**: Reclaiming storage occupied by dead tuples.
- **DBA Scenarios**: Preventing database bloat.

**Examples**:
```sql
-- Standard Vacuum (Reclaims space for re-use, doesn't lock)
VACUUM users;

-- Vacuum Analyze (Reclaims space AND updates statistics for the query planner)
VACUUM ANALYZE users;

-- VACUUM FULL (Reclaims disk space to OS, LOCKS TABLE EXCLUSIVELY - Dangerous in Prod)
VACUUM FULL users;
```

### Configuration (`ALTER SYSTEM`)
- **Description**: Changing `postgresql.conf` settings via SQL.
- **DBA Scenarios**: Tuning memory or logging settings without editing files manually.

**Examples**:
```sql
-- View current configuration
SHOW work_mem;

-- Change setting for the current session only
SET work_mem = '64MB';

-- Change setting persistently (requires reload/restart)
ALTER SYSTEM SET work_mem = '64MB';

-- Reload config without restarting DB
SELECT pg_reload_conf();
```

---

## 9. Monitoring, Locks & Troubleshooting

### Active Queries & Sessions
- **Description**: Inspecting what the database is doing right now.
- **DBA Scenarios**: Identifying stuck queries or high load sources.

**Examples**:
```sql
-- See currently running queries
SELECT pid, usename, state, query, age(clock_timestamp(), query_start) as duration
FROM pg_stat_activity
WHERE state != 'idle';

-- Kill a specific session (Forceful)
SELECT pg_terminate_backend(pid);

-- Cancel a query (Gentle)
SELECT pg_cancel_backend(pid);
```

### Checking Locks
- **Description**: Finding queries waiting on resources.
- **DBA Scenarios**: Debugging why an application is "hanging".

**Examples**:
```sql
-- Find blocked queries
SELECT 
    blocked_locks.pid  AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity
    ON blocked_activity.pid = blocked_locks.pid

JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid

JOIN pg_catalog.pg_stat_activity blocking_activity
    ON blocking_activity.pid = blocking_locks.pid

-- IMPORTANT PART: identify real blocking
WHERE NOT blocked_locks.granted
  AND blocking_locks.granted;


