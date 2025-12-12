# pam-configs.md

This file is a complete, practical, go-to guide for **PAM configuration on Linux**. It explains every common PAM file you will touch (`system-auth`, `password-auth`, `sshd`, `su`, `sudo`, `login`, etc.), how control flags work, the meaning and impact of each phase (auth, account, password, session), where to place modules, exact examples, and recovery steps. This is written for someone who will edit PAM in production — clear, direct, and drill-down practical.

You will learn:
- the role of each PAM configuration file and when a service reads it
- the four PAM phases and how modules behave in each
- control flags and how to use them safely (`required`, `requisite`, `sufficient`, `optional`, and advanced control syntax)
- where to put `pam_sss`, `pam_unix`, `pam_faillock`, `pam_pwquality`, `pam_limits`, `pam_mkhomedir`, `pam_succeed_if`, `pam_deny`, and others
- safe editing practices and rollback
- debugging commands and exact log locations
- real-world examples for AD-integrated systems with SSSD

No vague theory. Everything here is actionable.

---

# 1. PAM basics — four phases and what they do

PAM modules are executed in four distinct phases:

`auth` — verify who you are (password, key prompts, 2FA). This is where authentication modules run.

`account` — check account status and policies (expiry, disabled flag, access filters). These modules do not prompt for secrets.

`password` — used when changing passwords (passwd), not during normal authentication.

`session` — run after successful authentication to set up or tear down session state (create home dir, apply limits, initialize keys).

Each service (sshd, login, su, sudo) calls its PAM file; those files often `include` or `substack` common shared files like `system-auth` or `password-auth` so you get consistent behavior across services.

---

# 2. Key PAM configuration files and when they are read

- `/etc/pam.d/sshd` — SSH server. This is the entry point for remote logins.
- `/etc/pam.d/login` — console login.
- `/etc/pam.d/su` — `su` command.
- `/etc/pam.d/sudo` — `sudo` command (may vary by distro).
- `/etc/pam.d/password-auth` — used by many services on RHEL-derived systems as the stack for remote logins; often includes `system-auth`.
- `/etc/pam.d/system-auth` — the global shared stack. Broken `system-auth` breaks many services.
- `/etc/pam.d/common-auth`, `/etc/pam.d/common-account`, etc. — Debian/Ubuntu style equivalents.

When editing PAM for SSH, always start with `/etc/pam.d/sshd` and follow includes to `password-auth` and `system-auth` so you understand the full stack.

---

# 3. Control flags — how modules influence the result

There are five standard control flags with simple semantics and additional advanced syntax.

`required` — module must succeed; even if it fails, PAM continues to run other modules, but the overall result will be failure when the stack finishes. Use for mandatory checks you still want to record before denying.

