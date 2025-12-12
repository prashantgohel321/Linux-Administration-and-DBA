# common-pam-configurations.md

This file collects **all commonly used, real-world PAM configurations** you will encounter when working with Linux authentication, especially in AD + SSSD environments. The goal is simple: when you need a specific behavior, you should know exactly which PAM lines to add, remove, or modify — without guessing.

Each configuration includes:
- what it does
- when to use it
- the exact PAM lines
- how to test it
- what breaks if misconfigured

This is a practical reference designed for real admin work.

---

- [common-pam-configurations.md](#common-pam-configurationsmd)
- [1. Allow both local Linux users and AD users to authenticate](#1-allow-both-local-linux-users-and-ad-users-to-authenticate)
    - [Why this works](#why-this-works)
    - [Test](#test)
- [2. Allow only AD users to SSH (block local accounts from SSH)](#2-allow-only-ad-users-to-ssh-block-local-accounts-from-ssh)
    - [Behavior](#behavior)
    - [Test](#test-1)
    - [What can break](#what-can-break)
- [3. Enable automatic home directory creation for AD users](#3-enable-automatic-home-directory-creation-for-ad-users)
    - [Test](#test-2)
- [4. Enforce account lockout after failed attempts](#4-enforce-account-lockout-after-failed-attempts)
    - [Test](#test-3)
- [5. Restrict su-to-root only to wheel group](#5-restrict-su-to-root-only-to-wheel-group)
    - [Behavior](#behavior-1)
    - [Add AD group to wheel:](#add-ad-group-to-wheel)
    - [Test](#test-4)
- [6. Disable root SSH login via PAM (extra layer)](#6-disable-root-ssh-login-via-pam-extra-layer)
    - [Result](#result)
    - [Test](#test-5)
- [7. Allow only users in specific AD groups to SSH](#7-allow-only-users-in-specific-ad-groups-to-ssh)
    - [Behavior](#behavior-2)
    - [Test](#test-6)
- [8. Allow local root login but block all other local users](#8-allow-local-root-login-but-block-all-other-local-users)
    - [Effect](#effect)
- [9. Allow password login but deny password changes (secure environments)](#9-allow-password-login-but-deny-password-changes-secure-environments)
    - [Test](#test-7)
- [10. Enforce strong password policy locally only](#10-enforce-strong-password-policy-locally-only)
    - [Behavior](#behavior-3)
- [11. Disable local accounts entirely (rare but used in hardened servers)](#11-disable-local-accounts-entirely-rare-but-used-in-hardened-servers)
    - [Result](#result-1)
- [12. MFA integration example (OTP before AD password)](#12-mfa-integration-example-otp-before-ad-password)
    - [Flow](#flow)
- [13. Log all PAM failures for auditing](#13-log-all-pam-failures-for-auditing)
- [14. Temporary maintenance mode (allow only root)](#14-temporary-maintenance-mode-allow-only-root)
    - [Result](#result-2)
- [15. Permit AD users to su-to-root](#15-permit-ad-users-to-su-to-root)
- [16. Deny SSH login from specific AD groups](#16-deny-ssh-login-from-specific-ad-groups)
    - [Behavior](#behavior-4)
- [17. Force password prompt even if previous module succeeded](#17-force-password-prompt-even-if-previous-module-succeeded)
- [18. Require AD authentication even for local users (rare)](#18-require-ad-authentication-even-for-local-users-rare)
    - [Result](#result-3)
- [19. Block SSH key-based login via PAM](#19-block-ssh-key-based-login-via-pam)
- [20. Fail open vs fail closed configurations](#20-fail-open-vs-fail-closed-configurations)
- [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

# 1. Allow both local Linux users and AD users to authenticate

This is the **baseline** configuration used in most enterprise setups.

Add in `system-auth` and `password-auth`:
```bash
auth    sufficient    pam_unix.so try_first_pass nullok
auth    sufficient    pam_sss.so use_first_pass
auth    required      pam_deny.so
```

### Why this works
- Local users authenticate via pam_unix
- AD users authenticate via pam_sss
- pam_deny prevents anyone else from slipping through

### Test
```bash
su - localuser
su - aduser@domain
ssh aduser@server
```

If AD users fail but `id` works → pam_sss line missing.

---

<br>
<br>

# 2. Allow only AD users to SSH (block local accounts from SSH)

Used when local logins are not allowed for security reasons.

Edit `/etc/pam.d/sshd` → before `auth substack password-auth`, add:
```bash
auth    requisite    pam_succeed_if.so uid >= 100000
```
(Change UID threshold depending on AD user UID range.)

### Behavior
- Local users blocked
- AD users allowed

### Test
```bash
ssh localuser@server   # denied
ssh aduser@server      # allowed
```

### What can break
- If uid filtering is incorrect, AD users may also be blocked.

---

<br>
<br>

# 3. Enable automatic home directory creation for AD users

In `system-auth` and `password-auth`:
```bash
session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

or if using oddjob:
```bash
session    required    pam_oddjob_mkhomedir.so umask=0077
```

### Test
```bash
ssh aduser@server
ls /home/aduser
```

If not created → oddjobd not running:
```bash
systemctl enable --now oddjobd
```

---

<br>
<br>

# 4. Enforce account lockout after failed attempts

Placed in both `system-auth` and `password-auth`:
```bash
auth        required      pam_faillock.so preauth silent audit deny=3 unlock_time=900
auth        [success=1]   pam_faillock.so authfail audit deny=3 unlock_time=900
account     required      pam_faillock.so
```

### Test
Try three failed passwords:
```bash
ssh aduser@server
faillock --user aduser
```

Reset lock:
```bash
faillock --user aduser --reset
```

---

<br>
<br>

# 5. Restrict su-to-root only to wheel group

Add in `/etc/pam.d/su`:
```bash
auth    required    pam_wheel.so use_uid
```

### Behavior
Only wheel members can run `su -`.

### Add AD group to wheel:
```bash
gpasswd -a 'DOMAIN\\Admins' wheel
```

### Test
```bash
su -
```

---

<br>
<br>

# 6. Disable root SSH login via PAM (extra layer)

Even if `PermitRootLogin yes` in sshd config, PAM can block root.

Add in `/etc/pam.d/sshd`:
```bash
auth    requisite    pam_succeed_if.so uid != 0
```

### Result
Root login via SSH is denied.

### Test
```bash
ssh root@server   # should fail
```

---

<br>
<br>

# 7. Allow only users in specific AD groups to SSH

In `/etc/pam.d/sshd` before password-auth:
```bash
auth    required    pam_succeed_if.so user ingroup DOMAIN\\LinuxUsers
```

### Behavior
- Only members of AD group LinuxUsers can SSH
- Others fail immediately

### Test
```bash
id aduser
ssh aduser@server
```

If group mapping fails → check:
```bash
getent group 'DOMAIN\\LinuxUsers'
```

---

<br>
<br>

# 8. Allow local root login but block all other local users

In `password-auth`:
```bash
auth requisite pam_succeed_if.so uid = 0
```

Then below:
```bash
auth requisite pam_succeed_if.so uid >= 100000
```

### Effect
- Only root or AD users can SSH

---

<br>
<br>

# 9. Allow password login but deny password changes (secure environments)

In PASSWORD phase:
```bash
password    required    pam_deny.so
```

### Test
```bash
passwd aduser   # should fail
```

---

<br>
<br>

# 10. Enforce strong password policy locally only

In PASSWORD phase:
```bash
password requisite pam_pwquality.so try_first_pass retry=3 minlen=12 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1
```

### Behavior
- AD password policies still enforced by AD
- Local accounts follow pwquality rules

---

<br>
<br>

# 11. Disable local accounts entirely (rare but used in hardened servers)

In `system-auth` before pam_unix:
```bash
auth    requisite    pam_succeed_if.so uid >= 100000
```

### Result
- All local users blocked
- AD users still allowed

---

<br>
<br>

# 12. MFA integration example (OTP before AD password)

Place before pam_sss:
```bash
auth required pam_google_authenticator.so nullok
```

Then:
```bash
auth sufficient pam_sss.so use_first_pass
```

### Flow
1. OTP required
2. AD password required

---

<br>
<br>

# 13. Log all PAM failures for auditing

In any PAM file:
```bash
auth optional pam_warn.so
```

Check logs:
```bash
grep pam_warn /var/log/secure
```

---

<br>
<br>

# 14. Temporary maintenance mode (allow only root)

In `sshd`:
```bash
auth requisite pam_succeed_if.so uid = 0
```

### Result
- Only root can SSH
- Useful for maintenance windows

---

<br>
<br>

# 15. Permit AD users to su-to-root

Add AD group to wheel:
```bash
gpasswd -a 'DOMAIN\\Admins' wheel
```

No PAM change required, pam_wheel handles it.

---

<br>
<br>

# 16. Deny SSH login from specific AD groups

In `/etc/pam.d/sshd`:
```bash
auth [success=1 default=ignore] pam_succeed_if.so user ingroup DOMAIN\\BlockedGroup
auth requisite pam_deny.so
```

### Behavior
Members of BlockedGroup cannot SSH.

---

<br>
<br>

# 17. Force password prompt even if previous module succeeded

Use `use_first_pass` vs `try_first_pass` options carefully.

Example:
```bash
auth sufficient pam_unix.so try_first_pass
```
Allows local users to authenticate without reprompting.

Changing to:
```bash
auth sufficient pam_unix.so use_first_pass
```
Forces use of previous password — can cause failures if pam_faillock or other module rejects it.

---

<br>
<br>

# 18. Require AD authentication even for local users (rare)

Remove pam_unix from AUTH phase:
```bash
auth sufficient pam_unix.so
```
→ delete

Keep only pam_sss:
```bash
auth sufficient pam_sss.so
```

### Result
Local passwords no longer work.

---

<br>
<br>

# 19. Block SSH key-based login via PAM

Add in `/etc/pam.d/sshd`:
```bash
auth requisite pam_listfile.so item=service sense=deny file=/etc/ssh/deny_pubkey.txt
```

Not common but used in strict security environments.

---

<br>
<br>

# 20. Fail open vs fail closed configurations

**Fail open** example:
```bash
auth [success=ok default=ignore] pam_sss.so
```
If SSSD unavailable, login may still succeed → not secure.

**Fail closed** example (recommended):
```bash
auth sufficient pam_sss.so use_first_pass
```
If SSSD fails, authentication fails.

---

<br>
<br>

# What you achieve after this file

You now have a complete library of PAM configurations used in real enterprise setups. With this:
- You can enforce any login policy required
- You can allow or block any class of users
- You can tune AD authentication cleanly
- You can troubleshoot failures quickly using predictable patterns

This file becomes your reference handbook for modifying PAM safely, correctly, and confidently.
