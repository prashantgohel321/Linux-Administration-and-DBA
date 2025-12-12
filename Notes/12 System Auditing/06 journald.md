# journald.md

This file is a practical, command-focused guide to **systemd-journald** — how it collects logs, how to configure persistence and retention, how to query and export logs, and how to integrate journald with rsyslog or a centralized log pipeline. Everything here is written for Rocky Linux / RHEL-style systems but applies to other modern distros with minor path differences.

You will learn exact files to edit, commands to run, and debugging steps. No fluff.

---

# 1. What journald is and why it matters

`systemd-journald` is the systemd logging daemon. It collects logs from the kernel, init system, services (stdout/stderr), and syslog. Journald stores logs in a binary format that preserves metadata (PRI, _UID, _PID, _COMM, SYSLOG_IDENTIFIER, SELINUX context, etc.), which makes queries precise and fast.

Key advantages:
- structured metadata for each log entry
- fast indexed queries with `journalctl`
- consistent capture of stdout/stderr of systemd services
- optional persistent storage on disk

---

# 2. Storage modes and enabling persistent logging

By default some distros store journals transiently under `/run/log/journal` (volatile). To make journals persistent across reboots, create `/var/log/journal`.

Commands to enable persistent journal:
```
mkdir -p /var/log/journal
chown root:systemd-journal /var/log/journal
chmod 2755 /var/log/journal
systemctl restart systemd-journald
```

Confirm persistence:
```
journalctl --list-boots
```
If you see multiple boot IDs, persistent storage works.

---

# 3. Main configuration file and key settings

`/etc/systemd/journald.conf` is the main config. You should not edit `journald.conf.d` unless you need drop-ins.

Important options and recommended settings:
```
# /etc/systemd/journald.conf
Storage=persistent          # store logs in /var/log/journal
SystemMaxUse=500M          # maximum disk space for all journal files
SystemKeepFree=200M        # keep at least this free space on filesystem
SystemMaxFileSize=50M      # max size per journal file
MaxRetentionSec=1month     # rotate out older logs after this time
RuntimeMaxUse=200M         # if using volatile only
ForwardToSyslog=yes        # forward entries to rsyslog if present
Compress=yes               # compress journal files
Seal=yes                   # seal journal files for tamper detection (requires systemd-journal-remote tools)
```

After editing, reload journald:
```
systemctl reload systemd-journald
```

Note: `Seal=yes` can add CPU overhead and requires corresponding support for verification. Use only if you require tamper-evidence.

---

# 4. Querying logs with journalctl (practical commands)

`journalctl` is the main tool to read and query the journal. Useful examples:

```
# follow live logs
journalctl -f

# last 200 lines
journalctl -n 200

# logs for a unit
journalctl -u sshd

# logs for a unit since boot
journalctl -b -u sshd

# logs for a specific boot (use boots list)
journalctl -b -1   # previous boot
journalctl --list-boots

# filter by time
journalctl --since "2025-12-10 09:00" --until "2025-12-10 12:00"

# filter by priority (err, warning, info)
journalctl -p err..alert

# filter by PID
journalctl _PID=1234

# filter by systemd field: syslog identifier
journalctl SYSLOG_IDENTIFIER=sshd

# show structured fields with verbose output
journalctl -o verbose -u sshd

# binary export to file to transfer elsewhere
journalctl --output=export > /tmp/journal.export
# import elsewhere with journalctl --import
```

For scripting, use `-o json` or `-o json-pretty` to parse fields.

---

# 5. Forwarding journald to rsyslog or external systems

If you want text logs persisted or forwarded centrally, configure `ForwardToSyslog=yes` in `journald.conf` and let rsyslog pick them up via `imjournal` or `imuxsock`.

Alternatively use `systemd-journal-remote` to collect journals over the network (useful for central journal collection).

Example: enable forwarding to syslog and verify rsyslog receives entries:
```
# in /etc/systemd/journald.conf
ForwardToSyslog=yes

# restart services
systemctl restart systemd-journald
systemctl restart rsyslog

# test
logger "test message from journald forwarding"
journalctl -f &
# check /var/log/messages or /var/log/secure depending on facility
```

