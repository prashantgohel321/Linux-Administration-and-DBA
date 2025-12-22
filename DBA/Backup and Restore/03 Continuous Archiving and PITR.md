# PostgreSQL Continuous Archiving and Point‑in‑Time Recovery (Explained Practically)

- [PostgreSQL Continuous Archiving and Point‑in‑Time Recovery (Explained Practically)](#postgresql-continuous-archiving-and-pointintime-recovery-explained-practically)
  - [Why Continuous Archiving Exists](#why-continuous-archiving-exists)
  - [Setting Up WAL Archiving](#setting-up-wal-archiving)
  - [Making a Base Backup with Continuous Archiving](#making-a-base-backup-with-continuous-archiving)
  - [Incremental Backups within This System](#incremental-backups-within-this-system)
  - [Low Level Base Backups](#low-level-base-backups)
  - [Restoring Using Continuous Archiving](#restoring-using-continuous-archiving)
  - [Timelines and Why They Matter](#timelines-and-why-they-matter)
  - [Practical Tips](#practical-tips)
  - [Caveats to Consider](#caveats-to-consider)

<br>
<br>

## Why Continuous Archiving Exists

- We can use continuous archiving to turn PostgreSQL's built-in crash recovery into a powerful backup strategy. PostgreSQL writes every single change to WAL (Write-Ahead Log) files in pg_wal. Normally, these help recover after a crash, but with archiving, we store all completed WAL files safely outside the data directory.

- This gives us a chain of changes. When we combine it with one physical base backup, we can restore the database to any exact moment in time – even seconds before a bad query ran. That's why it's called Point-in-Time Recovery (PITR).

## Setting Up WAL Archiving

- WAL is written continuously, but archiving requires PostgreSQL to store completed segment files outside the `pg_wal` directory. To enable this, configuration changes are required in `postgresql.conf`. 
  - Set `wal_level` to `replica` or `higher`, 
  - `archive_mode` to `on`, and supply `a command in archive_command`. 
  - `archive_command` = `'cp %p /path/to/archive/%f'`
- The `archive_command` runs whenever a WAL file segment finishes, allowing PostgreSQL to copy that file to safe storage.

- An example archive command copies each completed WAL file to another filesystem. When a WAL segment ends, the server runs the shell command and expects a zero exit status for success. 
  - When the result is zero, PostgreSQL deletes or recycles the original WAL file. 
  - If the command fails, PostgreSQL retries periodically until the archive succeeds. This guarantees no hole will appear in the archive chain.

- When archiving WAL files, the file name must remain unchanged. PostgreSQL identifies WAL segments by names, so archived copies must preserve those names. Archive destinations must be private, because WAL contains every change the database ever made.

- Once archiving is active, WAL files continue accumulating in storage. As long as the archive does not fall behind, the database can always be restored to any transaction boundary after the most recent base backup.

<br>
<br>

## Making a Base Backup with Continuous Archiving

- A base backup <mark><b>captures the entire data directory at one moment</b></mark>. Once archiving is working, **`pg_basebackup`** can be used to capture the physical cluster. This backup does not require the server to stop running. PostgreSQL places the cluster into backup mode internally, ensuring files copied during <mark><b>pg_basebackup</b></mark> are safe to restore.

```bash
pg_basebackup -D /backup/base -Ft -z -P --wal-method=stream

# This copies the entire cluster while the server runs. PostgreSQL ensures consistency internally.
```

After the base backup completes, WAL files recorded during the backup must also be kept. WAL files needed for the backup are identified automatically. PostgreSQL writes a history file to the archive that marks the start and stop points for that backup. This history file tells recovery which WAL files are necessary.

When restoring, the base backup places the cluster back on disk exactly as it was. Replay then begins reading archived WAL files, moving the restored cluster forward.

The interval between base backups depends on how much WAL storage you are willing to keep. WAL replay time grows as WAL accumulates. Large databases may keep long WAL histories to reduce the frequency of full base backups.

## Incremental Backups within This System

Incremental backups extract only the changed blocks since an earlier backup. They rely on WAL summaries and require matching earlier backups. When restoring an incremental backup chain, all earlier backups must be present. WAL replay rules do not change; archived WAL is still required to move the database to the recovery endpoint.

This approach suits large databases where most data remains untouched. Small or highly volatile databases usually prefer full backups instead.

## Low Level Base Backups

Instead of pg_basebackup, the low level backup API can be used. A backend session starts backup mode by running pg_backup_start with a label. While the session remains open, file system tools copy the entire data directory. After copying finishes, pg_backup_stop completes backup mode and records required WAL boundaries. The backup label and tablespace map must be saved byte‑for‑byte inside the backup root.

This method works without stopping the server. Each required WAL segment must be archived; otherwise the backup will not restore correctly.

Low level backups demand careful ordering: start backup mode, copy data, stop backup mode. Breaking order invalidates the result. This approach allows parallel backups and advanced scripting control.

## Restoring Using Continuous Archiving

Restoration begins by placing the base backup directory back into a PostgreSQL data location. Existing data directories must be cleared first, because file content must match exactly. WAL files written after the base backup must then be restored into pg_wal or fetched from the archive during recovery.

Recovery is controlled by configuration. PostgreSQL needs a restore_command that fetches WAL files from the archive. When the server starts with recovery.signal present, recovery mode begins. PostgreSQL reads archived WAL files in sequence. Missing WAL triggers additional archive requests. This continues until the archive runs out or until the configured target point is met.

Point‑in‑time recovery becomes possible by specifying a recovery target. A timestamp or named restore point instructs PostgreSQL to stop replay at a chosen moment. All data written after that target is ignored, producing a database state as it existed at that specific moment.

If WAL corruption appears during replay, recovery stops. If WAL cannot be fetched, replay pauses until files become available. Restarting the server continues recovery from the last safe record.

After recovery completes, PostgreSQL removes recovery.signal and switches to normal operation.

## Timelines and Why They Matter

When recovery completes, PostgreSQL begins a new WAL timeline. A timeline allows the cluster to remember branching points. For example, if the database is restored back to Monday and brought online, future WAL records diverge from original Tuesday history. The new WAL receives a new timeline ID, preserving the older history.

Timeline files track ancestry. These files allow PostgreSQL to replay WAL across complex histories without overwriting earlier WAL data. This makes repeated testing of recovery targets possible. Administrators can restore to multiple different moments without losing earlier histories.

## Practical Tips

Continuous archiving allows warm standby servers. By streaming archived WAL to a secondary machine that shares the same base backup, standby servers remain nearly current and ready for promotion.

Archive storage grows large over time. Compressed WAL reduces space usage, and pg_basebackup options allow WAL to be included automatically inside backup packages.

Scripts help manage archive_command complexity. Archiving pipelines can push WAL to remote storage, cold storage, or backup rotation systems.

## Caveats to Consider

Continuous archiving backs up entire clusters. Partial restores are not supported. WAL depends on full cluster consistency. New tablespaces create permanent path references inside WAL and must be handled carefully. Archived WAL volume depends heavily on workload and checkpoint settings.

Configuration files are not archived through WAL and must be backed up through normal file copies. WAL replay restores data operations, not server configuration edits.

This method requires planning, testing, and discipline. When executed correctly, it provides reliable long‑term recovery, precise point‑in‑time restores, and robust standby replication options.
