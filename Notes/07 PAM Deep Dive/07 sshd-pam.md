# sshd-pam.md

This file explains **how SSH authentication flows through PAM**, specifically through the file:
```bash
/etc/pam.d/sshd
```
This is one of the most sensitive PAM configurations because SSH is usually the primary remote entry point into servers. Even a small mistake here can lock out all users, including administrators.

This deep-dive covers:
- how sshd interacts with PAM
- how `sshd` decides whether to use password-auth or system-auth
- when SSH bypasses PAM entirely
- how AD users authenticate via SSH (pam_sss + SSSD + Kerberos)
- detailed breakdown of every sshd-specific PAM directive
- real-world troubleshooting scenarios and commands

No theory, only practical explanations that matter in real environments.

---

<br>
<br>

# SSH authentication flow overview

When a user attempts SSH login, the flow is:
1. `sshd` receives the connection
2. sshd checks **sshd_config** for allowed authentication methods
3. If `PasswordAuthentication yes` → sshd calls PAM
4. PAM loads `/etc/pam.d/sshd`
5. That file usually *includes* / *pulls in* `password-auth`
6. `password-auth` loads the entire authentication stack (pam_unix, pam_sss, faillock, etc.)
7. SSSD does identity + password verification for AD users
8. PAM returns success or failure to sshd
9. sshd allows or denies access

SSH *does not* handle authentication internally unless public-key, keyboard-interactive, or GSSAPI mechanisms skip PAM.

---

<br>
<br>

# PAM file for SSH: `/etc/pam.d/sshd`

Typical Rocky/RHEL-based configuration:
```bash
#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin

account    required     pam_nologin.so
account    include      password-auth

password   include      password-auth

session    include      password-auth
session    include      postlogin
```

This file is intentionally short. The heavy lifting happens in `password-auth` and `system-auth`.

Let’s break down each SSH-specific PAM rule.

---

<br>
<br>

# Line-by-line explanation

## `auth substack password-auth`
This is the most critical line.

It tells PAM:
```bash
Use the entire AUTH phase defined in /etc/pam.d/password-auth
```

That means:
- pam_unix handles local users
- pam_sss handles AD users
- pam_faillock enforces lockouts
- pam_deny stops everything at the end

If this line is missing or broken → SSH password authentication **completely fails**.

Use `substack` instead of `include` to ensure proper success/failure propagation.

---

<br>
<br>

## `auth include postlogin`
The `postlogin` stack usually handles:
- logging
- environment setup
- optional modules

Not critical for authentication but important for environment correctness.

---

<br>
<br>

## `account required pam_nologin.so`
This module blocks non-root logins if `/etc/nologin` exists.

If someone creates `/etc/nologin`, SSH logins stop for all non-root users.

Test:
```bash
touch /etc/nologin
ssh user@server  # will be denied
rm /etc/nologin
```

---

<br>
<br>

## `account include password-auth`
This applies the ACCOUNT phase inside `password-auth`. This checks:
- AD account disabled?
- login hours allowed?
- ad_access_filter?
- local account expiration?

If AD authentication succeeds but SSH still gives "Access denied", the failure is usually in **ACCOUNT phase**.

Debug using:
```bash
tail -f /var/log/sssd/sssd_pam.log
```

---

<br>
<br>

## `password include password-auth`
This controls password change requests received via SSH.

Example:
```bash
ssh user@server
"Your password has expired – please change it now"
```

If password changes fail, check the `password-auth` PAM stack instead.

---

<br>
<br>

## `session include password-auth`
Runs session modules after authentication, including:
- pam_mkhomedir (AD home directory auto-create)
- pam_limits (ulimits)

This is why AD users get home dirs automatically only after SSH login.

If missing, AD users may authenticate but still fail with:
```bash
Could not chdir to home directory
```

---

<br>
<br>

## `session include postlogin`
Handles logging and environment settings.

---

<br>
<br>

# Interaction with sshd_config

sshd_config options heavily influence PAM behavior.

## 1. `PasswordAuthentication yes`
If this is **no**, PAM is completely bypassed.

Check:
```bash
grep -i passwordauth /etc/ssh/sshd_config
```

