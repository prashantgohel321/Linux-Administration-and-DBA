# pam-modules.md

- In this file I am going deep into **every important PAM module** that matters for Linux + AD + SSSD authentication. I am not writing a theoretical list; I am explaining each module practically — what it does, when it runs, what breaks if it fails, and how to test its behavior. PAM authentication issues almost always trace back to one or more modules inside `/etc/pam.d/*`. This file gives me a practical reference I can rely on.

---

<br>
<br>

# What PAM modules actually are

PAM modules are small shared libraries (`.so` files) located in:
```bash
/lib64/security/
```

Each module performs a very specific task:
- checking passwords
- enforcing account restrictions
- creating home directories
- handling AD authentication via SSSD

Modules are combined inside the PAM config files to build complete authentication behavior.

---

<br>
<br>

# The modules I must know for Linux + AD environments
These are the modules I will encounter and troubleshoot most often:

1. **pam_env.so**
2. **pam_unix.so**
3. **pam_sss.so**
4. **pam_deny.so**
5. **pam_permit.so**
6. **pam_faillock.so**
7. **pam_limits.so**
8. **pam_mkhomedir.so**
9. **pam_succeed_if.so**
10. **pam_tally2.so** (older distros)
11. **pam_pwquality.so** (password policy)

Each module is described below with practical examples.

---

<br>
<br>

# 1. pam_env.so

This module loads environment variables before authentication begins.
```bash
auth    required    pam_env.so
```
If this module fails → authentication does NOT fail. It simply means environment variables will not load.

This module rarely causes issues.

---

<br>
<br>

# 2. pam_unix.so

This is the core module for **local** Linux authentication. It checks `/etc/passwd` and `/etc/shadow`.
```bash
auth    sufficient    pam_unix.so
password required      pam_unix.so
```

Behavior:
- If a local user enters the correct password → authentication succeeds immediately.
- If password is wrong → PAM continues to next modules.

If pam_unix.so is removed or misordered:
- Root login might break
- Local users may fail authentication

Test it:
```bash
su - localuser
```

If AD users authenticate but local users fail → pam_unix misconfigured.

---

<br>
<br>

# 3. pam_sss.so

This is the MOST important module for AD authentication.
```bash
auth    sufficient    pam_sss.so
account [default=bad success=ok user_unknown=ignore] pam_sss.so
session required      pam_sss.so
```

pam_sss.so delegates authentication to SSSD. If this module is missing or placed incorrectly:
- AD users cannot authenticate
- SSSD logins fail

Test it using:
```bash
su - testuser1@gohel.local
```

If `id` works but login fails → pam_sss.so missing in system-auth/password-auth.

---

<br>
<br>

# 4. pam_deny.so

This module **always denies** authentication.
```bash
auth required pam_deny.so
```
It should ALWAYS be the last module.

If it appears earlier in the stack → EVERY login fails.

This is a common misconfiguration.

---

<br>
<br>

# 5. pam_permit.so

This module **always allows** authentication. Not used in secure setups.
```bash
auth optional pam_permit.so
```
Using this in wrong place can allow unintended logins.

---

<br>
<br>

# 6. pam_faillock.so

This module implements account lockout after failed login attempts.

Example:
```bash
auth        required        pam_faillock.so preauth silent deny=3 unlock_time=300
auth        [success=1]     pam_faillock.so authfail deny=3 unlock_time=300
account     required        pam_faillock.so
```

If misconfigured:
- all users, including root, may get locked
- AD users may get locked locally even if AD account is fine

Check faillock counters:
```bash
faillock --user testuser1
```
Reset counters:
```bash
faillock --user testuser1 --reset
```

---

<br>
<br>

# 7. pam_limits.so

Applies system resource limits from `/etc/security/limits.conf`.
```bash
session required pam_limits.so
```
This module rarely breaks authentication, but missing it means session limits won’t apply.

---

<br>
<br>

# 8. pam_mkhomedir.so

Automatically creates home directories for AD users on first login.
```bash
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
```
If missing:
- AD users may authenticate but fail login due to missing home directory

Test by logging in as a new AD user.

---

<br>
<br>

# 9. pam_succeed_if.so

Conditional checks.

For example, allow only certain UID ranges:
```bash
auth required pam_succeed_if.so uid >= 1000
```
Or block system accounts from logging in.

If misconfigured:
- AD users may get blocked unintentionally

Test by checking logs:
```bash
grep pam_succeed_if /var/log/secure
```

---

<br>
<br>

# 10. pam_tally2.so (older module)

Used for lockout policies on older systems.

Check failed attempts:
```bash
pam_tally2 --user testuser1
```
Reset counter:
```bash
pam_tally2 --user testuser1 --reset
```

Modern systems use `pam_faillock.so` instead.

---

<br>
<br>

# 11. pam_pwquality.so

Enforces password complexity rules.
```bash
password required pam_pwquality.so try_first_pass retry=3
```
If misconfigured:
- password changes may fail
- root may be blocked from setting simpler passwords

---

<br>
<br>

# Module execution order — the MOST critical part

Authentication behaves differently depending on module order.

Example safe flow:
```bash
auth required pam_env.so
auth sufficient pam_unix.so
auth sufficient pam_sss.so
auth required pam_deny.so
```

If pam_deny.so is placed before pam_sss.so:
- AD authentication will always fail

If pam_unix.so comes after pam_sss.so:
- AD users will authenticate slower
- local users might be forced through SSSD unnecessarily

Order matters more than the modules themselves.

---

<br>
<br>

# How to test a module effectively

Use these commands:

### 1. Test PAM authentication
```bash
pamtester login testuser1 authenticate
```

### 2. Test login via su (bypasses SSH issues)
```bash
su - testuser1
```

### 3. Trigger specific module logs
```bash
grep PAM /var/log/secure
```

### 4. Watch SSSD side
```bash
tail -f /var/log/sssd/sssd_pam.log
```

---

<br>
<br>

# Common module-related failures and fixes

### AD users fail login but `id` works
Fix:
- pam_sss.so missing in system-auth or password-auth

### Local users fail login
Fix:
- pam_unix.so misplaced or removed

### All users denied
Fix:
- pam_deny.so placed too early

### Users locked after 3 attempts unexpectedly
Fix:
- faillock misconfigured

### Home directory not created
Fix:
- pam_mkhomedir.so missing in session phase

---

<br>
<br>

# What I achieve after this file

I now understand every major PAM module I will use in real Active Directory + Linux setups. I know:
- what each module does
- how they interact
- how ordering affects login
- how to test each module
- where to look when a specific module breaks authentication

This knowledge allows me to debug PAM quickly and correctly without guessing.