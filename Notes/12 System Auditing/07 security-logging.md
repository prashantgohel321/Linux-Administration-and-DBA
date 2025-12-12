# security-logging.md

This file is a complete, practical guide on **Linux security logging** — what should be logged, where logs come from, how to ensure logs are complete and trustworthy, how to correlate logs from multiple subsystems (PAM, SSH, sudo, journald, SSSD, auditd, firewall), how attackers try to hide, and how to detect tampering or suspicious behavior.

This is not theory. This is what real administrators and security teams monitor.

---

# 1. The goal of security logging

Security logging must answer four questions in any investigation:
1. **Who** did something? (usernames, UIDs, AUIDs, AD users)
2. **What** exactly they did? (commands, files changed, authentication attempts)
3. **When** it was done? (accurate timestamping, consistent time sync)
4. **From where** it was done? (IP, TTY, service name)

A secure Linux system must log:
- authentication events (success + failure)
- sudo use
- privilege escalation attempts
- file modifications to sensitive files
- command execution (via auditd)
- SSH activity (login, key use, disconnects)
- SSSD/Kerberos login flow for AD users
- SELinux denials
- firewall actions
- system services behavior
- any tampering with logs themselves

---

# 2. Where Linux security logs live

Primary locations:
```
/var/log/secure           # auth, sshd, sudo, PAM
/var/log/messages         # general system messages
/var/log/audit/audit.log  # kernel audit logs
/var/log/sssd/*.log       # SSSD, AD login flow
/var/log/cron             # cron job logs
/var/log/firewalld        # firewall events if enabled
```

Systemd logs:
```
journalctl -u sshd
journalctl -u sssd
journalctl -u sudo
journalctl -u systemd-logind
```

These logs provide overlapping viewpoints. You must correlate across them.

---

# 3. Authentication logging (PAM + SSH + SSSD)

Authentication flows generate logs from multiple layers.

## SSHD logs
Location: `/var/log/secure`
```
sshd[2254]: Failed password for root from 10.0.0.15 port 54321 ssh2
sshd[2254]: Accepted password for prashant from 10.0.0.15
```

What to monitor:
- repeated failures (bruteforce)
- unusual usernames
- logins at odd hours
- logins from unfamiliar IP addresses

## PAM logs
Also in `/var/log/secure`.
```
pam_unix(sshd:auth): authentication failure
pam_sss(sshd:auth): received for user from SSSD
```

PAM logs show **which module** rejected authentication.

## SSSD logs
```
/var/log/sssd/sssd_pam.log
/var/log/sssd/sssd_domain.log
```
These logs explain:
- when AD lookup fails
- when Kerberos ticket fetch fails
- when domain unreachable
- group lookup or ID mapping errors

Example:
```
SSSD Error: krb5_child failed to get TGT for user 'prashant@AD.LOCAL'
```

---

# 4. Sudo logging

Every sudo action must be logged.

In `/var/log/secure`:
```
sudo:   prashant : TTY=pts/0 ; PWD=/home/prashant ; USER=root ; COMMAND=/bin/cat /etc/shadow
```

Monitor:
- sudo use outside maintenance windows
- sudo to unexpected commands
- users running sudo without permission
- excessive failed sudo attempts

Enhance sudo logging with `/etc/sudoers`:
```
Defaults log_input,log_output
Defaults logfile="/var/log/sudo.log"
```

This records keystrokes and output for forensic analysis.

---

# 5. Auditd logging (deep security events)

auditd tracks what users **actually did**, not just whether they authenticated.

Tracks:
- executed commands
- file changes (chmod, chown, delete, rename)
- sudo executions
- privilege escalations
- access to sensitive files

Examples in `/var/log/audit/audit.log`:
```
type=EXECVE msg=audit(1712935032.532:491): a0="sudo" a1="cat" a2="/etc/shadow"
```

Audit logs cannot be easily bypassed and preserve the original authenticated user (AUID).

---

# 6. SELinux security logging

SELinux denials appear as:
```
type=AVC msg=audit(1712935032.532:491): avc: denied { read } for pid=1234 comm="httpd" path="/home/user/test.html"
```

These indicate policy violations. Monitoring AVCs helps detect misconfigured applications **and** attempted unauthorized access.

