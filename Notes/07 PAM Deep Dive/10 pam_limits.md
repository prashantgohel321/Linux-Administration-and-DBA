# pam_limits.md

This file is a complete, practical deep dive into **pam_limits.so**, the PAM module responsible for applying resource limits (ulimits) defined in:
```bash
/etc/security/limits.conf
/etc/security/limits.d/*.conf
```

`pam_limits.so` looks simple, but in real environments it controls:
- per-user CPU usage
- RAM limits
- max processes (to prevent fork-bombs)
- open file limits (important for servers)
- priority and scheduling
- core dump permissions

This module becomes critical on multi-user servers, AD-integrated systems, and any Linux environment concerned with stability + security.

This file explains:
- how pam_limits works
- where configuration lives
- how limits apply to AD users
- how to test limits
- common misconfigurations
- advanced examples

---

<br>
<br>

# What pam_limits.so actually does

During the **SESSION** phase, PAM loads pam_limits.so. This module reads limit configuration files and applies restrictions to the user’s session.

If pam_limits.so is missing from session phase:
- ulimit values stay at OS defaults
- per-user resource controls do not work
- AD users may bypass system limits unintentionally

Correct placement in PAM files:
```bash
session    required    pam_limits.so
```

This line must appear in both:
- `/etc/pam.d/system-auth`
- `/etc/pam.d/password-auth`
- (or in `/etc/pam.d/sshd` via include)

---

<br>
<br>

# Where pam_limits reads configuration from

1. Main config:
```bash
/etc/security/limits.conf
```
2. Additional config snippets:
```bash
/etc/security/limits.d/*.conf
```
These override or extend limits.conf.

---

<br>
<br>

# Syntax of limits.conf (practical explanation)

Each rule has four fields:
```bash
<domain> <type> <item> <value>
```

### domain
Defines who this rule applies to.
Examples:
```bash
*            → all users
root         → only root
username     → a specific user
@admins      → local Linux group
@domain\\group → AD group via SSSD
```

### type
Can be:
```bash
hard → cannot be exceeded even temporarily
soft → can be increased by user up to hard limit
```

### item
Common items:
```bash
nofile   → max open files
nproc    → max processes
fsize    → max file size
cpu      → CPU time limit
stack    → max stack size
as       → virtual memory
memlock  → locked memory
rtprio   → real-time priority
core     → core dumps
```

### value
The numeric limit.

---

<br>
<br>

# Real-world examples with explanation

## 1. Increase open files for all users
```bash
* soft nofile 10240
* hard nofile 65535
```
Use case: servers running applications needing many file descriptors.

Check:
```bash
ulimit -n
```

---

<br>
<br>

## 2. Limit max processes for non-admin users
Prevent fork-bombs.
```bash
*     soft nproc 2000
*     hard nproc 2500
@admins hard nproc unlimited
```

Test:
```bash
ulimit -u
```

---

<br>
<br>

## 3. Restrict AD users using AD group mapping
```bash
@domain\\Developers   hard nofile 32768
@domain\\Developers   soft nofile 16384
```

Check group membership:
```bash
id 'DOMAIN\\username'
```

---

<br>
<br>

## 4. Disable core dumps for all users (security)
```
* hard core 0
```

---

<br>
<br>

## 5. Give system services higher priority
```bash
@system  -  rtprio  99
```

Note: requires kernel support.

---

<br>
<br>

## 6. Memory locking (DB servers)
```bash
oracle  hard memlock unlimited
```

---

<br>
<br>

# How limits apply to AD users (important)

pam_limits integrates seamlessly with SSSD-provided identities. That means:

- AD users can receive limits
- AD groups can be referenced using `@DOMAIN\\GroupName`
- group membership comes from SSSD’s NSS interface

Example:
```bash
@GOHEL\\LinuxUsers soft nofile 20480
```

To test if user is in group:
```bash
id username@gohel.local
```

If group membership does not appear → SSSD misconfiguration.

---

<br>
<br>

# Verifying limits are applied

Limits only apply **after login**, inside a session.

Check using:
```bash
ulimit -a
```
Example output includes:
```bash
open files                      (-n) 10240
max user processes              (-u) 2000
core file size                  (blocks) 0
```

Also check system environment:
```bash
cat /proc/$(pidof bash)/limits
```
Shows detailed per-process limits.

---

<br>
<br>

# Common problems and how to fix them

## Problem 1: Limits not applying to SSH logins
Cause:
- pam_limits.so missing in PASSWORD-AUTH session block

Fix:
Ensure:
```bash
session required pam_limits.so
```
appears in **system-auth** AND **password-auth**.

---

<br>
<br>

## Problem 2: Limits apply to console login but not SSH
Cause:
- SSH is not using PAM

Fix in `/etc/ssh/sshd_config`:
```bash
UsePAM yes
```
Restart SSH:
```bash
systemctl restart sshd
```

---

<br>
<br>

## Problem 3: AD group rules ignored
Cause:
- SSSD not providing group lists

Fix:
```bash
id username
sssctl user-show username
```
Make sure AD groups appear.

---

<br>
<br>

## Problem 4: A limit not taking effect despite config
Possible reasons:
- wrong domain syntax
- overriding entry in /etc/security/limits.d/
- shell not using PAM session (rare)

Debug:
```bash
grep -R nofile /etc/security
```
Which file is overriding your settings?

---

<br>
<br>

# Advanced configuration examples

## 1. Separate rules for service users
```bash
nginx   soft nofile  200000
nginx   hard nofile  400000
```

<br>
<br>

## 2. Special rules for AD administrative groups
```bash
@DOMAIN\\LinuxAdmins hard nproc unlimited
@DOMAIN\\LinuxAdmins soft nproc unlimited
```

<br>
<br>

## 3. Restrict CPU time for development users
```bash
@DOMAIN\\DevUsers hard cpu 3600
```
Limits them to 1 hour CPU time per process.

---

<br>
<br>

# How to safely test changes

1. Keep a root session open.
2. Modify limits.conf or limits.d/*.conf.
3. Open a new SSH session as the target user.
4. Check:
```bash
ulimit -a
```
5. Confirm limits are applied.

If limits break SSH login, revert immediately.

---

<br>
<br>

# Recovery procedure

If limits break authentication (rare but possible):
1. Login via console/VM console.
2. Comment out your new rule.
3. Restart sshd.

---

<br>
<br>

# What you achieve after this file

You now fully understand:
- how pam_limits works
- how to apply resource restrictions correctly
- how limits interact with AD users and groups
- how to test and troubleshoot limits
- how to avoid dangerous misconfigurations

pam_limits is a critical component of Linux hardening, and this file equips you to use it confidently in real enterprise scenarios.