# password-policy.md

This file explains how to design, configure, enforce, test, and troubleshoot password policies on Linux systems in a practical, production-ready way. Focus is on real commands, exact file locations, and how local Linux policies interact with Active Directory (AD) when SSSD is used. No theory-only sections — this is a hands-on handbook.

You will learn:
- what files and modules control password policy on Linux
- how to enforce complexity, history, expiration, and lockout
- differences between local and AD-managed password policies
- exact configuration lines for `pam_pwquality`, `pam_pwhistory`, `pam_unix`, `pam_faillock`, and `pam_tally2`
- how to test policies safely and how to recover

---

# 1. Where password policy lives on Linux

Password policy is implemented across multiple layers. There is no single file that "is the policy". The main pieces are:

- `/etc/login.defs` — high-level defaults for password aging (PASS_MAX_DAYS, PASS_MIN_DAYS, PASS_WARN_AGE)
- `/etc/security/pwquality.conf` — settings for `pam_pwquality.so` (complexity rules, dictionary checks)
- PAM stacks (`/etc/pam.d/system-auth`, `/etc/pam.d/password-auth`) — modules called during AUTH and PASSWORD phases, e.g. `pam_pwquality.so`, `pam_unix.so`, `pam_pwhistory.so`.
- `/etc/shadow` — stores password hashes and expiration fields per user
- `pam_faillock.so` or `pam_tally2` — account lockout modules for repeated failed attempts
- SSSD/AD — when using AD, password complexity, history, and expiration are often enforced by AD GPOs; Linux should not duplicate conflicting rules but may enforce local controls for local accounts

Keep in mind: PAM is the glue. The modules invoked in PAM decide which policies are enforced and when.

---

# 2. Password hashing and storage

Linux stores password hashes in `/etc/shadow`. Modern systems use `SHA-512` by default. The algorithm is controlled by `/etc/login.defs` or `authconfig` on RHEL-derived systems.

Check current hashing method:
```
grep -i "ENCRYPT_METHOD" /etc/sysconfig/authconfig 2>/dev/null || true
# or check libuser config
authconfig --test | grep hashing
```

To enforce SHA-512 hashing (RHEL/Rocky):
```
authconfig --passalgo=sha512 --update
```

Do not use old hashes (md5/crypt) in production.

---

# 3. Complexity rules with pam_pwquality

`pam_pwquality.so` enforces complexity and dictionary checks. Configuration lives in `/etc/security/pwquality.conf`.

A practical, secure example `/etc/security/pwquality.conf`:

```
# /etc/security/pwquality.conf
minlen = 12
dcredit = -1    # require at least 1 digit
ucredit = -1    # require at least 1 uppercase
lcredit = -1    # require at least 1 lowercase
ocredit = -1    # require at least 1 special char
minclass = 4    # require characters from 4 classes (digit, upper, lower, special)
maxrepeat = 3
dictcheck = 1
usercheck = 1
enforcing = 1
```

Put `pam_pwquality.so` into the password phase of your PAM stack (usually in `system-auth` and `password-auth`):

```
# /etc/pam.d/system-auth  (password section)
password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password    required      pam_deny.so
```

Notes:
- `local_users_only` makes the complexity checks apply only to local users; AD users are validated by AD policy.
- `try_first_pass` makes modules use the password already entered by the user so the stack is consistent.
- `use_authtok` in `pam_unix` ensures password-change operations pass the new password from earlier modules.

---

# 4. Password history (prevent reuse)

`pam_pwhistory.so` enforces history so users cannot reuse the last N passwords.

Example PAM lines to enforce history of 10 passwords:

```
# /etc/pam.d/system-auth (password section)
password required pam_pwhistory.so remember=10 enforce_for_root use_authtok
```

Important:
- `pam_pwhistory` works with `pam_unix` and `pam_unix` must actually store the password history. Ensure your system supports this (modern glibc and shadow utilities do).
- For AD users, history is controlled by AD and Linux `pam_pwhistory` will not affect AD-managed accounts if `local_users_only` is set.

---

# 5. Password aging (expiration) with `/etc/login.defs` and `chage`

Long-term password rotation is handled by `/etc/login.defs` defaults and per-user values in `/etc/shadow`.

Key fields in `/etc/login.defs`:
```
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
```

To set expiration for a user:
```
chage -M 90 -m 1 -W 14 username
```
Check user values:
```
chage -l username
```
Or inspect `/etc/shadow` fields (last change, min, max, warn):
```
grep "^username:" /etc/shadow | cut -d: -f3-8
```

For AD users, password expiration is typically controlled by AD GPO. SSSD will show `password_expires` attributes but changing AD-managed expiry from Linux is not recommended without coordination.

---

# 6. Account lockout on failed attempts

Use `pam_faillock.so` (RHEL/CentOS/Rocky modern approach) to lock accounts after consecutive failed attempts.

Example lines to add to `system-auth` and `password-auth` near the top of the `auth` section:

```
# preauth
auth        required      pam_faillock.so preauth silent deny=5 unlock_time=900 fail_interval=900
# after auth modules
auth        [default=die] pam_faillock.so authfail deny=5 unlock_time=900 fail_interval=900
# in account section to reset
account     required      pam_faillock.so
```

