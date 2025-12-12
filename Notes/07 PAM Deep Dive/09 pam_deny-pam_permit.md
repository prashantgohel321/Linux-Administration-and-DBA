# pam_deny-pam_permit.md

This file explains **pam_deny.so** and **pam_permit.so**, two of the simplest but most dangerous PAM modules. Even though they look harmless, placing them incorrectly can instantly:
- lock out all users
- grant unintended access
- bypass authentication entirely
- break SSH, su, sudo, or system authentication

These modules must be understood in a **practical, configuration-level, real-world** way — not in theory.

---

- [pam\_deny-pam\_permit.md](#pam_deny-pam_permitmd)
- [What pam\_deny.so actually does](#what-pam_denyso-actually-does)
- [Why pam\_deny.so exists](#why-pam_denyso-exists)
- [What breaks if pam\_deny.so is placed incorrectly](#what-breaks-if-pam_denyso-is-placed-incorrectly)
- [Debugging pam\_deny.so issues](#debugging-pam_denyso-issues)
- [What pam\_permit.so actually does](#what-pam_permitso-actually-does)
- [Why pam\_permit.so exists](#why-pam_permitso-exists)
- [Dangerous misconfigurations with pam\_permit.so](#dangerous-misconfigurations-with-pam_permitso)
- [Correct real-world usage patterns](#correct-real-world-usage-patterns)
  - [Pattern 1: Ensure fail-closed behavior](#pattern-1-ensure-fail-closed-behavior)
  - [Pattern 2: Permit account phase after AD/local checks](#pattern-2-permit-account-phase-after-adlocal-checks)
- [Testing pam\_deny / pam\_permit effects](#testing-pam_deny--pam_permit-effects)
  - [1. Test denial behavior](#1-test-denial-behavior)
  - [2. Test permit behavior](#2-test-permit-behavior)
- [Common failure cases and fixes](#common-failure-cases-and-fixes)
  - [**Failure 1: All users suddenly locked out**](#failure-1-all-users-suddenly-locked-out)
  - [**Failure 2: Password always succeeds**](#failure-2-password-always-succeeds)
  - [**Failure 3: SSH fails but su works**](#failure-3-ssh-fails-but-su-works)
- [Recovery procedure when PAM is broken](#recovery-procedure-when-pam-is-broken)
- [Final rule of thumb](#final-rule-of-thumb)
- [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

# What pam_deny.so actually does

`pam_deny.so` **always returns failure**.

No conditions.
No exceptions.
No arguments.

Example:
```bash
auth required pam_deny.so
```

→ PAM stops the stack and denies authentication.

If this appears anywhere *above* pam_unix.so or pam_sss.so, all users will be denied instantly.

---

<br>
<br>

# Why pam_deny.so exists

It is a **fail-safe module**. It ensures that if no previous module explicitly allowed authentication, access is denied.

Think of it as:
```bash
"If nothing allowed you by now, you are denied."
```

It must **always** appear at the end of the auth, account, password, or session phases.

Example (correct placement):
```bash
auth sufficient pam_unix.so
auth sufficient pam_sss.so
auth required   pam_deny.so   # always last
```

---

<br>
<br>

# What breaks if pam_deny.so is placed incorrectly

Incorrect:
```bash
auth required pam_deny.so
auth sufficient pam_sss.so
```

Result:
- All AD logins fail
- All local logins fail
- su fails
- SSH fails
- Root SSH login fails

The system becomes effectively unusable from PAM’s perspective.

This is why any automation modifying PAM must **never** reorder pam_deny.

---

<br>
<br>

# Debugging pam_deny.so issues

If all logins are failing instantly without even appearing in SSSD logs, pam_deny is the culprit.

Check:
```bash
grep pam_deny /etc/pam.d/*
```

Look for pam_deny appearing before pam_unix, pam_sss, or other modules.

Log entry in `/var/log/secure` typically shows:
```bash
pam_deny(sshd:auth): authentication failure
```

Fix:
1. Move pam_deny.so to the bottom of each section.
2. Restore a backup if needed.

---

<br>
<br>

# What pam_permit.so actually does

`pam_permit.so` **always returns success**.

It unconditionally allows authentication.

Example:
```bash
auth required pam_permit.so
```

→ EVERY login succeeds **even with wrong passwords**.

This is obviously dangerous and should never be used for authentication decisions.

---

<br>
<br>

# Why pam_permit.so exists

It is mostly used internally by PAM when:
- a stacked group of modules needs a default success value
- a placeholder is required while assembling custom stacks

It should almost never appear directly in the `auth` phase unless you’re doing something extremely specific.

Typical safe usage:
```bash
account required pam_permit.so
```
This simply tells PAM that the account phase succeeded.

But even here, it must be understood clearly.

---

<br>
<br>

# Dangerous misconfigurations with pam_permit.so

Example of catastrophic misuse:
```bash
auth sufficient pam_permit.so
```

Effect:
- Any password works.
- All logins succeed.
- SSH becomes wide open.
- sudo, su, and console become insecure.

This is an instant security disaster.

---

<br>
<br>

# Correct real-world usage patterns

## Pattern 1: Ensure fail-closed behavior
```bash
auth sufficient pam_unix.so
auth sufficient pam_sss.so
auth required   pam_deny.so
```

pam_deny ensures secure fallback.

---

<br>
<br>

## Pattern 2: Permit account phase after AD/local checks
```bash
account required pam_unix.so
account [default=bad success=ok user_unknown=ignore] pam_sss.so
account required pam_permit.so
```

Why?
- pam_unix and pam_sss decide account validity.
- pam_permit simply ends the stack cleanly.

This is safe.

---

<br>
<br>

# Testing pam_deny / pam_permit effects

## 1. Test denial behavior
Temporarily simulate failure:
```bash
auth required pam_deny.so
su - username
```
Expect:
```bash
authentication failure
```

<br>
<br>

## 2. Test permit behavior
Temporarily simulate success (DO NOT USE IN PRODUCTION):
```bash
auth sufficient pam_permit.so
```
Test:
```bash
su - wrongpassword
```
If login succeeds → pam_permit is working.

Immediately revert.

---

<br>
<br>

# Common failure cases and fixes

## **Failure 1: All users suddenly locked out**
Cause:
- pam_deny moved above expected location

Fix:
```bash
Move pam_deny.so back to bottom of auth section
``` 

<br>
<br>

## **Failure 2: Password always succeeds**
Cause:
- pam_permit used incorrectly in auth phase

Fix:
```bash
Remove pam_permit from auth
Use pam_permit only in account/session under proper conditions
```

<br>
<br>

## **Failure 3: SSH fails but su works**
Cause:
- pam_deny misplaced in password-auth but not system-auth

Fix:
```bash
Compare:
diff /etc/pam.d/password-auth /etc/pam.d/system-auth
```

---

<br>
<br>

# Recovery procedure when PAM is broken

If pam_deny breaks login and you cannot SSH:

1. Switch to console or use VM console.
2. Restore backups:
```bash
cp /etc/pam.d/system-auth.bak /etc/pam.d/system-auth
cp /etc/pam.d/password-auth.bak /etc/pam.d/password-auth
```
3. Restart SSH:
```bash
systemctl restart sshd
```

Always test PAM edits from a second session.

---

<br>
<br>

# Final rule of thumb

**pam_deny** → always last  
**pam_permit** → rarely needed, and NEVER in `auth` phase

---

<br>
<br>

# What you achieve after this file

You now fully understand the two most misunderstood PAM modules. You know exactly:
- when to use them
- where NOT to place them
- how they affect AD + SSSD
- how to recognize and fix misconfigurations immediately

This knowledge prevents catastrophic authentication failures in enterprise systems and helps maintain strict control over login behavior.