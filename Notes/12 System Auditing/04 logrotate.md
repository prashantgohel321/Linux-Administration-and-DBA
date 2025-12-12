# logrotate.md

This file is a complete, practical guide to configuring, tuning, testing, and troubleshooting **logrotate** on Linux. logrotate controls log file rotation, compression, retention, and cleanup. You will use it heavily for managing `/var/log/*`, audit logs, application logs, and custom service logs.

The goal is simple: prevent logs from filling disks while keeping enough history for audits and investigations.

No fluff — this is real-world usage.

---

# 1. What logrotate does

logrotate automatically rotates log files based on size, time, or both. A rotation means:
- renaming the current log file (e.g., `app.log` → `app.log.1`)
- compressing older logs (`app.log.1.gz`, `app.log.2.gz`)
- deleting logs older than retention policy
- optionally running post-rotation commands (like `systemctl reload service`)

It runs daily via cron or systemd timer:
```
/etc/cron.daily/logrotate
```
OR
```
systemctl list-timers | grep logrotate
```

---

# 2. Where logrotate configuration lives

Global config:
```
/etc/logrotate.conf
```
Default include directory:
```
/etc/logrotate.d/
```
Each file under logrotate.d controls rotation for a specific service.

Example:
```
/etc/logrotate.d/sshd
/etc/logrotate.d/audit
/etc/logrotate.d/httpd
```

Your custom apps should get their own file in `/etc/logrotate.d/`.

---

# 3. Understanding basic logrotate syntax

A typical block:
```
/var/log/secure {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0600 root root
}
```
Meaning:
- `weekly` — rotate once per week
- `rotate 4` — keep 4 old logs
- `compress` — gzip old files
- `missingok` — skip quietly if file missing
- `notifempty` — do not rotate if empty
- `create` — create new log after rotation with permissions

---

# 4. Key directives (practical explanations)

### `daily`, `weekly`, `monthly` — rotation schedule
Self-explanatory. Use `size` rules if log grows too fast.

### `size <value>` — rotate when file exceeds size
Example:
```
size 100M
```
Rotate when log >100 MB.

### `rotate N` — how many archived logs to keep
Example:
```
rotate 10
```
Keeps 10 compressed logs.

### `compress` / `nocompress`
Compresses rotated logs using gzip.

### `delaycompress`
Useful for services that hold the file open. First rotation is uncompressed; next cycle compresses it.

### `copytruncate`
Truncates log file **in place** instead of renaming it.

Use copytruncate **only if the application cannot handle file renaming** (common for some apps).

### `create mode owner group`
After rotation, create a new log with permissions. Required for secure services:
```
create 0600 root root
```

### `postrotate ... endscript`
Run commands after rotation.

Example (reload rsyslog to reopen file descriptors):
```
postrotate
    systemctl reload rsyslog > /dev/null 2>&1 || true
endscript
```

---

# 5. How logrotate works internally

1. Checks the timestamp or size of logs.
2. Rotates based on config.
3. Compresses older logs.
4. Runs pre/post scripts.
5. Updates state file: `/var/lib/logrotate/logrotate.status`.

Checking state file is essential for debugging why logs didn't rotate.

---

# 6. Real-world logrotate examples

## Example A — Rotate SSH logs (`/var/log/secure`)
```
/var/log/secure {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0600 root root
}
```

## Example B — Rotate audit logs (`/var/log/audit/audit.log`)
Auditd uses its own rotation command but logrotate can still manage older files.

A typical `/etc/logrotate.d/audit`:
```
/var/log/audit/audit.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    postrotate
        /sbin/service auditd reload > /dev/null 2>&1 || true
    endscript
}
```

## Example C — Rotate application logs with size threshold
```
/var/log/myapp/app.log {
    size 200M
    rotate 10
    compress
    missingok
    notifempty
    copytruncate
}
```
Use `copytruncate` if app does not reopen logs automatically.

---

# 7. Testing logrotate manually (critical skill)

To test rotation without modifying logs:
```
logrotate -d /etc/logrotate.conf
```
`-d` = debug (no actual rotation)

To force rotate immediately:
```
logrotate -f /etc/logrotate.conf
```
Or force one specific config:
```
logrotate -f /etc/logrotate.d/myapp
```

Check state file:
```
cat /var/lib/logrotate/logrotate.status
```

---

# 8. Troubleshooting logrotate

### Issue: Log not rotating
Check:
```
logrotate -d /etc/logrotate.conf
```
Possible reasons:
- log is empty (notifempty)
- file missing (missingok not specified)
- rotation interval not reached
- size < threshold
- wrong path or permissions
- application holds file open (use copytruncate or restart service)

### Issue: Logs rotate but not compress
Check for `delaycompress`. It delays compression for one cycle.

### Issue: Service not reopening log after rotation
Add postrotate script:
```
postrotate
    systemctl reload <service>
endscript
```

### Issue: Disk still filling even after rotate
Ensure old logs are actually deleted:
```
rotate 4
```
Not sufficient if logs grow too large within one cycle; use `size`.

---

# 9. Creating logrotate configs for custom applications

Suppose your app writes to `/opt/app/app.log`.

Create `/etc/logrotate.d/myapp`:
```
/opt/app/app.log {
    daily
    rotate 14
    size 50M
    compress
    copytruncate
    missingok
    notifempty
}
```

Test:
```
logrotate -d /etc/logrotate.d/myapp
```
Then:
```
logrotate -f /etc/logrotate.d/myapp
```

---

# 10. Security considerations when using logrotate

- Use secure file permissions with `create 0600 root root` for sensitive logs.
- Ensure rotated logs are accessible only to authorized users.
- Use compression to reduce footprint and avoid filling disk.
- Protect `/var/log/audit` aggressively — no unauthorized user should read it.
- If logs contain credentials or secrets, ensure they are not world-readable.

---

# 11. Integration with systemd

On modern systems, systemd timers may handle logrotate:
```
systemctl status logrotate.timer
```

Manual trigger:
```
systemctl start logrotate.service
```

Verify last run:
```
systemctl list-timers --all | grep logrotate
```

---

# 12. Cheat sheet

```
# test rotation without doing it
logrotate -d /etc/logrotate.conf

# force rotation
logrotate -f /etc/logrotate.conf

# check status file
cat /var/lib/logrotate/logrotate.status

# list configs
ls /etc/logrotate.d/
```

---

# What you achieve after this file

You now know how to:
- design reliable log rotation for any service
- prevent disk flooding
- integrate rotation with daemons like rsyslog and auditd
- debug and test logrotate configurations safely
- write secure rotation policies for enterprise environments

This is everything you need to master logrotate in production.
