# auditd.md

This file is your complete, practical guide to **Linux auditd**, the enterprise-grade auditing framework used for tracking system events, security violations, file access, privilege escalation, and policy enforcement. Everything here is written from the perspective of real-world system administration and security operations.

No theory — this is what you will actually configure, monitor, and troubleshoot.

---

- [auditd.md](#auditdmd)
- [1. What auditd is and why it matters](#1-what-auditd-is-and-why-it-matters)
- [2. Installing and enabling auditd](#2-installing-and-enabling-auditd)
- [3. Key auditd components](#3-key-auditd-components)
- [4. Understanding audit record structure](#4-understanding-audit-record-structure)
- [5. Basic auditctl usage (runtime rules)](#5-basic-auditctl-usage-runtime-rules)
- [6. Persistent audit rules](#6-persistent-audit-rules)
- [7. Monitoring command execution (syscall auditing)](#7-monitoring-command-execution-syscall-auditing)
- [8. Auditing destructive actions (delete, rename, chmod)](#8-auditing-destructive-actions-delete-rename-chmod)
- [9. Authentication and sudo auditing](#9-authentication-and-sudo-auditing)
- [10. SELinux audit integration](#10-selinux-audit-integration)
- [11. Searching logs with ausearch](#11-searching-logs-with-ausearch)
- [12. Summaries with aureport](#12-summaries-with-aureport)
- [13. Detecting malicious behavior using audit rules](#13-detecting-malicious-behavior-using-audit-rules)
    - [Detect privilege escalation attempts](#detect-privilege-escalation-attempts)
    - [Detect reading shadow file](#detect-reading-shadow-file)
    - [Detect tampering with sshd config](#detect-tampering-with-sshd-config)
    - [Detect creation of SUID files](#detect-creation-of-suid-files)
    - [Detect unexpected shell spawns (reverse shells / backdoors)](#detect-unexpected-shell-spawns-reverse-shells--backdoors)
- [14. Performance considerations](#14-performance-considerations)
- [15. Hardening auditd itself](#15-hardening-auditd-itself)
- [16. Troubleshooting auditd](#16-troubleshooting-auditd)
    - [auditd won’t start](#auditd-wont-start)
    - [Rules not loading](#rules-not-loading)
    - [ausearch returns nothing](#ausearch-returns-nothing)
    - [High CPU usage](#high-cpu-usage)
- [17. Resetting audit logs](#17-resetting-audit-logs)
- [18. Example full ruleset (enterprise hardened)](#18-example-full-ruleset-enterprise-hardened)


<br>
<br>

# 1. What auditd is and why it matters

auditd is the **Linux Auditing System daemon**. It captures low-level kernel events and records:
- who accessed which file
- who modified configuration files
- who used sudo or attempted privilege escalation
- changes made to user accounts
- system calls (open, execve, delete, chmod, chown)
- SELinux AVC denials
- authentication events (login, logout)
- tampering attempts

auditd is required for:
- forensic investigations
- compliance (PCI DSS, HIPAA, CIS, STIG)
- detecting malicious activity
- monitoring sensitive files

It logs actions **before they happen** (pre-checks) and *as they happen*, so attackers cannot easily bypass it.

---

<br>
<br>

# 2. Installing and enabling auditd

Rocky/RHEL/CentOS usually ship auditd by default.

Check:
```bash
rpm -qa | grep audit
```

Install (if needed):
```bash
dnf install audit audit-libs -y
```

Enable and start:
```bash
systemctl enable --now auditd
systemctl status auditd
```

Important: auditd cannot be fully restarted with systemctl because the audit subsystem is kernel-level. Some changes require `auditctl` or reboot.

---

<br>
<br>

# 3. Key auditd components

- **auditd** — daemon that writes logs
- **auditctl** — runtime audit rule manager (non-persistent)
- **/etc/audit/audit.rules** — legacy rule file
- **/etc/audit/rules.d/*.rules** — preferred location for persistent audit rules
- **ausearch** — search audit logs
- **aureport** — summary reports
- **/var/log/audit/audit.log** — main log file

---

<br>
<br>

# 4. Understanding audit record structure

A single audit event may include multiple lines. Example:
```bash
type=SYSCALL msg=audit(1712859023.123:502): arch=c000003e syscall=59 success=yes uid=1001 auid=1001 exe="/usr/bin/sudo" ...
type=EXECVE msg=audit(1712859023.123:502): argc=3 a0="sudo" a1="cat" a2="/etc/shadow"
```

Interpretation:
- `SYSCALL` — the system call invoked (execve)
- `EXECVE` — arguments passed
- `uid` — user running the command
- `auid` — *original* authenticated user (important for sudo)

`auid` is the forensic identifier — an attacker cannot change it easily.

---

<br>
<br>

# 5. Basic auditctl usage (runtime rules)

Add a temporary rule:
```bash
auditctl -w /etc/passwd -p wa -k passwd_changes
```

Meaning:
- `-w` watch a file
- `-p` permissions to monitor: r (read), w (write), x (execute), a (attribute)
- `-k` key for grouping logs

Remove runtime rule:
```bash
auditctl -W /etc/passwd
```

List current rules:
```bash
auditctl -l
```

Runtime rules disappear after reboot unless added to `/etc/audit/rules.d/*.rules`.

---

<br>
<br>

# 6. Persistent audit rules

Create `/etc/audit/rules.d/hardening.rules`:

```bash
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /var/log/secure -p wa -k secure_log_mod
```

Reload rules:
```bash
auditctl -R /etc/audit/rules.d/
```

Check:
```bash
auditctl -l
```

---

<br>
<br>

# 7. Monitoring command execution (syscall auditing)

Example: audit all executions of `sudo`:
```bash
-w /usr/bin/sudo -p x -k sudo_exec
```

Audit all executions by user 1001:
```bash
-a always,exit -F uid=1001 -F arch=b64 -S execve -k user_commands
```

Audit commands run as root:
```bash
-a always,exit -F euid=0 -S execve -k root_commands
```

Audit sensitive directories:
```bash
-w /etc -p wa -k etc_changes
-w /var/www -p wa -k webroot
```

---

<br>
<br>

# 8. Auditing destructive actions (delete, rename, chmod)

Audit removal of files:
```bash
-a always,exit -S unlink -S unlinkat -S rename -S renameat -k file_delete
```

Audit permission changes:
```bash
-a always,exit -S chmod -S fchmod -S fchmodat -k chmod_changes
```

Audit ownership changes:
```bash
-a always,exit -S chown -S fchown -S fchownat -k chown_changes
```

These tell you exactly **who deleted what**, **when**, and **via which process**.

---

<br>
<br>

# 9. Authentication and sudo auditing

Audit login/logout events are recorded automatically by PAM.

To audit sudo commands:
```bash
-w /var/log/sudo.log -p wa -k sudo_log
```

If using `sudoers` with `log_input` and `log_output`, audit those directories too.

---

<br>
<br>

# 10. SELinux audit integration

SELinux denials automatically appear in audit logs as `AVC` messages:

Search for SELinux denials:
```bash
ausearch -m avc
```

Example output:
```bash
avc:  denied  { read } for pid=2323 comm="httpd" scontext=... tcontext=... tclass=file
```

If your system uses SELinux enforcing mode, auditd becomes essential for debugging AVCs.

---

<br>
<br>

# 11. Searching logs with ausearch

Find events by key:
```bash
ausearch -k passwd_changes
```

Find events for a specific user:
```bash
ausearch -ua 1001
```

Find sudo attempts:
```bash
ausearch -x sudo
```

Find file modifications:
```bash
ausearch -f /etc/ssh/sshd_config
```

Filter by date:
```bash
ausearch -ts today -k passwd_changes
```

---

<br>
<br>

# 12. Summaries with aureport

List login failures:
```bash
aureport -fa
```

List all executed commands:
```bash
aureport -x --summary
```

List file changes:
```bash
aureport -f
```

List users:
```bash
aureport -u
```

Generate full report:
```bash
aureport --summary
```

---

<br>
<br>

# 13. Detecting malicious behavior using audit rules

### Detect privilege escalation attempts
```bash
-a always,exit -F euid=0 -S execve -k root_escalation
```

### Detect reading shadow file
```bash
-w /etc/shadow -p r -k shadow_read
```

### Detect tampering with sshd config
```bash
-w /etc/ssh/sshd_config -p wa -k ssh_config_mod
```

### Detect creation of SUID files
```bash
-a always,exit -F perm=x -F uid!=0 -S chmod -F a2&04000 -k suid_creation
```

### Detect unexpected shell spawns (reverse shells / backdoors)
```bash
-w /bin/bash -p x -k shell_exec
-w /bin/sh  -p x -k shell_exec
```

---

<br>
<br>

# 14. Performance considerations

Auditd can generate huge logs. To avoid performance issues:
- Watch only critical paths
- Use specific syscalls instead of broad matches
- Avoid recursive directory watches on large directories

Monitor log size:
```bash
du -sh /var/log/audit/
```

Configure log rotation in `/etc/audit/auditd.conf`:
```bash
max_log_file = 20
num_logs = 5
```

---

<br>
<br>

# 15. Hardening auditd itself

Modify `/etc/audit/auditd.conf`:

```bash
write_logs = yes
name_format = hostname
space_left_action = email
admin_space_left_action = halt
```

If audit logs fill up, depending on policy, system may:
- halt to prevent tampering
- drop events
- send email warnings

`admin_space_left_action = halt` is required for compliance environments.

---

<br>
<br>

# 16. Troubleshooting auditd

### auditd won’t start
```bash
journalctl -u auditd -xe
```

### Rules not loading
```bash
auditctl -R /etc/audit/rules.d/
auditctl -l
```

### ausearch returns nothing
Check:
```bash
ls -l /var/log/audit/audit.log
```
If empty, auditd may not be running.

### High CPU usage
Check for overly broad syscall rules.

---

<br>
<br>

# 17. Resetting audit logs

Rotate logs manually:
```bash
auditctl -s
service auditd rotate
```

Or delete logs (NOT recommended on production):
```bash
rm -f /var/log/audit/audit.log
systemctl restart auditd
```

---

<br>
<br>

# 18. Example full ruleset (enterprise hardened)

```bash
# monitor identity files
-w /etc/passwd -p wa -k passwd
-w /etc/shadow -p wa -k shadow
-w /etc/group  -p wa -k group

# monitor sudo
-w /etc/sudoers -p wa -k sudoers
-w /var/log/sudo.log -p wa -k sudo_log

# monitor ssh"]
}
```