Behavior:
- after 5 failed attempts, account locked for 900 seconds (15 minutes)
- `fail_interval` determines the window for counting failures

Testing:
```
# try 5 failed password attempts for the user via SSH or pamtester
faillock --user username     # shows failed attempts
faillock --user username --reset   # reset failures
```

If using AD users, decide whether to use AD lockout policies (recommended) or local faillock. Mixing both is confusing; prefer centralizing lockout in AD when AD accounts are primary.

---

# 7. Legacy `pam_tally2` and `pam_tally` (avoid if possible)

`pam_tally2` is older and replaced by `pam_faillock`. Only use if you maintain older systems. Configuration and commands differ (`pam_tally2 --user username`) but the concept is identical.

---

# 8. Force password change at next login

To require a user to change password on next login:
```
chage -d 0 username   # forces password change at next login
passwd --expire username   # alternative
```
For AD users, use AD tools to set `pwdLastSet` to 0 or require change at next logon in AD.

---

# 9. Interaction with Active Directory (SSSD)

When the system is joined to AD via SSSD/realmd, password policy can be enforced in two places:

1. AD side (recommended): AD Group Policy Objects (GPO) control password complexity, history, lockout, and expiration. These are authoritative for AD accounts.
2. Linux side: `pam_pwquality`, `pam_pwhistory`, `pam_faillock` — these affect local accounts. For AD users, use `local_users_only` in pwquality to avoid conflicting policies.

Best practice:
- Let AD enforce password complexity/history/lockout for AD-managed accounts. Configure Linux modules to apply to local accounts only, or to act as a secondary safeguard for local accounts.
- Do NOT try to duplicate complex AD rules in local PAM for AD accounts — keep the source of truth single.

Testing AD password changes:
```
# change AD user password from Linux (if allowed)
passwd aduser@domain
# or use kpasswd for Kerberos
kpasswd aduser@domain
```
If password change fails, check SSSD logs and AD rights.

---

# 10. Password policy enforcement examples (complete PAM snippets)

## Example A — Enforce policy for local users, AD controls AD users

```
# /etc/pam.d/system-auth (password section)
password requisite pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password required pam_pwhistory.so remember=10 enforce_for_root
password sufficient pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password required pam_deny.so
```

## Example B — Enforce strict policy for all users (not recommended with AD)

```
password requisite pam_pwquality.so try_first_pass retry=3 authtok_type=
password required pam_pwhistory.so remember=10 enforce_for_root use_authtok
password sufficient pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password required pam_deny.so
```

Only use Example B in environments without AD or where Linux is authoritative for passwords.

---

# 11. Testing password policy safely

1. Keep a root session or console open to recover.
2. Create a test user for experiments:
```
useradd -m -s /bin/bash testpolicy
passwd testpolicy
```
3. Test complexity enforcement:
```
# attempt weak password
passwd testpolicy    # enter weak password and observe rejection
```
4. Test history:
```
passwd testpolicy    # change several times and ensure old password reuse rejected
```
5. Test lockout:
```
# simulate repeated failures via pamtester or ssh attempts
pamtester login testpolicy authenticate   # use wrong password multiple times
faillock --user testpolicy
```
6. Test expiration:
```
chage -d 0 testpolicy   # force change at next login
```
7. For AD users, test changes via `kpasswd` and monitor `/var/log/sssd/sssd_pam.log`.

---

# 12. Recovery and rollback

If you lock yourself out or break password changes:

1. Use VM console or alternate root session to log in.
2. Revert PAM changes from backup:
```
cp /root/system-auth.bak /etc/pam.d/system-auth
cp /root/password-auth.bak /etc/pam.d/password-auth
```
3. Reset failure counters:
```
faillock --user username --reset
pam_tally2 --user username --reset   # if using pam_tally2
```
4. Unlock root if necessary:
```
passwd -u root
```

---

# 13. Auditing and logging

Track password events with:
```
/var/log/secure
/var/log/auth.log (Debian/Ubuntu)
/var/log/sssd/sssd_pam.log
```
Log events to centralized SIEM for alerts on repeated failures or mass password-change events. Use `auditd` rules if you need to capture `passwd` executions specifically:

```
# /etc/audit/rules.d/password.rules
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/passwd -k password-change
-a always,exit -F arch=b32 -S execve -F path=/usr/bin/passwd -k password-change
```
Reload rules and test.

---

# 14. Additional hardening tips

- Ensure `pam_pwquality` uses a dictionary for `dictcheck` to block common words. Install `cracklib` or `libpwquality`. Configure `dictpath` in `/etc/security/pwquality.conf` if necessary.
- Do not allow empty passwords. `nullok` in `pam_unix` should be avoided in production.
- Use `PASS_MIN_DAYS` to prevent immediate password reuse after change.
- Consider using FIDO2 / hardware tokens for passwordless or second-factor authentication.
- When integrating with AD, document which policies are defined in AD vs on Linux to avoid operational confusion.

---

# What you achieve after this file

You will have a complete, practical understanding of how Linux password policy works, how to configure and enforce complexity, history, expiration, and lockout, and how these policies interact with Active Directory via SSSD. You will be able to design policies for local and AD-managed accounts, test them safely in your VMware lab, and recover from mistakes quickly.

This is the operational guide you will use when hardening authentication on Linux systems.
