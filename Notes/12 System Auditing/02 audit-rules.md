# audit-rules.md

This file is a deep, practical guide to designing, writing, validating, and tuning **auditd rules**. You will not only learn the syntax — you will understand how to build hardened, production-ready audit policies that capture exactly what matters: privilege escalation attempts, sensitive file modification, key system calls, user activity, tampering attempts, and high-value security signals.

Everything here is hands-on, command-driven, and battle-tested. No generic CIS copy-pastes — everything is explained in real operational context.

---

<br>
<br>

# 1. Where audit rules live

Audit rules exist in two forms:

1. **Runtime rules** — applied immediately and lost on reboot.
   - Commands managed by: `auditctl`
   - View rules: `auditctl -l`

2. **Persistent rules** — loaded at boot.
   - Location: `/etc/audit/rules.d/*.rules`
   - Compiled into `/etc/audit/audit.rules` at startup
   - After editing: reload with
     ```bash
     auditctl -R /etc/audit/rules.d/
     ```

Always create new rule files like:
```bash
/etc/audit/rules.d/hardening.rules
/etc/audit/rules.d/privileged.rules
/etc/audit/rules.d/filesystem.rules
```

Never modify `/etc/audit/audit.rules` directly.

---

<br>
<br>

# 2. Rule types — watch rules vs syscall rules

There are two rule categories. Use the correct one for the correct use-case.

## Watch Rules (file/folder monitoring)
Watch rules track **access to files or directories**. Example:
```
-w /etc/passwd -p wa -k passwd_watch
```
Use watch rules when:
- you need to monitor config changes
- you want to track edits to specific files
- you care about read/write/attribute changes but not all system calls

## Syscall Rules (low-level syscall auditing)
Syscall rules track **system calls executed by any process**. Example:
```
-a always,exit -F arch=b64 -S execve -k exec_log
```
Use syscall rules when:
- you want to catch process executions
- you want to track file deletion, renaming, permission changes
- you want to detect privilege escalation attempts

Syscall rules are more granular but heavier. Use carefully.

---

<br>
<br>

# 3. Architecture flags — must include both 32-bit and 64-bit on x86_64

On a 64-bit Linux system, processes may run as either 64-bit or 32-bit. Use both:
```
-F arch=b64   # 64-bit
-F arch=b32   # 32-bit
```
If you forget b32, attackers can use 32-bit syscalls to bypass rules.

---

<br>
<br>

# 4. Rule keyword (`-k`) usage

The `-k` tag groups related events for searching:
```
-k passwd_changes
-k ssh_config_mod
-k file_delete
```
Use meaningful names. Avoid uppercase or spaces.

Search later with:
```
ausearch -k passwd_changes
```

---

<br>
<br>

# 5. Practical watch rules (high-value targets)

These rules track modification of sensitive system files.

## Identity files
```
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group  -p wa -k identity
```

## SSH configuration
```
-w /etc/ssh/sshd_config     -p wa -k ssh_config
-w /etc/ssh/ssh_config      -p wa -k ssh_config
```

## Sudoers
```
-w /etc/sudoers        -p wa -k sudo_config
-w /etc/sudoers.d      -p wa -k sudo_config
```

## Important system configs
```
-w /etc/pam.d/          -p wa -k pam_changes
-w /etc/security/       -p wa -k sec_changes
-w /etc/audit/          -p wa -k audit_changes
```

## Kernel parameters
```
-w /etc/sysctl.conf     -p wa -k sysctl_mod
-w /etc/sysctl.d/       -p wa -k sysctl_mod
```

## Services + network changes
```
-w /etc/systemd/system/ -p wa -k service_config
-w /etc/hosts           -p wa -k hostfile
```

---

<br>
<br>

# 6. Practical syscall rules — the most important

## Track **all commands executed**
```
-a always,exit -F arch=b64 -S execve -k exec_log
-a always,exit -F arch=b32 -S execve -k exec_log
```
This logs every command execution system-wide.

## Track file deletion
```
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -k delete
```

