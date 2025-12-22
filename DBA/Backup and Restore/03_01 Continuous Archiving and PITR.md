# Continuous Archiving and PITR – Step‑By‑Step Real Scenario Guide

- [Continuous Archiving and PITR – Step‑By‑Step Real Scenario Guide](#continuous-archiving-and-pitr--stepbystep-real-scenario-guide)
  - [Continuous Archiving](#continuous-archiving)
  - [Point-in-Time Recover (PITR)](#point-in-time-recover-pitr)
  - [Simple Example](#simple-example)
  - [Scenario Overview](#scenario-overview)
  - [Step 1: Check Current WAL Level](#step-1-check-current-wal-level)
  - [Step 2: Enable Archiving](#step-2-enable-archiving)
  - [Step 3: Take a Base Backup (Physical Backup)](#step-3-take-a-base-backup-physical-backup)
  - [Step 4: Do Regular Work Normally](#step-4-do-regular-work-normally)
  - [Step 5: Simulate a Disaster](#step-5-simulate-a-disaster)
  - [Step 6: Decide Target Recovery Time](#step-6-decide-target-recovery-time)
  - [Step 7: Stop PostgreSQL Before Restore](#step-7-stop-postgresql-before-restore)
  - [Step 8: Replace Current Data Directory With Base Backup](#step-8-replace-current-data-directory-with-base-backup)
  - [Step 9: Configure Recovery](#step-9-configure-recovery)
  - [Step 10: Start PostgreSQL and Let Recovery Run](#step-10-start-postgresql-and-let-recovery-run)
  - [Step 11: Why This Flow Was Successful](#step-11-why-this-flow-was-successful)
  - [Step 12: Important Messages From This Scenario](#step-12-important-messages-from-this-scenario)


## Continuous Archiving

- We can think of continuous archiving as PostgreSQL's way of saving every single change (WAL files) to a safe place outside the database as soon as they are complete. This creates a full history of everything that happened in the database.

<br>
<br>

## Point-in-Time Recover (PITR)

- PITR lets us restore the database not just to the last backup, but to any exact moment in time by replaying those saved WAL files.

<br>
<br>

## Simple Example

Imagine yesterday we took a full base backup at 10:00 AM.
```bash
pg_basebackup -D /var/lib/pgsql/backups/full_10am -F tar -X stream -P
```

<br>
<details>
<summary><b>Breakdown of above command</b></summary>
<br>

- **`pg_basebackup`**: Tool to take a full physical PostgreSQL base backup.
- **`-D /var/lib/pgsql/backups/full_10am`**: `-D` = Destination directory → where backup files will be stored.
- **`-F tar`**: `-F` = Format → store backup as .tar archives instead of normal directories.
- **`-X stream`**: `-X` = Include WAL files → stream WAL along with backup so it’s immediately recoverable.
- **`-P`**: `-P` = Progress display → show backup progress on the screen.

**In short**: This command creates a TAR-format physical backup + WAL stream + progress output into the given directory.

</details>
<br>


Today at 2:00 PM, someone accidentally runs **`DELETE FROM customers`**; and deletes all data.

With continuous archiving + PITR:
- We restore the 10:00 AM base backup. **`pg_restore /var/lib/pgsql/backups/full_10am`**
- PostgreSQL replays all saved WAL files. **`restore_command = 'cp /archived_wal/%f %p'`**
- We tell it to stop replay at 1:59 PM (just before the bad delete). **`recovery_target_time = '2025-01-01 13:59:00'`**


**Result**: Database comes back exactly as it was at 1:59 PM – all data safe, no loss!

**Short meaning**: Continuous archiving saves every change → PITR uses it to "rewind" the database to any second we want.

<details>
<summary><b>Q. What is Base Backup?</b></summary>
<br>

- A base backup is a full copy of the PostgreSQL cluster directory at a specific moment. This is what PITR and replication need to rebuild the database.

```bash
pg_basebackup -D /backups/full_10am -F tar -X stream
```

**What it includes:**
- data directory
- tables + indexes (physical form)
- control files
- config files (optional)
- WAL (if streamed)

In short: *“Take everything PostgreSQL needs to start up again from scratch.”*

</details>

<br>
<details>
<summary><b>Q. WHat is Physical Backup?</b></summary>
<br>

- A physical backup copies the actual database files on disk, not SQL statements.

```bash
# Your physical cluster directory:
/var/lib/pgsql/15/data/
```

If you copy this whole folder → that’s a physical backup.

**What it includes:**
- data files
- WAL segments
- system catalogs
- storage layout exactly as on disk

In short: *“Bit-for-bit raw copy of the real storage, not logical INSERT statements.”*

</details>

<br>
<details>
<summary><b>Q. What is Logical Decoding?</b></summary>
<br>

- Logical decoding is a PostgreSQL feature that reads WAL changes in a human-understandable form (INSERT/UPDATE/DELETE data), allowing streaming changes to external systems like Kafka, replicas, or auditing tools.

</details>
<br>

<details>
<summary><b>restore_command and recover_target_time</b></summary>
<br>

- **`restore_command`**: Tells PostgreSQL how to fetch archived WAL files during recovery (e.g., copy them from an archive folder).

- **`recovery_target_time`**: Defines the exact timestamp where PostgreSQL should stop replaying WAL during PITR.

</details>
<br>


## Scenario Overview

- A database called **sales_data** is running on a PostgreSQL server. Important inserts happen daily. The goal is to: enable continuous WAL archiving, take a base backup, then later restore the database to a specific point in time after accidental data loss.

- Everything below follows this one flow. Nothing theoretical.

---

## Step 1: Check Current WAL Level

PostgreSQL must be using replica or higher. Connect to the database and check:

```bash
SHOW wal_level;
```

If the output is minimal, archiving cannot work. Change it.

<br>
<details>
<summary><b>wal_level</b></summary>
<br>

- We can think of `wal_level` as a setting that controls how much information PostgreSQL writes into the WAL (Write-Ahead Log). More information in WAL means better recovery options, replication support, and features like logical decoding – but it also means slightly more WAL data and disk usage.

- We need to set it in postgresql.conf and restart the server for changes to take effect.

All Possible Values (Short Explanation + When to Use)

- **`minimal`**
  - Writes only the minimum WAL needed for crash recovery.
  - No support for replication, PITR, or logical decoding.
  - **When to use**: Very small systems or embedded setups where we want maximum performance and don't need backups/replication.
Example: **`wal_level = minimal`**

- **`replica`** (most common in production)
  - Adds extra info for physical replication and PITR (continuous archiving).
  - Supports streaming replication, hot standbys, and base backups with pg_basebackup.
  - **When to use:** Almost all production databases – if we need backups, high availability, or replicas.
Example: **`wal_level = replica`**

- **`logical`**
  - Includes everything from replica + extra data needed for logical replication and logical decoding (e.g., pg_recvlogical, change data capture).
  - Slightly more WAL generated.
  - When to use: When we use logical replication slots, publish/subscribe, or tools like Debezium for CDC.
Example: **`wal_level = logical`**

</details>
<br>

Edit postgresql.conf:

```bash
wal_level = replica
```

Restart PostgreSQL for changes to apply:

```bash
sudo systemctl restart postgresql
```

Now WAL contains enough detail for recovery.

---

<br>
<br>

## Step 2: Enable Archiving

Tell PostgreSQL to copy every completed WAL segment to an archive storage location.

Edit postgresql.conf again:

```bash
archive_mode = on
archive_command = 'cp %p /backup/location/%f'
```

Here:

* **`%p`** is WAL file source path
* **`%f`** is WAL filename
* **`/backup/location/`** must already exist

<br>
<details>
<summary><b>archive_mode and archive_command</b></summary>
<br>

- **`archive_mode = on`**: Enables WAL archiving so PostgreSQL starts saving WAL files for recovery/replication.

- **`archive_command = 'cp %p /backup/location/%f'`**: Defines how to store each completed WAL file—here it copies WAL files to /backup/location/.

</details>
<br>

- Restart PostgreSQL again.

- To verify archiving works, insert something into the database, wait a moment, then check if files appear inside /backup/location/.

- When files start appearing, archiving is active.

---

<br>
<br>

## Step 3: Take a Base Backup (Physical Backup)

Now the database can be safely restored to any future point using WAL + this base backup.

Run **`pg_basebackup`**:

```bash
pg_basebackup -D /backup/base -Fp -Xs -P -U postgres
```

<br>
<details>
<summary><b>Breakdown of above command</b></summary>
<br>

- **`pg_basebackup`** Tool to take a physical PostgreSQL base backup.
- **`-D /backup/base`** Destination directory to store the backup.
- **`-Fp`** Format = plain directory (not tar).
- **`-Xs`** Include WAL files using separate files (not streaming mode).
- **`-P`** Show progress while backup runs.
- **`-U postgres`** Use the postgres role to run the backup.

</details>
<br>

- The backup folder now contains the entire physical database copy.

- This is the foundation for restoring later.

---

<br>
<br>

## Step 4: Do Regular Work Normally

Imagine the next day multiple inserts happen:

```bash
INSERT INTO sales VALUES (2001,'Laptop',40000);
INSERT INTO sales VALUES (2002,'Headphones',3500);
INSERT INTO sales VALUES (2003,'Keyboard',1700);
```

- The server also continues archiving WAL files in /backup/location/.

- Everything from this moment forward can later be replayed.

---

<br>
<br>

## Step 5: Simulate a Disaster

A mistake happens. Someone runs:

```bash
DELETE FROM sales;
```

- All rows are gone. A mistake like this happens instantly and commits successfully.

- At this point the database on disk is wrong. WAL archiving and the base backup will fix it.

---

<br>
<br>

## Step 6: Decide Target Recovery Time

Check server logs **`cat /var/lib/pgsql/15/data/log/postgresql-*.log`**, timestamps **`pg_waldump /var/lib/pgsql/15/data/pg_wal`**, or WAL file creation time **`ls -lh /var/lib/pgsql/15/data/pg_wal/`**. Assume the delete happened at:

```bash
2026-01-15 10:30:25
```

We choose to recover to 10:30:24 — one second before disaster.

---

<br>
<br>

## Step 7: Stop PostgreSQL Before Restore

Stop the server cleanly:

```bash
sudo systemctl stop postgresql
```

---

<br>
<br>

## Step 8: Replace Current Data Directory With Base Backup

Remove old corrupted cluster directory:

```bash
sudo rm -rf /var/lib/postgresql/16/main
```

Copy base backup files in its place:

```bash
sudo cp -R /backup/base /var/lib/postgresql/16/main
```

Make sure ownership matches the postgres user.

---

<br>
<br>

## Step 9: Configure Recovery

Inside the restored data directory, create **`recovery.signal`**:

```bash
touch /var/lib/postgresql/16/main/recovery.signal
```

Edit postgresql.conf to provide restore_command:

```bash
restore_command = 'cp /backup/location/%f %p'
```

Set recovery target:

```bash
recovery_target_time = '2026-01-15 10:30:24'
```

Now PostgreSQL knows how far to replay WAL.

---

<br>
<br>

## Step 10: Start PostgreSQL and Let Recovery Run

```bash
sudo systemctl start postgresql
```

- The database starts in recovery mode. It reads WAL files from **`/backup/location/`**, applies them one by one, and stops exactly at the specified second.

- When done, the server automatically leaves recovery mode.

Check the table:

```bash
SELECT * FROM sales;
```

The rows are back. The **`DELETE`** no longer exists.

---

<br>
<br>

## Step 11: Why This Flow Was Successful

- The base backup gave PostgreSQL a known safe state.
- The archived WAL files replayed everything recorded after the backup.
- The timestamp stopped recovery just before the mistake.

Continuous archiving makes PostgreSQL behave like time travel storage. You decide the exact second you want to land on.

---

<br>
<br>

## Step 12: Important Messages From This Scenario

- Archiving must be working before disaster.
- Base backup must match WAL history.
- Timestamp accuracy decides recovery success.
- PostgreSQL must be stopped during restore.
- WAL archive location must contain every file.

With this approach, accidental data loss becomes reversible.

This workflow is what makes PostgreSQL a safe database engine for production environments.
