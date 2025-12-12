# lockout-policy.md

This file covers **Linux account lockout policy** in a fully practical, production-ready way.  
You will learn exactly how to implement and test login lockouts using:
- pam_faillock (modern RHEL/Rocky-based systems)
- pam_tally2 (legacy)
- SSSD + AD lockout interaction
- SSH-specific lockout behavior
- all failure scenarios and safe recovery procedures

No shallow explanations — these are the real configurations you will use.

---

# 1. Why lockout policy matters

A lockout policy protects systems against:
- brute-force password guessing
- credential stuffing attempts
- misuse of shared accounts
- repeated attempts on stale or compromised credentials

Without lockout, attackers can hammer SSH indefinitely.  
With lockout, the account becomes inaccessible after N failed attempts for a set duration.

---

# 2. Modern lockout mechanism: pam_faillock

`pam_faillock.so` is now the standard for account lockout in RHEL/Rocky/CentOS systems.
It tracks failed login attempts in `/var/log/faillock/` per user.

You must modify **two PAM stacks**:
- `/etc/pam.d/system-auth`
- `/etc/pam.d/password-auth`

These stacks apply to local console, SSH, sudo, SU, and other PAM-authenticated services.

---

# 3. Recommended lockout configuration (secure & safe)

Add these lines **near the top** of both `/etc/pam.d/system-auth` and `/etc/pam.d/password-auth`:

```
# deny after 5 failed attempts within 15 minutes
# reset after 15 minutes

auth        required       pam_faillock.so preauth silent deny=5 unlock_time=900 fail_interval=900
```

Add this line **after all pam_unix/auth modules**:

```
auth        [default=die]  pam_faillock.so authfail deny=5 unlock_time=900 fail_interval=900
```

Add this line in the **account section** to reset counters on successful login:

```
account     required       pam_faillock.so
```

### Meaning of parameters
- **deny=5** → lock user after 5 failed attempts
- **unlock_time=900** → auto-unlock after 900 seconds (15 minutes)
- **fail_interval=900** → failures counted within a 15-minute window

---

# 4. Testing lockout safely

Create a test user:
```
useradd -m locktest
passwd locktest
```

Try wrong passwords 5 times:
```
ssh locktest@server   # enter incorrect passwords repeatedly
```

Check lockout status:
```
faillock --user locktest
```
Should show something like:
```
locktime = 900
failcnt = 5
```

Reset lock manually:
```
faillock --user locktest --reset
```

Try again:
```
ssh locktest@server
```
User should now authenticate normally.

---

# 5. Lockout event locations

Failed attempts recorded in:
- `/var/log/secure` (or `/var/log/auth.log` depending on distro)
- `/var/log/faillock/USERNAME`
- SSSD logs if AD users are involved

Example log entry in `/var/log/secure`:
```
pam_faillock(sshd:auth): Consecutive authentication failures for user locktest account temporarily locked
```

---

# 6. Lockout and SSH — important behavior

SSH authentication attempts count against faillock, including:
- password auth
- keyboard-interactive

But **public key authentication does NOT count** toward lockout, because pam_unix/pam_faillock are not invoked until password prompt.

If your users use SSH keys, lockout will not help block brute-force attempts — instead use Fail2ban or SSH rate limits.

---

# 7. Interaction with Active Directory (critical)

When Linux is joined to AD via SSSD:

### AD users can be locked out in two different places:
1. **Local faillock** (Linux-based lockout)
2. **AD domain lockout policy** (GPO-enforced)

This leads to confusion if both are active.

### Best practice
- Let **AD** enforce password lockout for AD accounts
- Let **Linux faillock** enforce lockout for **local accounts only**

To enforce faillock only for local users:
```
auth required pam_faillock.so preauth silent deny=5 unlock_time=900 fail_interval=900 local_users_only
```

Test with AD user:
```
faillock --user aduser@GOHEL.LOCAL
```
If local logging shows no file → faillock not applied (correct).

AD lockout status must be checked via:
```
Get-ADUser -Identity username -Properties LockedOut
```

---

# 8. Permanent lockout (until manually cleared)

Set `unlock_time = 0` for manual unlock only:

```
auth required pam_faillock.so preauth silent deny=5 unlock_time=0 fail_interval=900
```

Manual unlock required:
```
faillock --user username --reset
```

Use this only for high-security systems.

---

# 9. Lockout warnings to users

If you want to show warnings during authentication attempts, remove `silent` from the preauth line:

```
auth required pam_faillock.so preauth deny=5 unlock_time=900 fail_interval=900
```

User will see:
```
Authentication failure. Account will be locked soon.
```

---

# 10. legacy lockout: pam_tally2 (avoid unless forced)

Older systems use `pam_tally2`.

Check if available:
```
pam_tally2 --user username
```

Example configuration:
```
auth required pam_tally2.so deny=5 lock_time=900 onerr=fail audit
account required pam_tally2.so
```

Reset tally:
```
pam_tally2 --user username --reset
```

Only use for legacy compatibility.

---

# 11. Common failure scenarios and fixes

### 1. Lockout not working at all
Check PAM ordering. pam_faillock must appear *before* pam_unix.
```
grep -R "faillock" /etc/pam.d
```

### 2. AD users get locked locally even with AD lockout configured
You forgot `local_users_only`. Add it.

### 3. User remains locked even after unlock_time expires
System clock issues. Check:
```
timedatectl status
```
Fix NTP if needed.

### 4. sudo also gets locked unexpectedly
sudo uses the same PAM stack.  
If you don't want sudo failures counted, add:
```
# in /etc/pam.d/sudo
auth [success=1 default=ignore] pam_faillock.so deny=5 unlock_time=900 fail_interval=900
```

### 5. After enabling lockout, nobody can login
Recovery:
1. Use VMware console
2. Remove faillock lines from `/etc/pam.d/*`
3. Run:
```
faillock --user root --reset
faillock --user YOURUSER --reset
```

---

# 12. Monitoring lockouts

Show all locked users:
```
faillock --all
```

List metadata for a specific user:
```
faillock --user username
```

Add audit logging:
```
auditctl -w /var/log/faillock -p wa -k faillock
```

---

# 13. Recommended secure configuration (final)

Enable faillock for local users with safe defaults:

```
auth required pam_faillock.so preauth silent deny=5 unlock_time=900 fail_interval=900 local_users_only
auth [default=die] pam_faillock.so authfail deny=5 unlock_time=900 fail_interval=900 local_users_only
account required pam_faillock.so
```

Combine with AD lockout for domain accounts.

---

# 14. What you achieve after this file

You now know:
- how to configure lockout safely
- how to test and reset lockouts
- how local and AD lockout policies interact
- where failures occur and how to fix them
- how to recover if you misconfigure PAM

This file prepares you for real-world lockout management in enterprise Linux environments.