To enable password-based AD login:
```bash
PasswordAuthentication yes
```
Then:
```bash
systemctl restart sshd
```

---

<br>
<br>

## 2. `UsePAM yes`
If this is **no**, PAM is not used.

Check:
```bash
grep -i usepam /etc/ssh/sshd_config
```

Must be:
```bash
UsePAM yes
```

---

<br>
<br>

## 3. `GSSAPIAuthentication yes`
If enabled, Kerberos logins may happen *before* PAM.

This does not replace PAM, but affects logs.

---

<br>
<br>

## 4. `PubkeyAuthentication yes`
Public-key auth bypasses PAM for the AUTH phase but still runs **SESSION phase**.

This can cause confusion:
- SSH key works
- But home directory missing because pam_mkhomedir did not run for key-based access on some configs

---

<br>
<br>

# How AD users authenticate via SSH

1. SSHD receives AD username
2. SSHD calls PAM → sshd file → password-auth → system-auth
3. pam_sss forwards request to SSSD
4. SSSD uses Kerberos to validate the password
5. SSSD retrieves identity & groups via LDAP
6. SSSD returns success or failure to PAM
7. PAM returns success or failure to SSHD
8. SSHD either grants or denies login

If ANY of these layers fails, SSH login fails.

Debugging must consider all layers.

---

<br>
<br>

# Debugging SSH authentication failures

## 1. Check sshd logs
```bash
tail -f /var/log/secure | grep sshd
```

<br>
<br>

## 2. Check PAM logs
```bash
grep PAM /var/log/secure
```

<br>
<br>

## 3. Check SSSD logs
```bash
tail -f /var/log/sssd/sssd_pam.log
```

<br>
<br>

## 4. Test identity
```bash
id username
```

<br>
<br>

## 5. Test Kerberos
```bash
kinit username
klist
```

If kinit fails, SSH password authentication will fail.

<br>
<br>

## 6. Check DNS
Because Kerberos depends on it:
```bash
host dc01.gohel.local
```

---

<br>
<br>

# Real-world failure scenarios + exact fixes

## Scenario 1: AD users can `su - user` but cannot SSH
Cause → `password-auth` missing pam_sss.so

Fix:
```bash
grep sss /etc/pam.d/password-auth
```
If missing, re-add:
```bash
auth sufficient pam_sss.so use_first_pass
```

---

<br>
<br>

## Scenario 2: SSH shows "Permission denied" but logs show correct password
Cause → ACCOUNT phase blocking user

Check:
```bash
tail -f /var/log/sssd/sssd_pam.log
```
Look for:
- access filter deny
- login hours restricted
- AD account disabled

---

<br>
<br>

## Scenario 3: SSH login takes 15–30 seconds
Cause → SSSD waiting on offline AD servers

Test:
```bash
sssctl domain-status
```

Fix DNS or add multiple DCs.

---

<br>
<br>

## Scenario 4: SSH works but home directory missing
Cause → pam_mkhomedir missing in `session` phase

Fix:
```bash
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

---

<br>
<br>

## Scenario 5: Local users fail via SSH but AD users work
Cause → pam_unix.so misordered

Fix:
```bash
auth sufficient pam_unix.so try_first_pass nullok
```

---

<br>
<br>

# Testing SSH + PAM safely

Keep one root SSH session open.

Test in a second terminal:
```bash
ssh testuser1@server
```

Debug both logs live:
```bash
tail -f /var/log/secure /var/log/sssd/sssd_pam.log
```

---

<br>
<br>

# Checklist after modifying SSH PAM config

- `UsePAM yes` in sshd_config
- `PasswordAuthentication yes` if using password logins
- `/etc/pam.d/sshd` calls password-auth
- `password-auth` contains pam_sss.so
- `system-auth` contains pam_sss.so
- Kerberos works (`kinit username`)
- DNS resolves domain controllers
- Time is synchronized (`chronyc tracking`)

---

<br>
<br>

# What you achieve after this file

You now understand:
- precisely how sshd interacts with PAM
- which file controls which part of SSH authentication
- how AD + SSSD integrate into SSH
- how to debug failures using logs and commands
- how to safely modify SSH authentication behavior

This knowledge is essential for enterprise Linux security and identity management.