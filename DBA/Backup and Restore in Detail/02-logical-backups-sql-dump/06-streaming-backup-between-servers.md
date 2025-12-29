# 06 Streaming Backups Between Servers in PostgreSQL

<br>
<br>

- [06 Streaming Backups Between Servers in PostgreSQL](#06-streaming-backups-between-servers-in-postgresql)
  - [In simple words](#in-simple-words)
  - [Why streaming backups exist](#why-streaming-backups-exist)
  - [Most common streaming pattern](#most-common-streaming-pattern)
  - [Streaming between two different servers](#streaming-between-two-different-servers)
  - [Why this works safely](#why-this-works-safely)
  - [When streaming is a good choice](#when-streaming-is-a-good-choice)
  - [Limitations of streaming backups](#limitations-of-streaming-backups)
  - [Streaming with compression](#streaming-with-compression)
  - [Handling errors during streaming](#handling-errors-during-streaming)
  - [Streaming vs file-based backups](#streaming-vs-file-based-backups)
  - [DBA checklist before streaming](#dba-checklist-before-streaming)
  - [Final mental model](#final-mental-model)
  - [One-line explanation (interview ready)](#one-line-explanation-interview-ready)

<br>
<br>


## In simple words

- Streaming backup means copying data from one PostgreSQL server to another **without creating an intermediate dump file**.
- Data flows directly from source to target using a pipe.
- This is fast, clean, and very useful for migrations.

---

<br>
<br>

## Why streaming backups exist

- Creating dump files:
  * needs disk space
  * takes extra time
  * creates cleanup work

<br>

- Streaming avoids this by:
  * reading from source
  * writing to target immediately

No file sits in the middle.

---

<br>
<br>

## Most common streaming pattern

```bash
pg_dump source_db | psql -d target_db
```

What happens internally:
* `pg_dump` reads data from source
* output is sent through pipe
* psql receives and executes SQL
* target database is rebuilt live

---

<br>
<br>

## Streaming between two different servers

```bash
pg_dump -h source_ip -U src_user source_db \
| psql -h target_ip -U tgt_user -d target_db
```

This works across:
* different machines
* different data centers
* different PostgreSQL versions

---

<br>
<br>

## Why this works safely

* `pg_dump` uses a consistent snapshot
* `psql` executes commands in order
* data integrity is preserved

Users can keep working on source during streaming.

---

<br>
<br>

## When streaming is a good choice

I use streaming when:
* migrating databases
* cloning production to staging
* disk space is limited
* one-time transfers are needed

It is fast and simple.

---

<br>
<br>

## Limitations of streaming backups

Streaming backups:
* cannot be resumed if interrupted
* provide no backup file for reuse
* depend heavily on network stability

If network drops, restore fails.

---

<br>
<br>

## Streaming with compression

```bash
pg_dump source_db | gzip | gunzip | psql -d target_db

# This command takes a live backup of source_db, compresses it, immediately decompresses it, and pipes it straight into target_db. In simple words, it copies data from one database to another in a single flow without creating any dump file on disk.
```

- Used when network bandwidth is limited.
- CPU cost increases.

---

<br>
<br>

## Handling errors during streaming

If error occurs:
* streaming stops immediately
* partial data may exist

<br>

Best practice:
* restore into empty database
* drop and retry on failure

---

<br>
<br>

## Streaming vs file-based backups

Streaming:

* faster
* less disk usage
* single-use


<br>

File-based:

* reusable
* resumable
* safer for long-term storage

Choose based on situation.

---

<br>
<br>

## DBA checklist before streaming

Before streaming I ensure:

* target DB is empty
* required roles exist
* permissions are correct
* network is stable

Preparation prevents failures.

---

<br>
<br>

## Final mental model

* Streaming = pipe + live restore
* No files in between
* Fast but fragile
* Best for migrations

---

<br>
<br>

## One-line explanation (interview ready)

Streaming backup transfers a logical dump directly from one PostgreSQL server to another using pipes, avoiding intermediate files.
