<center>

# 02 WAL Level, archive_mode, and archive_command (How WAL Archiving Actually Works)
</center>

<br>
<br>


- [02 WAL Level, archive\_mode, and archive\_command (How WAL Archiving Actually Works)](#02-wal-level-archive_mode-and-archive_command-how-wal-archiving-actually-works)
  - [In simple words](#in-simple-words)
  - [Why configuration matters](#why-configuration-matters)
  - [`wal_level` (how much information WAL stores)](#wal_level-how-much-information-wal-stores)
    - [What `wal_level` means](#what-wal_level-means)
    - [Which `wal_level` is required](#which-wal_level-is-required)
  - [archive\_mode (turns archiving on)](#archive_mode-turns-archiving-on)
    - [What archive\_mode does](#what-archive_mode-does)
  - [`archive_command` (how WAL is archived)](#archive_command-how-wal-is-archived)
    - [What `archive_command` is](#what-archive_command-is)
  - [A simple `archive_command` example](#a-simple-archive_command-example)
  - [Why `archive_command` failures are dangerous](#why-archive_command-failures-are-dangerous)
  - [Testing WAL archiving](#testing-wal-archiving)
  - [Reload vs restart](#reload-vs-restart)
  - [Security and permissions](#security-and-permissions)
  - [Common DBA mistakes](#common-dba-mistakes)
  - [Final mental model](#final-mental-model)
  - [One-line explanation](#one-line-explanation)


<br>
<br>

## In simple words

**To make WAL archiving work, PostgreSQL needs three settings to cooperate**:
* `wal_level`
* `archive_mode`
* `archive_command`

If even one is wrong, WAL archiving silently fails.

---

<br>
<br>

## Why configuration matters

PostgreSQL never guesses your intention.

**Unless these settings are explicitly correct:**
* WAL files are recycled
* change history is lost
* PITR becomes impossible

That’s why WAL archiving failures are usually **configuration failures**.

---

<br>
<br>

## `wal_level` (how much information WAL stores)

### What `wal_level` means

`wal_level` defines **how much detail** PostgreSQL writes into WAL.

**Common values:**

* `minimal` (*just survive crashes*)
* `replica` (*backups + replicas*)
* `logical` (*stream changes outside PGSQL*)

<br>
<br>

- `wal_level` decides how much information PGSQL writes into WAL.
- More information = more features, but also more WAL size.

<br>

- **`minimal`**: This writes only the bare minimum WAL needed for crash recovery. It’s lightweight and fast, but you <mark><b>cannot use replication or PITR</b></mark>. This is fine for simple, standalone databases where you only care about basic safety.

<br>

- **`replica`**: This writes enough WAL data <mark><b>to support physical replication and PITR</b></mark>. It’s the most common setting in production systems. You get crash recovery, replicas, and backups, with acceptable overhead.

<br>

- **`logical`**: This writes the most detailed WAL. In addition to everything in replica, it <mark><b>includes information needed for logical decoding</b></mark>. This <u><b>allows logical</b></u> <u><b>replication</b></u>, <u><b>change data capture</b></u>, and <u><b>streaming changes to external systems</b></u>. It produces more WAL but enables advanced architectures.

---

<br>
<br>

### Which `wal_level` is required

**For WAL archiving:**

```conf
wal_level = replica
```

**Why:**

* `minimal` does not generate enough WAL
* `replica` guarantees crash recovery and PITR

Logical replication requires `logical`, but PITR does not.

---

<br>
<br>

## archive_mode (turns archiving on)

### What archive_mode does

**`archive_mode` tells PostgreSQL:**

> “Do not delete WAL until it is archived somewhere safe.”

**Enable it with:**

```conf
archive_mode = on
```

Without this, PGSQL reuses WAL files automatically.

---

<br>
<br>

## `archive_command` (how WAL is archived)

### What `archive_command` is

`archive_command` is a **shell command** executed every time a WAL segment is completed.

**PostgreSQL runs it like:**

```bash
archive_command %p %f
```

**Where:**

* `%p` = full path to WAL file
* `%f` = WAL file name

---

<br>
<br>

## A simple `archive_command` example

```conf
archive_command = 'cp %p /backup/wal_archive/%f'
```

**Meaning:**
* copy WAL file to archive directory
* only mark success if command exits with 0

If command fails, PostgreSQL retries.

---

<br>
<br>

## Why `archive_command` failures are dangerous

**If `archive_command`:**
* returns non-zero
* hangs
* writes to full disk

**Then:**
* WAL is not archived
* WAL cannot be recycled
* `pg_wal` directory grows
* database may stop

This is a classic production outage.

---

<br>
<br>

## Testing WAL archiving

**Always verify:**

```sql
SELECT * FROM pg_stat_archiver;
```

**Check:**
* `archived_count` increases
* `failed_count` stays zero

Never trust configuration blindly.

---

<br>
<br>

## Reload vs restart

**Changes to these parameters require:**
* `wal_level` → restart
* `archive_mode` → restart
* `archive_command` → reload

Restart planning is required.

---

<br>
<br>

## Security and permissions

**`archive_command` runs as:**
* PostgreSQL OS user

**Ensure:**
* archive directory permissions are correct
* command cannot be exploited

Security mistakes here leak data.

---

<br>
<br>

## Common DBA mistakes

* forgetting restart after `wal_level` change
* wrong archive path
* no monitoring of archive failures
* assuming archive = backup

WAL archiving is only as good as its validation.

---

<br>
<br>

## Final mental model

* `wal_level` = how much history
* `archive_mode` = keep history
* `archive_command` = where history goes

All three must work together.

---

<br>
<br>

## One-line explanation

PostgreSQL WAL archiving depends on `wal_level` for data detail, `archive_mode` to enable archiving, and `archive_command` to store WAL files safely.

<br>
<br>
<br>
<br>