Check SELinux audit events:
```
ausearch -m avc
```

---

# 7. Firewall logging

Firewalld logs (if enabled):
```
journalctl -u firewalld
```

Or manually log dropped packets via iptables:
```
iptables -A INPUT -j LOG --log-prefix "DROP_INPUT:" --log-level 4
```
Logs go to:
```
/var/log/messages
```

Use this to detect port scanning or unauthorized network actions.

---

# 8. Detecting tampering and suspicious behavior

Attackers frequently try to hide activity. Watch for:

## 1. Log deletion attempts
```
rm /var/log/secure
rm /var/log/audit/audit.log
```
Auditd catches this:
```
type=SYSCALL ... syscall=unlink ...
```

## 2. Timestamp manipulation
If audit logs suddenly have gaps or future timestamps → suspicious.

## 3. Sudden service restarts
Unexpected restarts of:
```
sshd
rsyslog
systemd-journald
```
may indicate tampering.

Check logs:
```
journalctl -u rsyslog -b
journalctl -u systemd-journald -b
```

## 4. Gaps in audit logs
If audit logs stop unexpectedly:
- auditd crashed
- disk full
- attacker rotated logs manually

Check:
```
journalctl -u auditd -f
ausearch -ts today
```

---

# 9. Time synchronization — mandatory for trusted logs

Security logs depend on timestamps. If time differs across systems, correlation breaks.

Enable chronyd:
```
systemctl enable --now chronyd
chronyc sources
chronyc tracking
```

Logs without synchronized time = forensic nightmare.

---

# 10. Remote log forwarding (preventing tampering)

If logs remain only on the local server, attackers with root access can delete or modify them. Centralize logs.

Use rsyslog TLS forwarding:
```
action(type="omfwd" Target="logcollector.local" Protocol="tcp" Port="6514" StreamDriver="gtls" StreamDriverMode="1" StreamDriverAuthMode="x509/name" StreamDriverPermittedPeers="logcollector.local" Template="RSYSLOG_ForwardFormat")
```

Or export journald logs:
```
journalctl --output=export | gzip > journal.export.gz
```

Or use auditd remote plugin (`audisp-remote`) for audit logs.

Remote logs = difficult for attacker to erase evidence.

---

# 11. Correlating logs across subsystems (practical method)

When investigating an incident, correlate:

### Step 1 — Identify SSH login
```
grep "Accepted password" /var/log/secure
```
Note timestamp + username + IP.

### Step 2 — Check sudo usage
```
aus​​earch -k sudo_exec --start <timestamp>
```

### Step 3 — Check executed commands
```
aus​​earch -k exec_log -ua <user>
```

### Step 4 — Check file changes
```
aus​​earch -k delete
ausearch -k chmod_changes
ausearch -k chown_changes
```

### Step 5 — Trace to SSSD if AD user
```
tail -f /var/log/sssd/sssd_pam.log
```

### Step 6 — Combine journal view
```
journalctl --since "timestamp"
```

This gives a full timeline of **who logged in, what they did, which files they touched, and whether they tried to hide**.

---

# 12. Building a minimally viable security logging baseline

At minimum, a secure server must log:
- `/var/log/secure` (SSH, sudo, PAM)
- `/var/log/messages` (system activity)
- `/var/log/audit/audit.log` (mandatory)
- `/var/log/sssd/*.log` (for AD-integrated systems)
- journald (persistent mode)

And forward logs remotely.

A well-designed audit rule set + syslog forwarding gives you the same level of visibility large enterprises rely on.

---

# 13. Quick cheat sheet

```
# View SSH logins
journalctl -u sshd -f

# View sudo activity
grep sudo /var/log/secure

# Audit executed commands
ausearch -sc execve | tail

# Audit file deletions
ausearch -k delete

# View SSSD authentication flow
journalctl -u sssd -f

# View SELinux denials
aus​​earch -m avc

# Follow all logs live
journalctl -f
```

---

# What you achieve after this file

You will understand exactly how Linux produces security logs, where to find them, how to correlate them, how to detect tampering, and how to forward logs securely to prevent attackers from covering their tracks. This enables you to operate Linux systems at a professional security standard.