## Track chmod
```
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -k chmod_changes
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -k chmod_changes
```

## Track chown
```
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -k chown_changes
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -k chown_changes
```

## Track privilege escalation (exec as root)
```
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_exec
-a always,exit -F arch=b32 -S execve -F euid=0 -k root_exec
```
This catches suspicious root-level execution attempts.

## Track sudo usage
```
-w /usr/bin/sudo -p x -k sudo_exec
-w /var/log/sudo.log -p wa -k sudo_log
```

## Detect SUID/SGID file creation
```
-a always,exit -F arch=b64 -S chmod -F a2&04000 -k suid_create
-a always,exit -F arch=b32 -S chmod -F a2&04000 -k suid_create
```
This alerts when someone sets SUID bit on programs.

---

<br>
<br>

# 7. Filtering rules — reducing noise

Auditd without filters creates huge logs. Add filters to remove junk.

## Ignore trusted users (e.g., system accounts)
```
-F uid>=1000 -F uid!=65534
```

## Track only user sessions
```
-F auid>=1000 -F auid!=4294967295
```
`4294967295` is the `unset` auid used by system services.

## Example: reduced-noise execve rule
```
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=4294967295 -k user_cmds
```

---

<br>
<br>

# 8. Validating rules before applying

Validate syntax:
```
auditctl -R /etc/audit/rules.d/  # runtime load
```

If any rule fails, auditctl prints the offending line.

---

<br>
<br>

# 9. Searching logs effectively

Find by key:
```
ausearch -k ssh_config
```

Find commands executed by a specific user:
```
ausearch -k exec_log -ua username
```

Find deleted files:
```
ausearch -k delete
```

Find events today:
```
ausearch -ts today -k exec_log
```

---

<br>
<br>

# 10. Reporting with aureport

Summaries:
```
aureport -x --summary     # executed commands
aureport -f --summary     # file events
aureport -au              # user auth events
```

---

<br>
<br>

# 11. Example enterprise production rule set (complete)

```
### Identity protection
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group  -p wa -k identity

### Sudo
-w /usr/bin/sudo -p x -k sudo_exec
-w /etc/sudoers -p wa -k sudo_config
-w /etc/sudoers.d -p wa -k sudo_config

### SSH
-w /etc/ssh/sshd_config -p wa -k ssh_config

### PAM
-w /etc/pam.d/ -p wa -k pam_config

### Audit configuration
-w /etc/audit/ -p wa -k audit_config

### Kernel parameters
-w /etc/sysctl.conf  -p wa -k sysctl_mod
-w /etc/sysctl.d/    -p wa -k sysctl_mod

### Exec monitoring
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=4294967295 -k user_cmds
-a always,exit -F arch=b32 -S execve -F auid>=1000 -F auid!=4294967295 -k user_cmds

### Deletion / rename
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -k delete

### Permission changes
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -k chmod_changes
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -k chmod_changes

### Ownership changes
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -k chown_changes
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -k chown_changes

### SUID creation
-a always,exit -F arch=b64 -S chmod -F a2&04000 -k suid_create
-a always,exit -F arch=b32 -S chmod -F a2&04000 -k suid_create
```

---

<br>
<br>

# 12. Performance tuning

If logs grow too quickly:
- tighten filters (`auid>=1000`)
- avoid monitoring huge directories recursively
- reduce syscall rules
- rotate logs aggressively:
```
max_log_file = 20
num_logs = 5
```

---

<br>
<br>

# 13. Troubleshooting

### Rule not loading
```
auditctl -R /etc/audit/rules.d/
```
Check for syntax errors.

### Events not appearing
```
ausearch -ts recent
systemctl status auditd
```

### Too many logs
Apply `auid>=1000` filter or reduce syscall rules.

---

<br>
<br>

# 14. What you achieve after this file

You now know how to write reliable audit rules, understand watch vs syscall logic, use filters to reduce noise, detect real attacks, and build fully hardened audit profiles suitable for enterprise environments. This file gives you a complete mental model of how to track anything happening on your Linux system with precision.