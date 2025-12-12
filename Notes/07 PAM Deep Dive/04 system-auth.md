# system-auth.md

- This file is an exhaustive, practical reference for `/etc/pam.d/system-auth` on Rocky Linux (RHEL derivatives). `system-auth` is the central PAM stack used by most services. If this file is wrong, SSH, console login, `su`, `sudo` and many other authentication points can break. I will explain what each line commonly does, why ordering and control flags matter, how to edit safely, how to test, and exactly which commands to run to recover if something breaks.

- This is written for real troubleshooting and real systems — no fluff.

---

- [system-auth.md](#system-authmd)
  - [What `system-auth` is and why it exists](#what-system-auth-is-and-why-it-exists)
  - [Always take a backup before editing](#always-take-a-backup-before-editing)
  - [Anatomy of a system-auth stack (typical example)](#anatomy-of-a-system-auth-stack-typical-example)
  - [Detailed line-by-line explanation](#detailed-line-by-line-explanation)
    - [`auth required pam_env.so`](#auth-required-pam_envso)
    - [`auth required pam_faillock.so preauth silent audit deny=3 unlock_time=900`](#auth-required-pam_faillockso-preauth-silent-audit-deny3-unlock_time900)
    - [`auth sufficient pam_unix.so try_first_pass nullok`](#auth-sufficient-pam_unixso-try_first_pass-nullok)
    - [`auth sufficient pam_sss.so use_first_pass`](#auth-sufficient-pam_sssso-use_first_pass)
    - [`auth required pam_faillock.so authsucc audit deny=3 unlock_time=900`](#auth-required-pam_faillockso-authsucc-audit-deny3-unlock_time900)
    - [`auth required pam_deny.so`](#auth-required-pam_denyso)
    - [`account required pam_unix.so`](#account-required-pam_unixso)
    - [`account [default=bad success=ok user_unknown=ignore] pam_sss.so`](#account-defaultbad-successok-user_unknownignore-pam_sssso)
    - [`account required pam_permit.so`](#account-required-pam_permitso)
    - [`password requisite pam_pwquality.so ...`](#password-requisite-pam_pwqualityso-)
    - [`password sufficient pam_sss.so use_authtok`](#password-sufficient-pam_sssso-use_authtok)
    - [`session optional pam_keyinit.so revoke`](#session-optional-pam_keyinitso-revoke)
    - [`session required pam_limits.so`](#session-required-pam_limitsso)
    - [`session required pam_mkhomedir.so skel=/etc/skel/ umask=0077`](#session-required-pam_mkhomedirso-skeletcskel-umask0077)
    - [`session optional pam_sss.so`](#session-optional-pam_sssso)
  - [Authselect and system-auth](#authselect-and-system-auth)
  - [Editing safely: step-by-step](#editing-safely-step-by-step)
  - [Debugging and logs](#debugging-and-logs)
  - [Common real-world scenarios and exact fixes](#common-real-world-scenarios-and-exact-fixes)
    - [Scenario: AD users can't login but `id` shows the user](#scenario-ad-users-cant-login-but-id-shows-the-user)
    - [Scenario: Local users cannot login after a change](#scenario-local-users-cannot-login-after-a-change)
    - [Scenario: Too many auth failures -\> everyone locked](#scenario-too-many-auth-failures---everyone-locked)
    - [Scenario: Home directory not created for AD users](#scenario-home-directory-not-created-for-ad-users)
  - [Quick test checklist after edits](#quick-test-checklist-after-edits)
  - [Reverting changes automatically using a safe edit script (example)](#reverting-changes-automatically-using-a-safe-edit-script-example)
  - [Final notes and best practices](#final-notes-and-best-practices)
  - [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

## What `system-auth` is and why it exists

- `system-auth` is a shared PAM configuration fragment. Many PAM-aware services include it to avoid duplicating the auth/account/password/session policy in every service file. `/etc/pam.d/sshd`, `/etc/pam.d/login`, and others include `@include system-auth` or have configurations that rely on the same rules. Changing `system-auth` therefore affects many services at once. That makes it powerful but risky.

- On modern RHEL-based systems, `authselect` may be used to manage PAM and NSS configurations. If `authselect` is in use, edit policies using `authselect` rather than editing system-auth directly unless you know how to persist the changes.

---

<br>
<br>

## Always take a backup before editing

Do this first every time:

```bash
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak-$(date +%F-%T)
```

If using `authselect` (RHEL8/Rocky8+):
```bash
authselect current
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.authselect-backup
```

If something breaks, restore the backup and restart services.

---

<br>
<br>

## Anatomy of a system-auth stack (typical example)

A typical, sensible `system-auth` for AD+SSSD looks like this (simplified):

```bash
# auth phase
auth        required      pam_env.so
auth        required      pam_faillock.so preauth silent audit deny=3 unlock_time=900
auth        sufficient    pam_unix.so try_first_pass nullok
auth        sufficient    pam_sss.so use_first_pass
auth        required      pam_faillock.so authsucc audit deny=3 unlock_time=900
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
session     required      pam_mkhomedir.so skel=/etc/skel/ umask=0077
session     optional      pam_sss.so
```

I will explain each line and why it is in that position.

---

<br>
<br>

## Detailed line-by-line explanation

### `auth required pam_env.so`
Loads environment variables from `/etc/security/pam_env.conf` and the user environment. Not critical, but helps set PATH and locale correctly for the session.

If removed, login still works but environment variables might not load.

### `auth required pam_faillock.so preauth silent audit deny=3 unlock_time=900`
Pre-auth step for the faillock module. It checks whether the account is already locked (before authentication) and maintains counters. `deny=3` means lock after 3 failed attempts, `unlock_time=900` means auto-unlock after 15 minutes. `silent` reduces noisy messages.

If you do not want lockouts, remove or adjust this line, but be aware of brute-force risk.

### `auth sufficient pam_unix.so try_first_pass nullok`
Local authentication using `/etc/shadow`. `sufficient` here means: if local auth succeeds, stop and treat the auth phase as successful. `try_first_pass` tries the password from previous module; `nullok` allows empty passwords if present in shadow (you usually avoid nullok in production).

If you place this after `pam_sss.so`, local users will be forced through SSSD unnecessarily. Order matters.

### `auth sufficient pam_sss.so use_first_pass`
This calls SSSD to authenticate AD users. `sufficient` makes SSSD success short-circuit the stack. `use_first_pass` uses the password already read by PAM (from tty or SSH) instead of prompting again.

If this line is missing, AD users will not authenticate.

### `auth required pam_faillock.so authsucc audit deny=3 unlock_time=900`
Records successful auth attempts and updates counters. This is part of the correct faillock placement to ensure lock counters reset on success.

### `auth required pam_deny.so`
Final safety net. It always fails and should be last. If placed earlier, it will deny every login.

### `account required pam_unix.so`
Account checks for local accounts (expiration, disabled status local side).

### `account [default=bad success=ok user_unknown=ignore] pam_sss.so`
Account checks via SSSD for AD accounts. The control flag here means: if the user is unknown to SSSD, ignore and let local account processing continue; if AD says bad (e.g., disabled), fail.

If you misconfigure this, AD accounts may be incorrectly treated as unknown or denied.

### `account required pam_permit.so`
This permissive line ensures the account chain does not block legitimate local system accounts. It is safe but optional depending on your stacking.

### `password requisite pam_pwquality.so ...`
Enforces password complexity. Only used on password change operations (passwd). If you use AD password change via SSSD, this still runs locally for local accounts.

If misconfigured, `passwd` can fail or prevent password changes.

### `password sufficient pam_sss.so use_authtok`
Allow password changes against AD through SSSD. `use_authtok` uses the existing auth token.

If this is missing, changing AD passwords from Linux may fail.

### `session optional pam_keyinit.so revoke`
Initializes kernel keyring; useful for cryptographic operations. Optional.

### `session required pam_limits.so`
Applies resource limits from `/etc/security/limits.conf`. Required for session resource control.

### `session required pam_mkhomedir.so skel=/etc/skel/ umask=0077`
Creates a home directory on first login if it doesn’t exist. For AD users, this often avoids login failures and missing HOME issues. If you prefer `oddjob-mkhomedir`, then PAM might call `pam_oddjob_mkhomedir.so` instead. `authselect` often configures oddjob-based home dir creation.

### `session optional pam_sss.so`
Session hooks for SSSD. Optional but helpful for SSSD-related session tasks.

---

<br>
<br>

## Authselect and system-auth

On Rocky/RHEL 8+, `authselect` manages the PAM policy. If you run `authselect apply-changes` or `authselect select` later, it can overwrite manual edits. Recommended flow:

- Use `authselect select sssd` to enable SSSD-managed PAM/NSS configs.
- To apply a one-off manual change, copy the profile and apply a custom profile:

```bash
authselect create-profile my-pam-profile --base-on sssd
# Edit files under /etc/authselect/custom/my-pam-profile/...
authselect apply-changes -b my-pam-profile
```

If you are not using `authselect`, you may edit `/etc/pam.d/system-auth` directly — but always back up first.

---

<br>
<br>

## Editing safely: step-by-step

1. Backup:
```bash
cp /etc/pam.d/system-auth /root/system-auth.back
```

2. Test config syntax: PAM has no syntax checker. The safe way is to open a new root session before applying changes and keep an existing root session open. That way, if SSH fails, you still have a working root shell.

3. Make minimal edits; prefer adding optional lines rather than removing lines.

4. If you must remove lines, comment them first by adding a `#` and test.

5. After editing, attempt a non-root test login from a local console or separate SSH client.

6. If you lock yourself out of SSH, use the open root console, restore backup, and restart `sshd`.

Restore example:
```bash
cp /root/system-auth.back /etc/pam.d/system-auth
systemctl restart sshd
```

---

<br>
<br>

## Debugging and logs

PAM-related messages go to `/var/log/secure` (and sometimes `/var/log/auth.log` on other distros). Use the following workflow:

1. Tail secure:
```bash
tail -f /var/log/secure
```
2. Try logging in as a test user (su - or ssh from a different client)
3. Observe PAM messages and SSSD outputs simultaneously:
```bash
tail -f /var/log/sssd/sssd_pam.log /var/log/secure
```

Common messages:
- `pam_unix(sshd:auth): authentication failure` → local password issue
- `pam_sss(sshd:auth): Authentication failure` → SSSD/Kerberos issue
- `pam_faillock` messages → account locked due to repeated failures

---

<br>
<br>

## Common real-world scenarios and exact fixes

### Scenario: AD users can't login but `id` shows the user
Symptoms: `id testuser1` returns user, but `ssh testuser1@host` fails.
Fix:
1. Check `/etc/pam.d/system-auth` contains `pam_sss.so` in the auth and account phases.
2. `tail -f /var/log/sssd/sssd_pam.log` while attempting login.
3. If logs show Kerberos errors, `kinit testuser1` to validate Kerberos.

### Scenario: Local users cannot login after a change
Symptoms: local accounts fail but AD users succeed.
Fix:
1. Verify `pam_unix.so` is present and `sufficient` is before `pam_deny.so`.
2. Restore from backup if needed.

### Scenario: Too many auth failures -> everyone locked
Symptoms: All users report `Account locked` or `Authentication failure` after a few attempts.
Fix:
1. Reset faillock counters for relevant users:
```bash
faillock --user testuser1 --reset
```
2. Re-evaluate `pam_faillock` options; consider increasing `deny` or adding `even_deny_root` carefully.

### Scenario: Home directory not created for AD users
Symptoms: Login fails with `Could not chdir to home directory: No such file or directory` or login succeeds but no home dir.
Fix:
1. Ensure `pam_mkhomedir.so` or `pam_oddjob_mkhomedir.so` is in the session phase.
2. Ensure `oddjobd` is running if using `pam_oddjob_mkhomedir.so`:
```bash
systemctl enable --now oddjobd
```

---

<br>
<br>

## Quick test checklist after edits

1. `rpm -q sssd realmd oddjob oddjob-mkhomedir` (confirm packages)
2. `systemctl is-active sssd` (sssd should be running)
3. `grep sss /etc/pam.d/system-auth` (ensure pam_sss lines exist)
4. `id testuser1` (NSS identity)
5. `kinit testuser1` and `klist` (Kerberos)
6. `su - testuser1` (PAM and session)
7. `ssh testuser1@host` (end-to-end)
8. Watch logs: `/var/log/secure` and `/var/log/sssd/sssd_pam.log`

---

<br>
<br>

## Reverting changes automatically using a safe edit script (example)

If you prefer a safe-edit wrapper that restores a backup if authtest fails, use this pattern locally (run as root in a console):

```bash
#!/bin/bash
set -e
BACKUP=/root/system-auth.back.$(date +%F-%T)
cp /etc/pam.d/system-auth $BACKUP
# copy new content into /etc/pam.d/system-auth.new first, then move into place
mv /etc/pam.d/system-auth.new /etc/pam.d/system-auth
sleep 1
# quick test: open a new SSH connection (script assumes you have a separate console)
# If your environment cannot do that, skip automatic revert and test manually
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 root@localhost true; then
  echo "New PAM config failed, restoring backup"
  cp $BACKUP /etc/pam.d/system-auth
  systemctl restart sshd
  exit 1
fi

# If test passes, keep changes
systemctl restart sshd
```

This script is only an example — test it in your lab and adapt.

---

<br>
<br>

## Final notes and best practices

- Never edit `system-auth` on a production server without an open root console. Always keep an active root session.
- Prefer `authselect` on systems that use it; create custom profiles rather than editing the distributed profile directly.
- Keep `pam_deny.so` as the last `auth` module.
- Keep `pam_unix.so` and `pam_sss.so` ordered so that both local and AD users work as expected.
- Use `pam_faillock` to defend against brute-force attacks, but tune thresholds carefully.
- Use `pam_mkhomedir` or `pam_oddjob_mkhomedir` to avoid home-directory issues for AD users.

---

<br>
<br>

## What you achieve after this file

After reading and applying this file, you will be able to:
- safely edit `/etc/pam.d/system-auth`
- understand every major module and control flag used in AD+SSSD setups
- debug authentication failures with real commands and logs
- recover from mistakes and restore access quickly

This is the definitive, practical `system-auth` guide for your AD integration work.