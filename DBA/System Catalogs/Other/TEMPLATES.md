<center><h1> PGSQL Templates: template0 and template1</h1></center>

<br>
<br>

- [In simple words:](#in-simple-words)
- [What is template1?](#what-is-template1)
- [When do i use template1?](#when-do-i-use-template1)
- [What is **`template0`**?](#what-is-template0)
- [When do i use **`template0`**?](#when-do-i-use-template0)
- [Key differences](#key-differences)
- [In simple words:](#in-simple-words-1)
- [How to modufy **`template1`**?](#how-to-modufy-template1)
- [Real life scenario 1: Common Extension Required Everywhere](#real-life-scenario-1-common-extension-required-everywhere)
- [Real life scenario 2: Common Schema for All Databases](#real-life-scenario-2-common-schema-for-all-databases)
- [Real life scenario 3: Secure Default Permissions](#real-life-scenario-3-secure-default-permissions)
- [Real life scenario 4: Common Roles](#real-life-scenario-4-common-roles)
- [Important rule for **`template1`**](#important-rule-for-template1)
- [Can we create a new template database?](#can-we-create-a-new-template-database)
- [Why create custom templates?](#why-create-custom-templates)
- [How to create a custom template (step by step)](#how-to-create-a-custom-template-step-by-step)
  - [Step 1 Create a Normal Database](#step-1-create-a-normal-database)
  - [Step 2 Add required objects](#step-2-add-required-objects)
  - [Step 3 Mark it as a template](#step-3-mark-it-as-a-template)
  - [Using the template](#using-the-template)
- [When I Prefer Custom Templates Over **`template1`**](#when-i-prefer-custom-templates-over-template1)

<br>
<br>


## In simple words:
- PGSQL creates a new database by copying an existing database called template.
- By default, PGSQL uses **`template1`**.
- **`template0`** is a special clean template kept only for safe and customized database creation.

<br>
<br>

---

## What is template1?
- template1 is the default template database.
- If I run **`CREATE DATABASE mydb`**; without mentioning any template, PGSQL automatically copies **`template1`**.
- This means whatever exists inside template1 becomes a part for the new database.

<br>

- Fresh PGSQL installation keeps **`template1`** very basic, but it is modifiable (only objects like **`schema`**, **`extensions`**...).
- I can add comonly required **`extensions`**, **`schemas`**, or default objects into **`template1`**.
- After that, every new database will automatically include those things.

<br>

- Because of this, **`template1`** is used to maintain consistency across databases in an organization.

<br>

- However, the locale and encoding of **`template1`** are fixed at creation time.
- They cannot be changed later because database internals, indexes and text rules are already built using them.

---

<br>
<br>

## When do i use template1?

- I use template1 when:
  - I want a standard database structure
  - All databases should follow the same rules.
  - I want default extensions or schemas to exist automatically
- This is the template used in daily database creation.

---

<br>
<br>

## What is **`template0`**?

- **`template0`** is PGSQL's original, untouched factory copy of a database.

<br>

- It is kept in a clean state and is not meant to be modified.
- PGSQL intentionally protects it so that one safe reference database always exists.

<br>

- **`template0`** solves this by acting as a permanent clean starting point.

---

<br>
<br>

## When do i use **`template0`**?
- I use **`template0`** when:
  - I need a different <abbr title="Locale is simply a set of language rules that PGSQL follows when it works with text. It decides how strings are compared and sorted, how characters are treated, and which text comes first or later. Because of this, locale direcly affects ORDER BY, text indexes, and string comparisons inside the database.">locale</abbr>.
  - I need a different <abbr title="Encoding defines which characters a database can store and understand. UTF-8 supports al languages and symbols, which is why it is the safest and most widely used encoding in real production systems.">encoding (UTF-8)</abbr>.
  - I want a completely clean database without custom objects.
Example:
```sql
CREATE DATABASE mydb
TEMPLATE template0
ENCODING 'UTF8'
LC_COLLATE 'en_US.UTF-8'
LC_CTYPE 'en_US.UTF-8';
```

> This is not possible with **`template0`** if the locale or encoding does not match.

---

<br>
<br>

## Key differences
- **`template1`**:
  - Default template
  - Modifiable
  - Used for standard database creation
  - Locale and encoding are fixed
- **`template0`**
  - Clean and read-only
  - Not modifiable
  - Used for custom locale / encoding
  - Acts as a safety backup template

---

<br>
<br>
<br>
<br>

<center><h1>Modifying template1 and Creating Custom Templates in PGSQL</h1></center>

<br>

## In simple words:
- PGSQL creates new databases by copying a template database.
- **`template1`** is the default template and can be modified to include common objects.
- Apart from template1, I can also create my own custom template database for specific use cases.

---

<br>
<br>

## How to modufy **`template1`**?

- Modifying **`template1`** means adding or changing common database objects, not changing its identity.

<br>

- I cannot change:
  - locale
  - encoding
- I can change:
  - extensions
  - schemas
  - roles
  - default permissions

To modify it, I simply connect to **`template1`** like a normal database:
```bash
\c template1
```

After this anything I create here will be copied into every future database created without specifying a template.

---

<br>
<br>

## Real life scenario 1: Common Extension Required Everywhere

If every application database needs UUID support, I install the extension once in **`template1`**.
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

> Now, whenever a new database is created, this extension is already available.
> This avoids manual extension installation and ensures consistency.

<br>
<details>
<summary><mark><b>uuid-ossp Explained</b></mark></summary>
<br>

This **`uuid-ossp`** extension is used to generate UUID values direclty inside PGSQL. It helps create globally unique IDs that wont clash across tables or systems, which is especially useful in distributed applications and modern systems where auto-increment IDs are not enough.

**Common use case commands for **`uuid-ossp`**:**
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```
> used once to enable UUID functions in the database.

<br>

```sql
SELECT uuid_generate_v4();
```
> Generates a random UUID, useful when you need a unique ID immediately.

<br>

```sql
CREATE TABLE orders(
    id UUID DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP DEFAULT now()
);
```
> Automatically creates a unique ID for every new row, without relying on auto-increment.

</details>
<br>

---

<br>
<br>

## Real life scenario 2: Common Schema for All Databases
Many companies want a standard schema like **`audit`** or **`logging`** in all database.
```sql
CREATE SCHEMA audit;
```
> Every new database will now automatically include the **`audit`** schema.

---

<br>
<br>

## Real life scenario 3: Secure Default Permissions
By default, the public role has broad permissions. <br>
In enterprise environments, this is often restricted.
```bash
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public to PUBLIC;
```

> This setup first removes all default permissions on the public schema from everyone, then gives back only basic access. In simple terms, users can see and use objects inside the schema, but they cannot create or modify anything there unless extra permissions are explicitly granted.

> This ensures that all newly created databaes follow the same security baseline.

---

<br>
<br>

## Real life scenario 4: Common Roles
If every database needs application roles like read-only or read-write, I can create them once.
```sql
CREATE ROLE app_read;
CREATE ROLE app_write;
```
> These roles will then exist automatically in every new database.

---

<br>
<br>

## Important rule for **`template1`**
- **`template1`** should contain only global and reusable objects.
- I should never add:
  - application-specific tables
  - test data
  - experiment objects
- Anything placed in **`template1`** is copied everywhere, so mistakes multiply fast.

---

<br>
<br>

## Can we create a new template database?
- Yes, PGSQL fully supports custom template databases.
- This is useful when different type of databases needs different base structures.

---

<br>
<br>

## Why create custom templates?
- One template does not fit all.
- Examples:
  - OLTP application databases
  - Reporting Databases
  - Analytics Databases
- Each type may require different schemas, extensions, or settings.

---

<br>
<br>

## How to create a custom template (step by step)
### Step 1 Create a Normal Database
```sql
CREATE DATABASE reporting_base;
```

<br>
<br>

### Step 2 Add required objects
```sql
\c reporting_base
CREATE SCHEMA reports;
CREATE EXTENSION pg_stat_ststements;
```

<br>
<br>

### Step 3 Mark it as a template
```sql
UPDATE pg_database
SET datistemplate = true
WHERE datname = 'reporting_base';
```
> Now **`reporting_base`** acts as a template.

---

<br>
<br>

### Using the template
```sql
CREATE DATABASE sales_reporting
TEMPLATE reporting_base;
```
> The new database will be an exact copy of **`reporting_base`**.

---

<br>
<br>

## When I Prefer Custom Templates Over **`template1`**
- I prefer custom templates when:
  - I want stricter control
  - I dont want to pollute **`template1`**
  - Different teams needs different database blueprints
- Many DBAs leave **`template1`** mostly untouched and rely on custom templates instead.

---