`requisite` — like `required`, but if it fails, PAM stops immediately and returns failure. Use for fast fail (e.g., a critical early validation you don't want to proceed after).

`sufficient` — if this module succeeds and no previous `required` failed, PAM immediately returns success for the stack. Use for shortcuts (e.g., local password auth that should win quickly).

`optional` — module result is ignored unless no other module granted success. Generally avoid reliance on optional modules for critical checks.

Advanced control syntax (vector form):
```
[success=1 default=ignore] pam_succeed_if.so user ingroup wheel
```
This means: if module returns success, skip one next rule; otherwise ignore and continue. This gives precise flow control and is used heavily in distributions.

Mistakes with control flags are the most common cause of broken PAM. `pam_deny.so` should usually be last with `required` to ensure everything else had a chance.

---

# 4. Recommended order of modules in `system-auth` for AD+SSSD setups

Order matters. This is a production-proven layout you can adapt safely.

```
# AUTH phase
auth    required      pam_env.so
auth    required      pam_faillock.so preauth silent audit deny=5 unlock_time=900
auth    sufficient    pam_unix.so try_first_pass nullok
auth    sufficient    pam_sss.so use_first_pass
auth    required      pam_faillock.so authfail deny=5 unlock_time=900
auth    required      pam_deny.so

# ACCOUNT phase
account required      pam_unix.so
account [default=bad success=ok user_unknown=ignore] pam_sss.so
account required      pam_permit.so

# PASSWORD phase
password requisite   pam_pwquality.so try_first_pass local_users_only retry=3
password sufficient  pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password sufficient  pam_sss.so use_authtok
password required    pam_deny.so

# SESSION phase
session required     pam_limits.so
session required     pam_mkhomedir.so skel=/etc/skel umask=0077
session optional     pam_sss.so
session required     pam_unix.so
```

Notes:
- `pam_env` first so environment is available to other modules.
- `pam_faillock` preauth must run before auth attempt; authfail after password modules increments counters.
- `pam_unix` tries local accounts first (sufficient), then `pam_sss` for AD users.
- `pam_deny` at end guarantees failure if nothing succeeded.
- `local_users_only` in `pam_pwquality` avoids conflicting with AD password policy.

Always backup files before changes.

---

# 5. Common PAM modules and exact usage

`pam_env.so` — sets environment variables early. Place at top of auth. If missing, some modules may not see expected env values.

`pam_faillock.so` — account lockout. Must be in preauth and post-auth positions. Use `local_users_only` for AD+local mixed environments.

`pam_unix.so` — classic local password auth (shadow). Use `sufficient` before `pam_sss` to allow local accounts to win quickly.

`pam_sss.so` — SSSD connector. Place as `sufficient` in auth, account, password, and session where needed.

`pam_pwquality.so` — password complexity. Put in password phase, typically with `local_users_only` when AD manages domain accounts.

`pam_pwhistory.so` — prevents password reuse. Use in password phase with `remember` option.

`pam_limits.so` — applies ulimits; place in session phase as `required`.

`pam_mkhomedir.so` — creates home directories on first login; session required in AD environments.

`pam_succeed_if.so` — conditional tests (uid, user in group). Used for allow/deny rules and to skip other modules based on conditions.

`pam_deny.so` — explicit deny; normally placed at the end of auth to fail if no module succeeded.

`pam_permit.so` — always permits; rarely used except in account phase as a pass-through.

`pam_ssh.so`, `pam_krb5.so`, `pam_otp.so` — used for SSH key handling, Kerberos, and MFA where needed.

`pam_exec.so` — run scripts during PAM flow (be careful, runs as root and can break logins).

---

# 6. Safe editing strategy and rollback

1. Always open a root remote session and keep it active while you edit. Do not log out until you confirm you can SSH again from a second terminal.
2. Make a backup with timestamp:
```
cp /etc/pam.d/system-auth /root/system-auth.bak-$(date +%F-%T)
```
3. Edit the file and save. Avoid complex sed scripts — hand-edit carefully.
4. Test immediately from another SSH connection. If locked out, use VM console to restore:
```
cp /root/system-auth.bak-* /etc/pam.d/system-auth
systemctl restart sshd
```
5. For mass deploys, test on a single host first and automate with careful templating.

A common safety trick: add `auth sufficient pam_permit.so` to the top while iterating, then remove it when finished. But this effectively disables auth and is dangerous — prefer keeping an open root session instead.

---

# 7. Debugging PAM problems — exact commands and logs

Logs:
- `/var/log/secure` (RHEL/CentOS/rocky)
- `/var/log/auth.log` (Debian/Ubuntu)
- `/var/log/sssd/*.log` for SSSD-related issues
- `journalctl -u sshd -f` for live sshd messages

Commands:
```
grep -i pam /var/log/secure | tail -n 100
tail -f /var/log/secure /var/log/sssd/sssd_pam.log
pamtester sshd username authenticate   # test PAM stack directly
faillock --user username
sssctl domain-status
sssctl user-show username
```
`pamtester` is invaluable because it exercises PAM without going through SSH and shows module-level failures.

If you see `pam_unix(sshd:auth): authentication failure` followed by `pam_sss(sshd:auth): authentication failure` and `Permission denied`, identify which module returned the decisive failure by checking logs and order.

---

# 8. Examples: common real-world scenarios and fixes

### Scenario: Local users cannot SSH, AD users can
Cause: `pam_unix.so` removed or misconfigured. Fix by restoring `pam_unix.so try_first_pass nullok` as `sufficient` before `pam_sss`.

### Scenario: AD users cannot SSH, local users can
Cause: `pam_sss.so` missing or not called. Check `password-auth` and `system-auth` includes. Ensure `pam_sss` present in auth and account phases.

### Scenario: Everyone locked out after quick edit
Fix: Use VM console to restore backup. Then test edits using a second session and smaller incremental changes.

### Scenario: Home directories not created for AD users
Cause: `pam_mkhomedir.so` missing or oddjobd not running. Fix: add `session required pam_mkhomedir.so skel=/etc/skel umask=0077` and `systemctl enable --now oddjobd`.

---

# 9. Advanced control examples

Skip next rule when condition is met (used for group-based allow):
```
# if user in wheel, skip next module
auth [success=1 default=ignore] pam_succeed_if.so user ingroup wheel
```
Use `pam_succeed_if` combined with `pam_deny` to build allow lists or deny lists at the host level.

Use `[default=bad success=ok user_unknown=ignore] pam_sss.so` control in account phase to treat unknown users differently from bad accounts.

---

# 10. PAM and services other than SSH

PAM controls `su`, `sudo`, graphical logins, cron, vsftpd, FTP, Postfix SASL, and more. When changing shared stacks like `system-auth`, test those services as well. For example, if sudo stops working after changes, the issue is often in `account` or `session` sections.

Remember: `su` uses `/etc/pam.d/su`, not `/etc/pam.d/sshd`. If su fails while SSH works, inspect `su` PAM file.

---

# 11. Final checklist before committing PAM changes

1. Backup all PAM files you will edit.  
2. Keep an active root session open.  
3. Make minimal changes and test immediately from another connection.  
4. Use `pamtester` to simulate authentication without SSH.  
5. Monitor logs in real time.  
6. If you deploy to multiple servers, test on one first.  
7. Document changes and how to revert.

---

# What you achieve after this file

You now have a practical, no-nonsense handbook to modify, test, and maintain PAM configuration safely. You know which files to edit, how control flags work, where common failures occur, and how to recover from mistakes. This document prepares you to manage PAM in real lab and production environments without guesswork.