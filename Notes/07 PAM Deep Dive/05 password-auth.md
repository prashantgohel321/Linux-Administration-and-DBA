# password-auth.md

- This file explains **/etc/pam.d/password-auth**, the PAM stack used by *remote logins* such as SSH and sometimes services using PAM via network authentication. While `system-auth` is the global backbone, **password-auth controls how authentication happens specifically for remote access**.

- If this file is wrong, SSH logins will fail even if `system-auth` is correct. In AD + SSSD environments, `password-auth` must align with `system-auth` but cannot simply be ignored or assumed to be identical.

- This file gives a fully practical breakdown: every module, ordering, real-world failures, debugging, and recovery procedures.

---

<br>
<br>

- [password-auth.md](#password-authmd)
- [Why `password-auth` exists](#why-password-auth-exists)
- [Always take a backup before editing](#always-take-a-backup-before-editing)
- [Typical `password-auth` file used in AD setups](#typical-password-auth-file-used-in-ad-setups)
- [Detailed explanation of each phase and its modules](#detailed-explanation-of-each-phase-and-its-modules)
  - [AUTH phase (SSH password validation)](#auth-phase-ssh-password-validation)
    - [`auth required pam_env.so`](#auth-required-pam_envso)
    - [`auth required pam_faillock.so preauth ...`](#auth-required-pam_faillockso-preauth-)
    - [`auth sufficient pam_unix.so`](#auth-sufficient-pam_unixso)
    - [`auth sufficient pam_sss.so use_first_pass`](#auth-sufficient-pam_sssso-use_first_pass)
    - [`auth required pam_faillock.so authfail ...`](#auth-required-pam_faillockso-authfail-)
    - [`auth required pam_deny.so`](#auth-required-pam_denyso)
  - [ACCOUNT phase (AD account eligibility)](#account-phase-ad-account-eligibility)
    - [`account required pam_unix.so`](#account-required-pam_unixso)
    - [`account [default=bad success=ok user_unknown=ignore] pam_sss.so`](#account-defaultbad-successok-user_unknownignore-pam_sssso)
    - [`account required pam_permit.so`](#account-required-pam_permitso)
  - [PASSWORD phase (password change operations)](#password-phase-password-change-operations)
    - [`password requisite pam_pwquality.so`](#password-requisite-pam_pwqualityso)
    - [`password sufficient pam_unix.so`](#password-sufficient-pam_unixso)
    - [`password sufficient pam_sss.so use_authtok`](#password-sufficient-pam_sssso-use_authtok)
    - [`password required pam_deny.so`](#password-required-pam_denyso)
  - [SESSION phase (after SSH login accepted)](#session-phase-after-ssh-login-accepted)
    - [`session optional pam_keyinit.so`](#session-optional-pam_keyinitso)
    - [`session required pam_limits.so`](#session-required-pam_limitsso)
    - [`session optional pam_sss.so`](#session-optional-pam_sssso)
    - [`session required pam_mkhomedir.so`](#session-required-pam_mkhomedirso)
- [Real-world failure scenarios + exact fixes](#real-world-failure-scenarios--exact-fixes)
  - [1. SSH login fails but `su - user` works](#1-ssh-login-fails-but-su---user-works)
  - [2. AD user gets wrong password error even though password is correct](#2-ad-user-gets-wrong-password-error-even-though-password-is-correct)
  - [3. Home directory not created on SSH login](#3-home-directory-not-created-on-ssh-login)
  - [4. Local users can’t SSH but AD users can](#4-local-users-cant-ssh-but-ad-users-can)
  - [5. Account locked after several tries (expected but annoying)](#5-account-locked-after-several-tries-expected-but-annoying)
  - [6. Everything is correct but SSH still says `Permission denied`](#6-everything-is-correct-but-ssh-still-says-permission-denied)
- [Testing changes safely](#testing-changes-safely)
- [Checklist after editing password-auth](#checklist-after-editing-password-auth)
- [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

# Why `password-auth` exists

Remote access (SSH) is security-sensitive and may require:
- stricter rules
- different lockout behavior
- MFA integration
- remote-only access policies

SSH rarely reads `/etc/shadow` directly. Instead, sshd calls PAM → PAM reads `password-auth` → which includes or behaves similarly to `system-auth`.

This means:
- SSH success depends on `password-auth` correctness
- AD user login depends on both SSSD + PAM + Kerberos + `password-auth`

If SSH fails but `su - user` works, the issue is almost always in `password-auth`.

---

<br>
<br>

# Always take a backup before editing

```bash
cp /etc/pam.d/password-auth /etc/pam.d/password-auth.bak-$(date +%F-%T)
```

Same rule as system-auth: **do not edit blindly**, keep a root session open.

---

<br>
<br>

# Typical `password-auth` file used in AD setups

```bash
# auth phase
auth        required      pam_env.so
auth        required      pam_faillock.so preauth silent audit deny=3 unlock_time=900
auth        sufficient    pam_unix.so try_first_pass nullok
auth        sufficient    pam_sss.so use_first_pass
auth        required      pam_faillock.so authfail audit deny=3 unlock_time=900
auth        required      pam_deny.so

# account phase
account     required      pam_unix.so
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so

# password phase
password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass
password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so

# session phase
session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     optional      pam_sss.so
session     required      pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

`password-auth` is structurally similar to `system-auth` but may differ depending on authselect profile.

---

<br>
<br>

# Detailed explanation of each phase and its modules

## AUTH phase (SSH password validation)

### `auth required pam_env.so`
Loads environment variables. Not critical.

### `auth required pam_faillock.so preauth ...`
Runs *before* password check. Maintains failure counters.

### `auth sufficient pam_unix.so`
Checks **local** passwords. If a local user's password matches, authentication succeeds immediately.

If this line is missing or misordered:
- Local accounts won't work via SSH.
- SSH remote login fails for local root unless PermitRootLogin yes.

### `auth sufficient pam_sss.so use_first_pass`
Hands authentication off to SSSD → AD.

If missing:
- AD users **cannot** SSH.
- `su - user@domain` might work, but SSH will not.

### `auth required pam_faillock.so authfail ...`
Records failed attempts.

### `auth required pam_deny.so`
Stops all remaining auth. Must be the final rule.

---

<br>
<br>

## ACCOUNT phase (AD account eligibility)

### `account required pam_unix.so`
Validates local accounts.

### `account [default=bad success=ok user_unknown=ignore] pam_sss.so`
This line checks AD account conditions:
- is account disabled?
- is login allowed?
- is user found in AD?

If this line breaks, AD SSH will fail **even when passwords are correct**.

### `account required pam_permit.so`
Ensures that system accounts are not blocked by accident.

---

<br>
<br>

## PASSWORD phase (password change operations)
Used when running `passwd` remotely.

If password changes fail remotely:
- check pam_pwquality
- check pam_sss use_authtok
- check AD password policies

### `password requisite pam_pwquality.so`
Enforces complexity for local accounts.

### `password sufficient pam_unix.so`
Handles local password change.

### `password sufficient pam_sss.so use_authtok`
Allows AD password change.

### `password required pam_deny.so`
Stop here; mandatory.

---

<br>
<br>

## SESSION phase (after SSH login accepted)

### `session optional pam_keyinit.so`
Init keyring.

### `session required pam_limits.so`
Applies ulimits.

### `session optional pam_sss.so`
Handles session-related tasks with SSSD. Optional.

### `session required pam_mkhomedir.so`
Creates home directory **if missing**.

If missing:
```bash
Could not chdir to home directory: No such file or directory
```

---

<br>
<br>

# Real-world failure scenarios + exact fixes

## 1. SSH login fails but `su - user` works
**Cause:** `password-auth` missing pam_sss.so in auth phase.

Fix:
```bash
grep sss /etc/pam.d/password-auth
```
If empty → re-add:
```bash
auth sufficient pam_sss.so use_first_pass
```
Restart sshd:
```bash
systemctl restart sshd
```

---

<br>
<br>

## 2. AD user gets wrong password error even though password is correct
**Cause:** Kerberos working, but ACCOUNT phase denies access.

Fix:
```bash
tail -f /var/log/sssd/sssd_pam.log
```
Look for:
- account disabled
- not in access group
- ad_access_filter violation

---

<br>
<br>

## 3. Home directory not created on SSH login
**Cause:** missing pam_mkhomedir or oddjobd not running.

Fix:
```bash
systemctl enable --now oddjobd
```
Ensure:
```bash
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

---

<br>
<br>

## 4. Local users can’t SSH but AD users can
**Cause:** pam_unix.so missing or misordered.

Fix:
```bash
auth sufficient pam_unix.so try_first_pass nullok
```

---

<br>
<br>

## 5. Account locked after several tries (expected but annoying)
Check lock status:
```bash
faillock --user username
```
Reset:
```bash
faillock --user username --reset
```

Adjust lockout policy in faillock lines.

---

<br>
<br>

## 6. Everything is correct but SSH still says `Permission denied`
Run end-to-end debugging:

Terminal 1:
```bash
tail -f /var/log/secure
```
Terminal 2:
```bash
ssh testuser1@server
```

Then inspect:
```bash
tail -f /var/log/sssd/sssd_pam.log
```

This reveals exactly which PAM phase fails.

---

<br>
<br>

# Testing changes safely

1. Keep an active root session open.
2. Edit `/etc/pam.d/password-auth`.
3. Open a second terminal and test SSH.
4. If locked out, restore backup:
```bash
cp password-auth.bak-* /etc/pam.d/password-auth
systemctl restart sshd
```

---

<br>
<br>

# Checklist after editing password-auth

- Does `grep sss /etc/pam.d/password-auth` show pam_sss?  
- Does `id username` work?  
- Does `kinit username` work?  
- Does SSH login succeed?  
- Does `/var/log/secure` show PAM errors?  
- Does `/var/log/sssd/sssd_pam.log` show AD errors?  

---

<br>
<br>

# What you achieve after this file

- You now understand **exactly how password-auth works**, how each module affects SSH logins, how to debug failures, and how to recover safely. You can now modify and troubleshoot remote authentication in a controlled, predictable way.

- This file makes you fully confident when working with PAM for SSH + SSSD + AD in enterprise environments.