# view-logs.md

This file explains **exactly how to view, interpret, filter, correlate, and investigate audit logs** on a Linux system using auditd. It focuses on practical usage of `ausearch`, `aureport`, journalctl, raw log parsing, cross-referencing events, and extracting forensic context.

You will learn:
- which logs exist and where they live
- how to extract meaningful events from massive audit logs
- how to interpret multi-line audit events
- how to use ausearch filters precisely
- how to correlate `execve`, `SYSCALL`, file operations, sudo actions, SELinux denials
- how to debug authentication events and privilege escalation attempts

This is the operational guide security engineers use daily.

---

# 1. Where audit logs are stored

The main audit log file is:
```
/var/log/audit/audit.log
```
Older rotated logs:
```
/var/log/audit/audit.log.1
/var/log/audit/audit.log.*.gz
```

If auditd is running properly, **everything auditd captures will be in these files**.

Other related logs:
```
/var/log/secure            # auth, sudo, sshd
/var/log/messages          # general system logs
/var/log/sssd/*.log        # AD/SSSD-related authentication logs
```

Auditd logs contain raw kernel events, whereas `/var/log/secure` contains PAM, SSH, sudo, and SSSD logs.

---

# 2. Viewing logs directly

To view logs live:
```
tail -f /var/log/audit/audit.log
```

To view logs with timestamp and filtering:
```
tail -f /var/log/audit/audit.log | grep execve
```

To view rotated logs:
```
zcat /var/log/audit/audit.log.3.gz | less
```

Use less for easy navigation:
```
less /var/log/audit/audit.log
```

---

# 3. Understanding audit record structure

A complete audit event typically consists of multiple lines with the same event ID:
```
type=SYSCALL msg=audit(1712935023.234:631): arch=c000003e syscall=59 success=yes ... auid=1001 uid=1001 exe="/usr/bin/sudo"
type=EXECVE  msg=audit(1712935023.234:631): argc=2 a0="sudo" a1="cat"
type=CWD     msg=audit(1712935023.234:631): cwd="/home/user"
```

The key is the **event number**: `(1712935023.234:631)`.
- everything with `:631` belongs to the same event
- `SYSCALL` gives system call details
- `EXECVE` shows command and arguments
- `CWD` shows working directory
- optional lines include PATH records (files accessed) and SELinux contexts

Auditd intentionally splits events into multiple messages.

---

# 4. Using ausearch — the primary tool for investigating audit logs

ausarch filters kernel audit logs logically and reconstructs events.

### Find events by key
```
ausearch -k ssh_config
```

### Find events by syscall type
```
ausearch -sc execve
```

### Find events by file accessed
```
ausearch -f /etc/passwd
```

### Find events by executable
```
ausearch -x sudo
ausearch -x /usr/bin/ssh
```

### Find events by user
```
ausearch -ua username
ausearch -ua 1001
```

### Filter by success / failure
```
ausearch --success yes -x sudo
ausearch --success no  -x sudo
```

### Filter by time window
```
ausearch -ts today
ausearch -ts recent
ausearch -ts 09:00 -te 12:00
```

### Combine filters
```
ausearch -ua username -sc execve -ts today
```

---

# 5. Using aureport — summarizing logs fast

`aureport` generates summaries from audit logs.

### Command execution summary
```
aureport -x --summary
```

### File access summary
```
aureport -f --summary
```

### Authentication summary
```
aureport -au
```

### Sudo summary
```
aureport -k | grep sudo
```

### Daily summary
```
aureport -ts today --summary
```

---

# 6. Investigating real scenarios (practical workflows)

## Scenario A — Who modified /etc/passwd?

1. Search by watch key:
```
ausearch -k identity
```
2. Or search by file path:
```
ausearch -f /etc/passwd
```
3. Inspect event details:
```
ausyscall --dump | grep 59  # verify syscall = execve
```

Look for:
- `auid` = original auth user (critical)
- `uid` = effective user
- `exe` = which binary was used
- `PATH` records = old/new inode and file attributes

## Scenario B — Who deleted files today?
```
ausearch -k delete -ts today
```

## Scenario C — Who ran sudo commands?
```
ausearch -k sudo_exec
```

## Scenario D — Detect suspicious root escalations
```
ausearch -k root_exec
```

Then inspect whether `auid` belonged to expected users.

## Scenario E — Investigate tampering with sshd_config
```
ausearch -k ssh_config
```

---

# 7. Inspecting complete events with ausearch -i

`ausearch -i` converts numeric codes (UID, TTY, syscall names) into readable text.

Example:
```
ausearch -i -k exec_log
```

This displays human-readable syscall names and usernames.

---

# 8. Viewing SELinux audit logs (AVC denials)

To list SELinux denials:
```
ausearch -m avc
```

To list only today’s denials:
```
ausearch -m avc -ts today
```

Or via journalctl:
```
journalctl -t setroubleshoot -f
```

SELinux denials are often caused by mislabeled files or incorrect contexts. Audit logs show exact cause.

---

# 9. Correlating multi-line events manually

If event number is `1712935023.234:631`, find all lines:
```
grep 1712935023.234:631 /var/log/audit/audit.log
```

Or with ausearch:
```
ausearch -a 631
```

Use this technique when logs are fragmented.

---

# 10. Viewing logs with journalctl (when audit events forwarded)

Some systems forward auditd logs into journald.

Check audit tag:
```
journalctl -t audit
```

Live follow:
```
journalctl -t audit -f
```

Filter by PID:
```
journalctl _PID=1234 -f
```

---

# 11. Working with very large logs

## Extract only today’s audit log
```
ausearch -ts today > today.log
```

## Compress logs for offline analysis
```
cat /var/log/audit/audit.log | gzip > audit.gz
```

## Parse only specific keys
```
ausearch -k delete > deleted.log
```

## Extract all events for a single user session
Find session ID:
```
ausearch -ua username | grep LOGIN
```
Then extract timeline using timestamp boundaries.

---

# 12. Cross-referencing `/var/log/secure` with audit logs

Example: SSH login failed in `/var/log/secure`.

Check audit:
```
ausearch -m USER_AUTH -ts recent
```

Example: sudo failed.
```
ausearch -m USER_CMD -ts today
```

Combining both logs gives full context.

---

# 13. Troubleshooting when logs appear incomplete

### 1. auditd not running
```
systemctl status auditd
```

### 2. audit backlog overflow
Check kernel messages:
```
dmesg | grep audit
```
Increase backlog in `/etc/audit/auditd.conf`:
```
backlog_limit = 8192
```

### 3. SELinux filtering audit messages
Check:
```
ausyscall --dump
```

### 4. Disk full
```
df -h /var/log
```
Auditd may stop logging if space is low.

---

# 14. Summary cheat sheet

```
# Live view
tail -f /var/log/audit/audit.log

# Investigate specific file
ausearch -f /etc/passwd

# Investigate sudo actions
ausearch -k sudo_exec -i

# Investigate deletions
ausearch -k delete

# Summaries
aureport -x --summary

# SELinux
ausearch -m avc
```

---

# What you achieve after this file

You will be able to confidently navigate audit logs, extract forensic-level details, correlate events across multiple logs, and identify suspicious behavior in a structured, repeatable way. This file gives you the practical muscle memory you need for real security operations and enterprise Linux support.