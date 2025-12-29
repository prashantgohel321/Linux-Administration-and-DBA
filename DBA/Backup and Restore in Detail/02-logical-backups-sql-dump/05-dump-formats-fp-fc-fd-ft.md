# 05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)

<br>
<br>

- [05 PostgreSQL Dump Formats: -Fp, -Fc, -Fd, -Ft (Explainable Guide)](#05-postgresql-dump-formats--fp--fc--fd--ft-explainable-guide)
  - [In simple words](#in-simple-words)
  - [Overview of available dump formats](#overview-of-available-dump-formats)
  - [Plain format (`-Fp`)](#plain-format--fp)
    - [What it is](#what-it-is)
    - [Characteristics](#characteristics)
    - [Pros](#pros)
    - [Cons](#cons)
    - [When I use it](#when-i-use-it)
  - [Custom format (`-Fc`)](#custom-format--fc)
    - [What it is](#what-it-is-1)
    - [Characteristics](#characteristics-1)
    - [Pros](#pros-1)
    - [Cons](#cons-1)
    - [When I use it](#when-i-use-it-1)
  - [Directory format (`-Fd`)](#directory-format--fd)
    - [What it is](#what-it-is-2)
    - [Characteristics](#characteristics-2)
    - [Pros](#pros-2)
    - [Cons](#cons-2)
    - [When I use it](#when-i-use-it-2)
  - [Tar format (`-Ft`)](#tar-format--ft)
    - [What it is](#what-it-is-3)
    - [Characteristics](#characteristics-3)
    - [Pros](#pros-3)
    - [Cons](#cons-3)
    - [When I use it](#when-i-use-it-3)
  - [Restore tool comparison](#restore-tool-comparison)
  - [Performance reality](#performance-reality)
  - [DBA recommendation (real world)](#dba-recommendation-real-world)
  - [Common mistakes to avoid](#common-mistakes-to-avoid)
  - [Final mental model](#final-mental-model)
  - [One‑line explanation (interview ready)](#oneline-explanation-interview-ready)

<br>
<br>


## In simple words

- When I take a logical backup with `pg_dump`, I must choose **how the backup is stored**.
- That choice is called the **dump format**.

<br>

- The format decides:
  * file structure
  * restore speed
  * flexibility
  * whether selective and parallel restore is possible

- Choosing the wrong format is a common DBA mistake.

---

<br>
<br>

## Overview of available dump formats

- PostgreSQL supports four main dump formats:
  * `-Fp` → Plain SQL (default)
  * `-Fc` → Custom format
  * `-Fd` → Directory format
  * `-Ft` → Tar format

- Each format has a specific purpose.

---

<br>
<br>

## Plain format (`-Fp`)

### What it is

A human‑readable SQL file containing CREATE, INSERT, and GRANT statements.

```bash
pg_dump -Fp mydb > mydb.sql
```

<br>
<br>

### Characteristics
* text file
* readable and editable
* restored using `psql`

<br>
<br>

### Pros
* very simple
* easy to inspect or modify
* no special restore tool needed

<br>
<br>

### Cons
* largest file size
* slow restore
* no selective restore
* no parallel restore

<br>
<br>

### When I use it
* small databases
* learning and debugging
* manual inspection needed

---

<br>
<br>

## Custom format (`-Fc`)

### What it is

A compressed binary dump designed specifically for PostgreSQL.

```bash
pg_dump -Fc mydb > mydb.dump
```

<br>
<br>

### Characteristics
* binary format
* requires `pg_restore`
* internally structured

<br>
<br>

### Pros
* smaller size
* faster restore
* supports selective restore
* supports parallel restore

<br>
<br>

### Cons
* not human‑readable
* cannot be edited manually

<br>
<br>

### When I use it
* production backups
* medium to large databases
* when restore speed matters

---

<br>
<br>

## Directory format (`-Fd`)

### What it is

A folder containing separate files for database objects.

```bash
pg_dump -Fd mydb -f mydb_dir
```

<br>
<br>

### Characteristics
* one directory, many files
* best for parallel restore

<br>
<br>

### Pros
* fastest restore
* highest flexibility
* ideal for very large databases

<br>
<br>

### Cons
* not a single file
* harder to move manually

<br>
<br>

### When I use it
* very large databases
* enterprise systems
* time‑critical restores

---

<br>
<br>

## Tar format (`-Ft`)

### What it is

A `tar` archive containing dump contents.

```bash
pg_dump -Ft mydb > mydb.tar
```

<br>
<br>

### Characteristics
* single archive file
* intermediate flexibility

<br>
<br>

### Pros
* single file
* supports `pg_restore`

<br>
<br>

### Cons
* slower than custom and directory formats
* less commonly used

<br>
<br>

### When I use it
* when I need a single file but want `pg_restore` features

---

<br>
<br>

## Restore tool comparison

| Dump Format | Restore Tool | Selective Restore | Parallel Restore |
| ----------- | ------------ | ----------------- | ---------------- |
| -Fp         | psql         | No                | No               |
| -Fc         | pg_restore   | Yes               | Yes              |
| -Fd         | pg_restore   | Yes               | Yes (Best)       |
| -Ft         | pg_restore   | Yes               | Limited          |

---

<br>
<br>

## Performance reality

* Backup speed is similar across formats
* Restore speed varies significantly
* Parallel restore makes the biggest difference

Format choice matters most during restore, not backup.

---

<br>
<br>

## DBA recommendation (real world)
* Small DB → `-Fp`
* Medium / Large DB → `-Fc`
* Very Large / Mission‑critical DB → `-Fd`

Avoid default plain format in production unless you know why you are using it.

---

<br>
<br>

## Common mistakes to avoid
* Using plain format for huge databases
* Not planning restore strategy
* Choosing format without testing restore

Backup format must match recovery expectations.

---

<br>
<br>

## Final mental model

* Dump format defines restore power
* pg_restore needs structured formats
* Parallel restore saves hours
* Production ≠ plain SQL

---

<br>
<br>

## One‑line explanation (interview ready)

PostgreSQL dump formats define how backups are stored and restored, directly affecting flexibility, restore speed, and recovery options.
