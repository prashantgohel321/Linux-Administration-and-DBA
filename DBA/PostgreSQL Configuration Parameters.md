# PostgreSQL Configuration Parameters (Simplified Guide)

This markdown explains the important configuration settings inside `postgresql.conf`, excluding Authentication, SSL, Query Tuning, and anything after Version/Platform compatibility.

---

- [PostgreSQL Configuration Parameters (Simplified Guide)](#postgresql-configuration-parameters-simplified-guide)
  - [1. File Locations](#1-file-locations)
  - [2. Connection Settings (Non‑Authentication)](#2-connection-settings-nonauthentication)
  - [3. Resource Usage – Memory](#3-resource-usage--memory)
  - [4. Resource Usage – Disk \& Files](#4-resource-usage--disk--files)
  - [5. Cost-Based Vacuum Delay](#5-cost-based-vacuum-delay)
  - [6. Background Writer Settings](#6-background-writer-settings)
  - [7. Parallelism](#7-parallelism)
  - [8. Write-Ahead Log (WAL)](#8-write-ahead-log-wal)
  - [9. Checkpoint Settings](#9-checkpoint-settings)
  - [10. WAL Archiving / PITR](#10-wal-archiving--pitr)
  - [11. Basic Replication Settings](#11-basic-replication-settings)
  - [12. Logging \& Reporting](#12-logging--reporting)
  - [13. Process Title](#13-process-title)
  - [14. Statistics System](#14-statistics-system)
  - [15. Autovacuum Settings](#15-autovacuum-settings)
  - [16. Client Defaults](#16-client-defaults)
  - [17. Locale \& Formatting](#17-locale--formatting)
  - [18. Lock Management](#18-lock-management)


## 1. File Locations

**data_directory** – Where PostgreSQL stores data files.

**hba_file** – Path to pg_hba.conf authentication config.

**ident_file** – Path to pg_ident.conf for user mapping.

**external_pid_file** – Optional PID file for service managers.

---

## 2. Connection Settings (Non‑Authentication)

**listen_addresses** – IP addresses PostgreSQL should accept connections on.

**port** – TCP port number for connections (default: 5432).

**max_connections** – Maximum simultaneous client connections.

**superuser_reserved_connections** – Reserved slots for superuser access.

**unix_socket_directories** – Paths for UNIX socket creation.

**unix_socket_permissions** – Permissions mask for socket file.

---

## 3. Resource Usage – Memory

**shared_buffers** – Main shared memory cache for table/index blocks.

**work_mem** – Per-operation RAM for sorting, hashing, joins.

**maintenance_work_mem** – Memory for VACUUM/CREATE INDEX.

**temp_buffers** – Per-session memory for temporary tables.

**autovacuum_work_mem** – Memory limit for autovacuum workers.

**logical_decoding_work_mem** – Memory for logical decoding.

**max_stack_depth** – Allowed backend stack size.

---

## 4. Resource Usage – Disk & Files

**temp_file_limit** – Limit for per-process temporary files.

**max_files_per_process** – OS file descriptor usage limit.

---

## 5. Cost-Based Vacuum Delay

**vacuum_cost_delay** – Throttle delay between vacuum operations.

**vacuum_cost_limit** – Work limit trigger for vacuum delay.

---

## 6. Background Writer Settings

**bgwriter_delay** – Sleep time between flush rounds.

**bgwriter_lru_maxpages** – Max pages flushed per cycle.

**bgwriter_lru_multiplier** – Aggressiveness of buffer scanning.

---

## 7. Parallelism

**max_worker_processes** – Total background workers allowed.

**max_parallel_workers** – Parallel workers across system.

**max_parallel_workers_per_gather** – Workers per query gather.

---

## 8. Write-Ahead Log (WAL)

**wal_level** – WAL detail stored (minimal/replica/logical).

**fsync** – Synchronize to disk for durability.

**synchronous_commit** – Commit wait control for safety vs speed.

**wal_sync_method** – Method for syncing WAL to disk.

**full_page_writes** – Protect against torn writes.

**wal_compression** – Compress full-page writes.

**wal_buffers** – Shared WAL buffer size.

**wal_writer_delay** – WAL writer frequency.

**wal_writer_flush_after** – WAL write size threshold.

---

## 9. Checkpoint Settings

**checkpoint_timeout** – Time between automatic checkpoints.

**checkpoint_completion_target** – Spread checkpoint duration.

**max_wal_size** – Upper WAL size boundary.

**min_wal_size** – Lower boundary for WAL reuse.

---

## 10. WAL Archiving / PITR

**archive_mode** – Enables WAL archiving.

**archive_command** – Command to archive WAL segments.

---

## 11. Basic Replication Settings

**max_wal_senders** – Max WAL sender processes.

**max_replication_slots** – Max replication slots.

**wal_keep_size** – Keep WAL segments for replicas.

---

## 12. Logging & Reporting

**log_destination** – Logging output type.

**logging_collector** – Enable/disable log collector.

**log_directory** – Directory to store logs.

**log_filename** – Log file naming format.

**log_rotation_age** – Rotate after interval.

**log_rotation_size** – Rotate after size.

**log_line_prefix** – Customize log header.

**log_timezone** – Timestamp timezone.

---

## 13. Process Title

**cluster_name** – Cluster label for process list.

**update_process_title** – Refresh running process names.

---

## 14. Statistics System

**track_activities** – Track running queries.

**track_counts** – Track table/index stats.

**track_functions** – Track function usage.

**stats_fetch_consistency** – Snapshot/cached stats choice.

---

## 15. Autovacuum Settings

**autovacuum** – Enables table cleanup automation.

**autovacuum_max_workers** – Max autovacuum workers.

**autovacuum_naptime** – Sleep period between checks.

**autovacuum_vacuum_threshold** – Rows updated before vacuum.

**autovacuum_analyze_threshold** – Rows changed before analyze.

**autovacuum_freeze_max_age** – Age limit for xid freeze.

---

## 16. Client Defaults

**default_transaction_isolation** – Default isolation level.

**statement_timeout** – Per-query execution timeout.

**lock_timeout** – Lock wait timeout.

**idle_session_timeout** – Terminate idle sessions.

---

## 17. Locale & Formatting

**datestyle** – Date output formatting.

**timezone** – Default timezone.

**client_encoding** – Client-side encoding.

**default_text_search_config** – Full-text search dictionary.

---

## 18. Lock Management

**deadlock_timeout** – Delay before deadlock checks.

**max_locks_per_transaction** – Max lock entries.

**max_pred_locks_per_transaction** – Predicate locks.

---
