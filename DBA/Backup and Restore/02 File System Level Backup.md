# PostgreSQL File System Level Backup (Practical Explanation)

- [PostgreSQL File System Level Backup (Practical Explanation)](#postgresql-file-system-level-backup-practical-explanation)
  - [What This Backup Method Really Is](#what-this-backup-method-really-is)
  - [A Simple Backup Command](#a-simple-backup-command)
  - [Why the Database Must Be Shut Down First](#why-the-database-must-be-shut-down-first)
  - [Why Individual Table or Database File Copies Do Not Work](#why-individual-table-or-database-file-copies-do-not-work)
  - [Snapshot Based File System Backups](#snapshot-based-file-system-backups)
  - [WAL Must Be Included in Snapshot Backups](#wal-must-be-included-in-snapshot-backups)
  - [Problems When Data Spans Multiple File Systems](#problems-when-data-spans-multiple-file-systems)
  - [Physical Backups Are Usually Larger Than SQL Dumps](#physical-backups-are-usually-larger-than-sql-dumps)
  - [When File System Backups Make Sense](#when-file-system-backups-make-sense)
  - [Core Idea to Remember](#core-idea-to-remember)


<br>
<br>

## What This Backup Method Really Is

- We can think of a file system level backup as <mark><b>copying the exact PostgreSQL data files straight from the disk</b></mark>. Instead of creating SQL commands like `pg_dump` does, this method captures the raw files of the entire data directory.

- When we restore it, PostgreSQL just reads those files directly, and the database comes back to exactly the same state as when we took the backup.

- The data directory holds everything: our tables, indexes, transaction logs, system catalogs, config files, and metadata. So copying this directory means we copy the whole PostgreSQL cluster.

<br>
<br>

## A Simple Backup Command

A basic raw backup looks like a normal file copy:

```bash
tar -cf backup.tar /usr/local/pgsql/data
```

- This command packs the entire PostgreSQL data directory into a tar file. When restored, the tar file is unpacked back into the PostgreSQL data directory location.

- This looks simple, but in real practice it requires strict conditions to avoid corruption.

<br>
<br>

## Why the Database Must Be Shut Down First

- PostgreSQL keeps writing to data files all the time it's running – pages change, WAL logs grow, background processes update files.

- If we copy files while the server is running, we get an inconsistent mix. Some files might show new data while others are still old.

- That's why we must stop PostgreSQL completely before taking a raw file backup:

```bash
pg_ctl stop
```

- Only then can we trust the copy to be safe and consistent.
- Just disconnecting clients isn't enough – internal activity still happens in memory and WAL.

<br>
<br>

## Why Individual Table or Database File Copies Do Not Work

- Every table in PostgreSQL depends on global system files (like pg_xact) that track transaction status for the whole cluster.
- If we copy only one table file, it points to transaction IDs whose status lives in shared system files. Without those, PostgreSQL can't know which rows are visible or committed.
- So we can only restore physical backups by replacing the entire data directory – partial restores won't work logically.

<br>
<br>

## Snapshot Based File System Backups

Some advanced filesystems (like ZFS, LVM) let us take atomic snapshots that freeze everything instantly.
With snapshots, we can back up without shutting down the server:
1. Take the snapshot (freezes the volume)
2. Copy from the snapshot to backup location
3. Release the snapshot

When we restore and start PostgreSQL, it treats it like a crash and automatically replays WAL to recover.
We should run a checkpoint first to make recovery faster:

```bash
CHECKPOINT;
```

<br>
<br>

## WAL Must Be Included in Snapshot Backups

- PostgreSQL needs the WAL files to recover properly from a snapshot. If WAL is missing, the backup can't be used.

<br>
<br>

## Problems When Data Spans Multiple File Systems

- If we use tablespaces on different drives, snapshots become tricky. We need to snapshot all volumes at exactly the same moment.
- If timings differ even slightly, transaction logs and data won't match – backup gets corrupted.

If perfect simultaneous snapshots aren't possible, we should:
1. Stop PostgreSQL and snapshot everything, or
2. Use continuous archiving + base backup instead (safer for online).

<br>
<br>

## Physical Backups Are Usually Larger Than SQL Dumps

- SQL dumps store only the commands to rebuild data (no empty space or index bloat).
- Physical backups copy everything exactly – including indexes, free space, and vacuum leftovers.
- So they take more disk space, but we can create them faster.

<br>
<br>

## When File System Backups Make Sense

We should use this method when:

- Migrating to identical hardware/setup
- We need the exact transaction state
- Speed matters and short downtime is okay

It's not good for upgrading PostgreSQL versions or moving across different systems (file formats may change).

<br>
<br>

## Core Idea to Remember

- File system backups give us a perfect raw copy of how PostgreSQL stores data on disk. We need to handle them carefully – respect the full directory, include WAL, and ensure consistency.
