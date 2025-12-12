# pam-overview.md

- In this file I am building a complete, practical understanding of **PAM (Pluggable Authentication Modules)**. I want clarity on what PAM actually is, how it behaves internally, how Linux uses it during authentication, and why certain modules like `pam_sss.so`, `pam_unix.so`, and `pam_deny.so` matter. PAM is the central point of authentication in Linux, so without understanding PAM, troubleshooting AD or SSSD issues is incomplete.

- This file is written for practical, real-world debugging and configuration.

---

- [pam-overview.md](#pam-overviewmd)
- [What PAM actually is](#what-pam-actually-is)
- [Where PAM config lives](#where-pam-config-lives)
- [PAM rule structure explained](#pam-rule-structure-explained)
    - [PAM types](#pam-types)
    - [Control flags](#control-flags)
- [PAM’s four phases](#pams-four-phases)
  - [1. auth phase](#1-auth-phase)
  - [2. account phase](#2-account-phase)
  - [3. password phase](#3-password-phase)
  - [4. session phase](#4-session-phase)
- [The most important PAM modules](#the-most-important-pam-modules)
    - [pam\_unix.so](#pam_unixso)
    - [pam\_sss.so](#pam_sssso)
    - [pam\_deny.so](#pam_denyso)
    - [pam\_permit.so](#pam_permitso)
    - [pam\_faillock.so](#pam_faillockso)
- [How PAM decides success or failure](#how-pam-decides-success-or-failure)
- [How PAM interacts with SSSD](#how-pam-interacts-with-sssd)
- [Testing PAM behavior in practice](#testing-pam-behavior-in-practice)
  - [1. Test login via PAM (su)](#1-test-login-via-pam-su)
  - [2. Test PAM using pamtester (optional tool)](#2-test-pam-using-pamtester-optional-tool)
  - [3. Check PAM logs](#3-check-pam-logs)
- [Typical PAM-related failures](#typical-pam-related-failures)
    - [1. AD users can’t log in but `id` works](#1-ad-users-cant-log-in-but-id-works)
    - [2. AD users authed once but fail later](#2-ad-users-authed-once-but-fail-later)
    - [3. Local users fail login](#3-local-users-fail-login)
    - [4. All users fail](#4-all-users-fail)
- [Checking PAM configuration](#checking-pam-configuration)
- [A good baseline PAM config for AD integration](#a-good-baseline-pam-config-for-ad-integration)
- [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

# What PAM actually is

PAM is a framework that lets Linux plug in different authentication modules dynamically. When a user logs in (SSH, console, su, sudo), Linux does not authenticate the user directly. Instead, it hands over authentication to PAM.

PAM then decides:
- how passwords must be checked
- how accounts are validated
- how sessions are initialized
- whether to allow or block access

PAM works using small plugins (.so modules), and the rules for how PAM behaves are defined in `/etc/pam.d/*` files.

So **PAM does not authenticate anyone by itself**. It just calls modules in order.

---

<br>
<br>

# Where PAM config lives

Every application that uses PAM has a file under:
```bash
/etc/pam.d/
```

Examples:
- `/etc/pam.d/sshd` → SSH logins
- `/etc/pam.d/login` → console logins
- `/etc/pam.d/su` → switching users
- `/etc/pam.d/sudo` → sudo command
- `/etc/pam.d/system-auth` → global authentication stack
- `/etc/pam.d/password-auth` → network logins like SSH

These files contain PAM rules in the format:
```bash
type  control_flag  module.so  arguments
```

I need to understand each part.

---

<br>
<br>

# PAM rule structure explained

Example:
```bash
auth sufficient pam_sss.so
```

Breakdown:
- `auth` → phase (authentication)
- `sufficient` → control flag
- `pam_sss.so` → module

### PAM types
Common types:
- `auth` → authentication
- `account` → account validity
- `password` → password changes
- `session` → start/stop session

### Control flags
These flags decide how PAM behaves if a module succeeds or fails.

- **required** → must succeed, but continue evaluating other modules
- **requisite** → must succeed, fail immediately if not
- **sufficient** → if succeeds, stop and return success
- **optional** → used only if no other module makes a decision

Example:
```bash
auth    sufficient    pam_sss.so
```
means:
- if AD authentication via SSSD succeeds, PAM stops there and login is granted.

Another example:
```bash
auth    requisite     pam_unix.so
```
means:
- if local password fails, stop immediately.

---

<br>
<br>

# PAM’s four phases

PAM uses four phases for authentication workflow.

## 1. auth phase
Confirms the user’s identity.
- `pam_unix.so` → local password
- `pam_sss.so` → AD authentication via SSSD
- `pam_faillock.so` → lockout policy

## 2. account phase
Checks account validity.
- is the account expired?
- is login allowed at this time?
- is account disabled in AD?

`pam_sss.so` in account phase checks AD-specific restrictions.

## 3. password phase
Responsible for password changes.

## 4. session phase
Executes after successful authentication.
- `pam_mkhomedir.so` → create home directory
- session logging

---

<br>
<br>

# The most important PAM modules

### pam_unix.so
Handles authentication using `/etc/shadow` (local accounts).

### pam_sss.so
Hands authentication to SSSD → AD/Kerberos/LDAP.

If this module is missing, AD authentication cannot work.

### pam_deny.so
Always denies access. Used as a final safety net.

### pam_permit.so
Always allows access. Almost never used.

### pam_faillock.so
Locks accounts after repeated failed logins.

---

<br>
<br>

# How PAM decides success or failure

Important logic:
- If a *sufficient* module succeeds → authentication succeeds immediately.
- If a *required* module fails → authentication will fail but only after evaluating remaining modules.
- If a *requisite* module fails → fail immediately.
- If all modules fail → authentication denied.

This explains why order matters.

Example:
```bash
auth sufficient pam_unix.so
```
If the local user’s password works, PAM will **never try AD authentication**.

This is why correct ordering is crucial.

---

<br>
<br>

# How PAM interacts with SSSD

When PAM reaches:
```bash
pam_sss.so
```

It calls SSSD and asks:
- Who is this user?
- Does the password match?
- Is the account allowed?

SSSD then talks to AD. PAM just waits.

If SSSD returns OK → PAM grants access.

If SSSD returns error → PAM logs failure.

---

<br>
<br>

# Testing PAM behavior in practice

## 1. Test login via PAM (su)
```bash
su - testuser1
```

## 2. Test PAM using pamtester (optional tool)
```bash
pamtester login testuser1 authenticate
```

## 3. Check PAM logs
All PAM activity logs go to:
```bash
/var/log/secure
```

Search PAM errors:
```bash
grep PAM /var/log/secure
```

---

<br>
<br>

# Typical PAM-related failures

### 1. AD users can’t log in but `id` works
Cause: `pam_sss.so` missing in system-auth or password-auth.

### 2. AD users authed once but fail later
Cause: faillock, lockout policy applied.

### 3. Local users fail login
Cause: pam_unix.so in wrong order or overwritten.

### 4. All users fail
Cause: pam_deny.so placed too early.

---

<br>
<br>

# Checking PAM configuration

Check for sss modules:
```bash
grep sss /etc/pam.d/*
```

Check system-auth:
```bash
cat /etc/pam.d/system-auth
```

Check password-auth:
```bash
cat /etc/pam.d/password-auth
```

---

<br>
<br>

# A good baseline PAM config for AD integration

Example (simplified):
```bash
auth        required      pam_env.so
auth        sufficient    pam_unix.so
auth        sufficient    pam_sss.so
auth        required      pam_deny.so
```

This ensures:
- local users still work
- AD users authenticate via SSSD
- anything not handled is denied

---

<br>
<br>

# What I achieve after this file

- By mastering PAM, I understand the exact path authentication takes before reaching SSSD and AD. I know how to read PAM configs, how to manipulate module order, how to debug using logs, and how PAM integrates with every authentication component in Linux. This knowledge is essential for controlling login behavior in any enterprise environment.