If `imjournal` produces duplicate logs (both imjournal and imuxsock enabled), choose only one input on rsyslog.

---

# 6. Managing disk space and retention

Use `SystemMaxUse`, `SystemKeepFree`, and `SystemMaxFileSize` to limit journal disk consumption. Example:
```
SystemMaxUse=1G
SystemKeepFree=500M
SystemMaxFileSize=100M
```

To vacuum old logs manually:
```
# remove files until total size under 500M
journalctl --vacuum-size=500M

# remove entries older than X days
journalctl --vacuum-time=30d

# remove files until number of files below N
journalctl --vacuum-files=5
```

Check current usage:
```
journalctl --disk-usage
```

---

# 7. Security: protecting and sealing journal files

Journal files are readable by the `systemd-journal` group. Be careful with group membership.

List permissions:
```
ls -ld /var/log/journal /var/log/journal/*
```

To restrict access, avoid adding users to `systemd-journal`. For strong tamper-evidence use `Seal=yes` in `journald.conf`. Signed/sealed journals allow later verification that files were not changed.

---

# 8. Troubleshooting common journald issues

### 1. Journald not persisting logs
- Confirm `/var/log/journal` exists and has correct owner and mode. Run the `mkdir`/`chown`/`chmod` commands above. Restart journald.

### 2. Journald consuming too much disk
- Check `journalctl --disk-usage`.
- Vacuum old logs: `journalctl --vacuum-size=XXX`.
- Set `SystemMaxUse` and `SystemKeepFree` in `journald.conf`.

### 3. Duplicate logs in rsyslog
- Avoid both `imjournal` and `imuxsock` simultaneously. Prefer `imjournal` on modern systems.

### 4. `journalctl` slow or high CPU
- Large journal files cause high I/O. Vacuum or limit journal size.
- Use `--since`/`--until` to narrow queries. Use binary `--output=export` for transfers.

### 5. Unable to forward journals to rsyslog
- Confirm `ForwardToSyslog=yes`. Check `journalctl -f` and `journalctl -u rsyslog -f` for errors.

---

# 9. Using structured output for parsing and SIEM ingestion

`journalctl -o json` or `-o json-pretty` is useful when sending logs to ELK or other parsers. Example:
```
journalctl -u myapp -o json | jq '.'
```
Fields of interest include `_PID`, `_UID`, `_COMM`, `SYSLOG_IDENTIFIER`, `_SYSTEMD_UNIT`, `MESSAGE`, `PRIORITY`.

Use `systemd-journal-remote` and `systemd-journal-gatewayd` to expose journal entries over HTTP/HTTPS to collectors.

---

# 10. Rotation, vacuuming, and integration with logrotate

Do not use logrotate on journal files. Use `journalctl --vacuum-*` or `journald.conf` settings. Logrotate should be used for text logs written by rsyslog or applications.

---

# 11. Advanced: central journald collection

For central collection of journal entries across hosts, use `systemd-journal-remote`:
- Run `systemd-journal-remote` on a collector to receive `/` exports over HTTPS
- Use `journalctl --merge` on the collector after importing

Steps (brief):
```
# on collector
dnf install systemd-journal-remote
systemctl enable --now systemd-journal-remote
# configure client to send exported journals to collector (use HTTPS and authentication)
```
This method preserves structured journal fields better than text syslog forwarding.

---

# 12. Quick commands cheat sheet

```
# show last 200 log lines
journalctl -n 200

# follow logs
journalctl -f

# view unit logs
journalctl -u sshd -f

# check disk usage
journalctl --disk-usage

# vacuum logs by size
journalctl --vacuum-size=500M

# show boots
journalctl --list-boots

# export journal to file
journalctl --output=export > /tmp/journal.export

# import exported journal
journalctl --import /tmp/journal.export
```

---

# What you achieve after this file

You will be able to configure persistent journaling, control retention and disk usage, query logs precisely with `journalctl`, forward logs to rsyslog or collect centrally with `systemd-journal-remote`, and troubleshoot the common issues caused by large journals or misconfiguration. This guide gives you the exact commands and safe procedures to manage journald in both lab and production environments.
