# PostgreSQL Commands Handbook

A comprehensive guide to essential PostgreSQL commands, complete with descriptions, real-world use cases, and practical examples.

## Table of Contents

- [PostgreSQL Commands Handbook](#postgresql-commands-handbook)
  - [Table of Contents](#table-of-contents)
  - [Connecting \& Meta Commands](#connecting--meta-commands)
    - [1. `psql`](#1-psql)
    - [2. `\l` (List Databases)](#2-l-list-databases)
    - [3. `\c` (Connect)](#3-c-connect)
    - [4. `\dt` (List Tables)](#4-dt-list-tables)
    - [5. `\d` (Describe Table)](#5-d-describe-table)
    - [6. `\du` (List Users)](#6-du-list-users)
    - [7. `\q` (Quit)](#7-q-quit)
  - [Database \& Table Operations](#database--table-operations)
    - [8. `CREATE DATABASE`](#8-create-database)
    - [9. `DROP DATABASE`](#9-drop-database)
    - [10. `CREATE TABLE`](#10-create-table)
    - [11. `DROP TABLE`](#11-drop-table)
    - [12. `ALTER TABLE`](#12-alter-table)
    - [13. `TRUNCATE`](#13-truncate)
  - [Data Manipulation (CRUD)](#data-manipulation-crud)
    - [14. `INSERT`](#14-insert)
    - [15. `SELECT`](#15-select)
    - [16. `UPDATE`](#16-update)
    - [17. `DELETE`](#17-delete)
  - [Filtering \& Sorting](#filtering--sorting)
    - [18. `WHERE`](#18-where)
    - [19. `ORDER BY`](#19-order-by)
    - [20. `LIMIT / OFFSET`](#20-limit--offset)
    - [21. `LIKE / ILIKE`](#21-like--ilike)
    - [22. `IN / BETWEEN`](#22-in--between)
  - [Joins \& Aggregations](#joins--aggregations)
    - [23. `JOINS`](#23-joins)
    - [24. `GROUP BY`](#24-group-by)
    - [25. `HAVING`](#25-having)
    - [26. `Aggregate Functions`](#26-aggregate-functions)
  - [Advanced PostgreSQL](#advanced-postgresql)
    - [27. `CREATE INDEX`](#27-create-index)
    - [28. `TRANSACTIONS`](#28-transactions)
    - [29. `VIEWS`](#29-views)
    - [30. `JSONB Operations`](#30-jsonb-operations)
    - [31. `EXPLAIN`](#31-explain)
    - [32. `UPSERT (ON CONFLICT)`](#32-upsert-on-conflict)

---

## Connecting & Meta Commands

### 1. `psql`
- **Description**: The interactive terminal for working with PostgreSQL.
- **Real-World Use Case**: Logging into the database server from the command line to perform administration tasks or run queries manually.

**Examples**:
```bash
# Login as the default 'postgres' user
psql -U postgres
# Login to a specific database (mydb) as a specific user (myuser)
psql -U myuser -d mydb
```

### 2. `\l` (List Databases)
- **Description**: Lists all databases existing on the current server instance.
- **Real-World Use Case**: To verify if a database exists or to see the correct name of the database you want to connect to.

**Examples**:
```sql
-- Inside psql terminal
\l
```

### 3. `\c` (Connect)
- **Description**: Connects to a different database within the current `psql` session.
- **Real-World Use Case**: You just created a new database `shop_db` and want to switch to it to start creating tables.

**Examples**:
```sql
-- Connect to the 'shop_db' database
\c shop_db
```

### 4. `\dt` (List Tables)
- **Description**: Lists all tables in the current database (usually in the `public` schema).
- **Real-World Use Case**: To quickly check what tables are available in the database you are currently connected to.

**Examples**:
```sql
-- List all tables
\dt
-- List tables in a specific schema
\dt myschema.*
```

### 5. `\d` (Describe Table)
- **Description**: Displays details about a specific table, including column names, data types, constraints, and indexes.
- **Real-World Use Case**: When you need to write an `INSERT` statement but forgot the column names or data types of a table.

**Examples**:
```sql
-- Describe the 'users' table
\d users
```

### 6. `\du` (List Users)
- **Description**: Lists all database roles (users) and their attributes (like superuser status).
- **Real-World Use Case**: To check if a specific user exists or if they have the correct permissions (e.g., `Create DB`).

**Examples**:
```sql
\du
```

### 7. `\q` (Quit)
- **Description**: Exits the `psql` terminal.
- **Real-World Use Case**: When you are finished with your database session and want to return to the shell.

**Examples**:
```sql
\q
```

---

## Database & Table Operations

### 8. `CREATE DATABASE`
- **Description**: Creates a new database container.
- **Real-World Use Case**: Setting up a fresh environment for a new microservice or project.

**Examples**:
```sql
-- Create a simple database
CREATE DATABASE my_project;
-- Create a database owned by a specific user
CREATE DATABASE my_project OWNER db_admin;
```

### 9. `DROP DATABASE`
- **Description**: Deletes a database permanently.
- **Real-World Use Case**: Removing a test database after automated tests have finished running.

**Examples**:
```sql
-- Delete a database (fail if it doesn't exist)
DROP DATABASE old_db;
-- Delete only if it exists
DROP DATABASE IF EXISTS old_db;
```

### 10. `CREATE TABLE`
- **Description**: Defines a new table structure with columns and data types.
- **Real-World Use Case**: Defining the schema for your application, such as a `users` table to store login info.

**Examples**:
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 11. `DROP TABLE`
- **Description**: Deletes a table and all its data permanently.
- **Real-World Use Case**: Cleaning up a temporary table used for data migration.

**Examples**:
```sql
DROP TABLE temp_users;
```

### 12. `ALTER TABLE`
- **Description**: Modifies the structure of an existing table (add/remove columns, change types).
- **Real-World Use Case**: Adding a `phone_number` column to the `users` table after a feature request update.

**Examples**:
```sql
-- Add a new column
ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);
-- Rename a column
ALTER TABLE users RENAME COLUMN username TO user_handle;
```

### 13. `TRUNCATE`
- **Description**: Removes all rows from a table very quickly but keeps the table structure. Faster than `DELETE`.
- **Real-World Use Case**: Clearing out a staging table before importing a fresh batch of daily data.

**Examples**:
```sql
TRUNCATE TABLE session_logs;
```

---

## Data Manipulation (CRUD)

### 14. `INSERT`
- **Description**: Adds new rows of data into a table.
- **Real-World Use Case**: Registering a new user in your application.

**Examples**:
```sql
-- Insert a single row
INSERT INTO users (username, email) VALUES ('jdoe', 'john@example.com');
-- Insert multiple rows
INSERT INTO users (username, email) VALUES 
('alice', 'alice@test.com'), 
('bob', 'bob@test.com');
```

### 15. `SELECT`
- **Description**: Retrieves data from a database.
- **Real-World Use Case**: Fetching the list of all active products to display on a webpage.

**Examples**:
```sql
-- Select all columns
SELECT * FROM users;
-- Select specific columns
SELECT username, email FROM users;
```

### 16. `UPDATE`
- **Description**: Modifies existing data in a table.
- **Real-World Use Case**: Changing a user's password or updating an order status from 'Pending' to 'Shipped'.

**Examples**:
```sql
-- Update the email for a specific user
UPDATE users SET email = 'new_email@test.com' WHERE id = 1;
```

### 17. `DELETE`
- **Description**: Removes specific rows from a table.
- **Real-World Use Case**: Removing a user account when they request account deletion.

**Examples**:
```sql
-- Delete a specific user
DELETE FROM users WHERE id = 5;
```

---

## Filtering & Sorting

### 18. `WHERE`
- **Description**: Filters the results to only show rows that meet a specific condition.
- **Real-World Use Case**: Finding a user by their email address during login.

**Examples**:
```sql
SELECT * FROM users WHERE email = 'john@example.com';
SELECT * FROM orders WHERE total_amount > 100;
```

### 19. `ORDER BY`
- **Description**: Sorts the result set in ascending (`ASC`) or descending (`DESC`) order.
- **Real-World Use Case**: Showing a list of blog posts with the most recent ones at the top.

**Examples**:
```sql
-- Sort users alphabetically by name
SELECT * FROM users ORDER BY username ASC;
-- Sort orders by newest first
SELECT * FROM orders ORDER BY created_at DESC;
```

### 20. `LIMIT / OFFSET`
- **Description**: `LIMIT` restricts the number of rows returned. `OFFSET` skips a specific number of rows.
- **Real-World Use Case**: Implementing pagination on a website (e.g., "Page 2" of results).

**Examples**:
```sql
-- Get the first 10 users
SELECT * FROM users LIMIT 10;
-- Get 10 users, skipping the first 10 (Page 2)
SELECT * FROM users LIMIT 10 OFFSET 10;
```

### 21. `LIKE / ILIKE`
- **Description**: Performs pattern matching. `ILIKE` is PostgreSQL-specific and is case-insensitive.
- **Real-World Use Case**: Searching for products where the name contains "phone".

**Examples**:
```sql
-- Case-sensitive search for names starting with 'J'
SELECT * FROM users WHERE username LIKE 'J%';
-- Case-insensitive search for names containing 'john'
SELECT * FROM users WHERE username ILIKE '%john%';
```

### 22. `IN / BETWEEN`
- **Description**: `IN` checks if a value matches any value in a list. `BETWEEN` checks if a value is within a range.
- **Real-World Use Case**: Filtering orders that have a status of either 'Shipped' or 'Delivered'.

**Examples**:
```sql
SELECT * FROM orders WHERE status IN ('Shipped', 'Delivered');
SELECT * FROM products WHERE price BETWEEN 10 AND 50;
```

---

## Joins & Aggregations

### 23. `JOINS`
- **Description**: Combines rows from two or more tables based on a related column.
- **Real-World Use Case**: Fetching orders along with the name of the user who placed them.

**Examples**:
```sql
-- INNER JOIN: Only records that match in both tables
SELECT users.username, orders.order_date 
FROM users 
INNER JOIN orders ON users.id = orders.user_id;

-- LEFT JOIN: All records from left table (users), even if they have no orders
SELECT users.username, orders.id 
FROM users 
LEFT JOIN orders ON users.id = orders.user_id;
```

### 24. `GROUP BY`
- **Description**: Groups rows that have the same values into summary rows.
- **Real-World Use Case**: Counting how many users live in each country.

**Examples**:
```sql
SELECT country, COUNT(*) FROM users GROUP BY country;
```

### 25. `HAVING`
- **Description**: Filters groups created by `GROUP BY`. Similar to `WHERE`, but for aggregated data.
- **Real-World Use Case**: Finding countries that have more than 100 users.

**Examples**:
```sql
SELECT country, COUNT(*) 
FROM users 
GROUP BY country 
HAVING COUNT(*) > 100;
```

### 26. `Aggregate Functions`
- **Description**: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.
- **Real-World Use Case**: Calculating the total revenue for the day.

**Examples**:
```sql
SELECT SUM(total_amount) FROM orders WHERE order_date = CURRENT_DATE;
SELECT AVG(price) FROM products;
```

---

## Advanced PostgreSQL

### 27. `CREATE INDEX`
- **Description**: Creates a data structure that improves the speed of data retrieval operations.
- **Real-World Use Case**: Speeding up search queries on the `email` column which is frequently accessed.

**Examples**:
```sql
CREATE INDEX idx_users_email ON users(email);
```

### 28. `TRANSACTIONS`
- **Description**: Bundles steps into a single operation. Either all steps succeed (`COMMIT`), or all fail (`ROLLBACK`).
- **Real-World Use Case**: Transferring money between bank accounts (subtract from A, add to B).

**Examples**:
```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

### 29. `VIEWS`
- **Description**: A virtual table based on the result-set of an SQL statement.
- **Real-World Use Case**: Creating a simplified report of "Active Premium Users" without giving direct table access.

**Examples**:
```sql
CREATE VIEW premium_users AS
SELECT id, username, email FROM users WHERE type = 'premium';

-- Query it like a table
SELECT * FROM premium_users;
```

### 30. `JSONB Operations`
- **Description**: Storing and querying JSON data efficiently (PostgreSQL specialty).
- **Real-World Use Case**: Storing flexible product attributes (color, size, weight) without creating new columns.

**Examples**:
```sql
-- Create table with JSONB column
CREATE TABLE products (id SERIAL, data JSONB);
-- Insert JSON data
INSERT INTO products (data) VALUES ('{"name": "TV", "attributes": {"resolution": "4K"}}');
-- Query inside JSON
SELECT data->>'name' FROM products WHERE data->'attributes'->>'resolution' = '4K';
```

### 31. `EXPLAIN`
- **Description**: Shows the execution plan of a statement.
- **Real-World Use Case**: Debugging slow queries to see if they are using indexes properly.

**Examples**:
```sql
EXPLAIN SELECT * FROM users WHERE email = 'test@test.com';
-- EXPLAIN ANALYZE actually runs the query to get timing
EXPLAIN ANALYZE SELECT * FROM users;
```

### 32. `UPSERT (ON CONFLICT)`
- **Description**: "Update or Insert". Tries to insert a row; if a conflict (e.g., duplicate ID) occurs, it updates the existing row instead.
- **Real-World Use Case**: Syncing data from an external API where you don't know if the record already exists locally.

**Examples**:
```sql
INSERT INTO settings (key, value) 
VALUES ('theme', 'dark') 
ON CONFLICT (key) 
DO UPDATE SET value = 'dark';
```