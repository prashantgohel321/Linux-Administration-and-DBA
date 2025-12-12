# troubleshooting_pam.md

This file is your **complete, practical troubleshooting guide** for PAM.  
The focus is not theory — only real-world diagnosis, exact log paths, clear symptoms, and the commands you actually run when PAM breaks.

If authentication fails anywhere (SSH, su, sudo, login, AD, local users), PAM is always in the path. Knowing how to debug PAM is mandatory for enterprise Linux administration.

This file covers:
- how PAM failure looks in logs
- how to isolate whether the problem is PAM, SSSD, Kerberos, SSHD, or password-auth
- how to debug each PAM phase (auth, account, password, session)
- recovery without losing system access
- common enterprise failure cases and exact fixes

---

- [troubleshooting\_pam.md](#troubleshooting_pammd)
- [1. When PAM breaks, what symptoms look like](#1-when-pam-breaks-what-symptoms-look-like)
  - [Symptom: SSH says "Permission denied"](#symptom-ssh-says-permission-denied)
  - [Symptom: su works but SSH fails](#symptom-su-works-but-ssh-fails)
  - [Symptom: SSH works but su fails](#symptom-ssh-works-but-su-fails)
  - [Symptom: AD user authenticates with correct password but is denied access](#symptom-ad-user-authenticates-with-correct-password-but-is-denied-access)
  - [Symptom: Home directory not created on first login](#symptom-home-directory-not-created-on-first-login)
- [2. Log files used to debug PAM](#2-log-files-used-to-debug-pam)
  - [/var/log/secure](#varlogsecure)
  - [SSSD logs (critical when AD involved)](#sssd-logs-critical-when-ad-involved)
  - [Kerberos logs](#kerberos-logs)
- [3. Debugging methodology (step-by-step)](#3-debugging-methodology-step-by-step)
  - [Step 1: Check if identity is available](#step-1-check-if-identity-is-available)
  - [Step 2: Test Kerberos authentication](#step-2-test-kerberos-authentication)
  - [Step 3: Check SSSD PAM logs](#step-3-check-sssd-pam-logs)
  - [Step 4: Check password-auth and system-auth ordering](#step-4-check-password-auth-and-system-auth-ordering)
  - [Step 5: Check ACCOUNT phase failures](#step-5-check-account-phase-failures)
  - [Step 6: Check SESSION phase issues](#step-6-check-session-phase-issues)
- [4. Common enterprise PAM failures and exact fixes](#4-common-enterprise-pam-failures-and-exact-fixes)
  - [Failure 1: All users suddenly locked out after PAM edit](#failure-1-all-users-suddenly-locked-out-after-pam-edit)
  - [Failure 2: Local users cannot SSH but AD users can](#failure-2-local-users-cannot-ssh-but-ad-users-can)
  - [Failure 3: AD users can SSH but cannot `su` to root](#failure-3-ad-users-can-ssh-but-cannot-su-to-root)
  - [Failure 4: AD user password correct but denied](#failure-4-ad-user-password-correct-but-denied)
  - [Failure 5: SSH login extremely slow](#failure-5-ssh-login-extremely-slow)
  - [Failure 6: Home directory not created](#failure-6-home-directory-not-created)
  - [Failure 7: Root cannot SSH (even when PermitRootLogin yes)](#failure-7-root-cannot-ssh-even-when-permitrootlogin-yes)
- [5. Fixing PAM misconfigurations safely](#5-fixing-pam-misconfigurations-safely)
  - [Always keep a root session open](#always-keep-a-root-session-open)
  - [Always back up before editing](#always-back-up-before-editing)
  - [Validate syntax](#validate-syntax)
- [6. Deep troubleshooting commands](#6-deep-troubleshooting-commands)
  - [Test PAM directly using pamtester](#test-pam-directly-using-pamtester)
  - [Trace PAM calls](#trace-pam-calls)
  - [Compare auth stacks](#compare-auth-stacks)
- [7. Checklist before declaring PAM the problem](#7-checklist-before-declaring-pam-the-problem)
- [8. Checklist for PAM-specific debugging](#8-checklist-for-pam-specific-debugging)
- [9. What to do if PAM is completely broken](#9-what-to-do-if-pam-is-completely-broken)
- [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

# 1. When PAM breaks, what symptoms look like

## Symptom: SSH says "Permission denied"
Likely failures:
- pam_sss missing or misordered
- pam_deny placed too early
- account phase rejecting AD user
- faillock blocking account
- Kerberos failed → SSSD returns auth-failure

Logs usually reveal which one.

---

## Symptom: su works but SSH fails
This means:
- system-auth is healthy
- password-auth is broken

Because SSH uses `password-auth`, but `su` uses `system-auth`.

Fix by comparing:
```bash
diff /etc/pam.d/system-auth /etc/pam.d/password-auth
```

---

## Symptom: SSH works but su fails
This means:
- password-auth OK
- system-auth broken

Check su logs:
```bash
grep su: /var/log/secure
```

---

## Symptom: AD user authenticates with correct password but is denied access
ACCOUNT phase failure:
- access filter
- login hours
- account disabled in AD

Check SSSD account logs:
```bash
tail -f /var/log/sssd/sssd_pam.log
```

---

## Symptom: Home directory not created on first login
SESSION phase issue:
- pam_mkhomedir missing
- oddjobd not running

Fix:
```bash
systemctl enable --now oddjobd
```

---

<br>
<br>

# 2. Log files used to debug PAM

PAM doesn’t have a single log file. You must look in multiple places:

## /var/log/secure
General PAM authentication messages:
```bash
tail -f /var/log/secure | grep PAM
```

You will see errors such as:
```bash
pam_sss(sshd:auth): authentication failure
pam_unix(su:auth): check pass; user unknown
pam_faillock(sshd:auth): Consecutive authentication failures
```

## SSSD logs (critical when AD involved)
```bash
tail -f /var/log/sssd/sssd_pam.log
tail -f /var/log/sssd/sssd_domain.log
```

If SSSD fails, PAM cannot authenticate AD users at all.

## Kerberos logs
```bash
/var/log/krb5kdc.log
journalctl -u sssd -u oddjobd -u sshd
```

---

<br>
<br>

# 3. Debugging methodology (step-by-step)

When authentication fails, **never guess**. Follow this strict sequence.

---

## Step 1: Check if identity is available
```bash
id username
```
If this fails:
- SSSD offline
- DNS wrong
- AD unreachable

Fix these BEFORE touching PAM.

---

## Step 2: Test Kerberos authentication
```bash
kinit username
klist
```
If this fails:
- bad password
- wrong time sync
- DNS SRV broken

This is NOT a PAM issue yet.

---

## Step 3: Check SSSD PAM logs
```bash
tail -f /var/log/sssd/sssd_pam.log
```
Common messages:
- `PAM: user not found`
- `PAM: access denied`
- `PAM: offline authentication failed`

If logs show nothing → PAM not calling pam_sss → misordered configuration.

---

## Step 4: Check password-auth and system-auth ordering
Search for pam_sss and pam_unix:
```bash
grep -n sss /etc/pam.d/system-auth
grep -n sss /etc/pam.d/password-auth
```
Correct example:
```bash
auth sufficient pam_unix.so try_first_pass nullok
auth sufficient pam_sss.so use_first_pass
auth required  pam_deny.so
```

If pam_deny.so appears BEFORE pam_sss or pam_unix, that is a lockout.

---

## Step 5: Check ACCOUNT phase failures
```bash
tail -f /var/log/secure
```
Look for:
```bash
pam_sss(sshd:account): Access denied for user
```
This means the password is correct but access policy blocks login.

Check SSSD config:
```bash
cat /etc/sssd/sssd.conf | grep access
```

---

## Step 6: Check SESSION phase issues
If login succeeds but session fails (no home dir, no limits):
- pam_limits missing
- pam_mkhomedir missing
- oddjobd stopped

---

<br>
<br>

# 4. Common enterprise PAM failures and exact fixes

## Failure 1: All users suddenly locked out after PAM edit
Cause:
- pam_deny moved up
- wrong order of pam_unix / pam_sss

Fix:
1. Console login via VM
2. Restore backups:
```bash
cp /etc/pam.d/system-auth.bak-* /etc/pam.d/system-auth
cp /etc/pam.d/password-auth.bak-* /etc/pam.d/password-auth
```
3. Restart sshd

---

## Failure 2: Local users cannot SSH but AD users can
Cause:
- pam_unix.so missing or wrong flags

Fix:
```bash
auth sufficient pam_unix.so try_first_pass nullok
```

---

## Failure 3: AD users can SSH but cannot `su` to root
Cause:
- not in wheel group

Fix:
```bash
gpasswd -a 'DOMAIN\\Admins' wheel
```

---

## Failure 4: AD user password correct but denied
Cause:
- ACCOUNT phase rejects user

Fix:
Check SSSD access control settings:
```bash
sssctl domain-status
```
Look for:
- access_provider
- ad_access_filter

---

## Failure 5: SSH login extremely slow
Cause:
- SSSD timeout waiting for unreachable DC

Check:
```bash
sssctl domain-status
```
Fix DNS or add multiple domain controllers.

---

## Failure 6: Home directory not created
Cause:
- pam_mkhomedir missing
- oddjobd not running

Fix:
```bash
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
systemctl enable --now oddjobd
```

---

## Failure 7: Root cannot SSH (even when PermitRootLogin yes)
Cause:
- PAM rule blocks UID 0

Fix:
Remove or adjust:
```bash
auth requisite pam_succeed_if.so uid != 0
```

---

<br>
<br>

# 5. Fixing PAM misconfigurations safely

## Always keep a root session open
Never edit PAM without an active root shell.

## Always back up before editing
```bash
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak
cp /etc/pam.d/password-auth /etc/pam.d/password-auth.bak
```

## Validate syntax
```bash
pamtester sshd username authenticate
```
Very useful for debugging.

---

<br>
<br>

# 6. Deep troubleshooting commands

## Test PAM directly using pamtester
```bash
pamtester login username authenticate
```
This bypasses SSH and tests PAM directly.

## Trace PAM calls
```bash
tail -f /var/log/secure
tail -f /var/log/sssd/sssd_pam.log
journalctl -u sshd -f
```

<br>
<br>

## Compare auth stacks
```bash
diff /etc/pam.d/system-auth /etc/pam.d/password-auth
```

---

<br>
<br>

# 7. Checklist before declaring PAM the problem

Confirm the following:
- DNS resolves AD domain controllers
- krb5.conf configured correctly
- time synchronized (chronyc tracking)
- SSSD online and working
- id username works
- kinit username works

If these fail → **not** a PAM issue.

PAM is the last layer — always debug lower layers first.

---

<br>
<br>

# 8. Checklist for PAM-specific debugging

- Is pam_sss in AUTH and ACCOUNT phases?
- Is pam_unix correctly placed?
- Is pam_deny at the bottom?
- Are faillock rules properly placed?
- Are session modules present?
- Do password-auth and system-auth match?
- Is sshd using PAM?

```bash
grep -i UsePAM /etc/ssh/sshd_config
```  

---

<br>
<br>

# 9. What to do if PAM is completely broken

Worst-case recovery procedure:
1. Open VM console (not SSH)
2. Restore known-good PAM config
3. Restart services
4. Test SSH in second session

Never leave server with only one active session after PAM edits.

---

<br>
<br>

# What you achieve after this file

You now have a **complete, practical, enterprise-grade PAM troubleshooting guide**.  
You know exactly:
- where failures occur
- how to read logs
- how to isolate whether the issue is PAM, SSSD, Kerberos, or SSH
- how to fix common problems
- how to recover safely

This file prepares you for real production troubleshooting — the kind of work Linux administrators and DevOps engineers face daily.