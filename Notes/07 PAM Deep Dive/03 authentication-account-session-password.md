# authentication-account-session-password.md

- In this file I am breaking down **the four core PAM phases**: `auth`, `account`, `password`, and `session`. These phases appear in every PAM config file, and understanding them is mandatory for debugging login failures in Linux, especially when Active Directory + SSSD is involved.

- I want a **practical explanation** of what each phase does, how PAM executes modules in each phase, what goes wrong when a phase breaks, and how to debug each one.

---

- [authentication-account-session-password.md](#authentication-account-session-passwordmd)
- [Why PAM has four phases](#why-pam-has-four-phases)
- [1. AUTH phase — Authentication (Password check)](#1-auth-phase--authentication-password-check)
    - [How AUTH phase works in reality](#how-auth-phase-works-in-reality)
    - [AUTH failure cases](#auth-failure-cases)
    - [Commands to test AUTH phase](#commands-to-test-auth-phase)
- [2. ACCOUNT phase — Account validation](#2-account-phase--account-validation)
    - [How ACCOUNT phase works](#how-account-phase-works)
    - [ACCOUNT failure scenarios](#account-failure-scenarios)
    - [Commands to test ACCOUNT phase](#commands-to-test-account-phase)
- [3. PASSWORD phase — Password changes](#3-password-phase--password-changes)
    - [What PASSWORD phase does](#what-password-phase-does)
    - [PASSWORD failure examples](#password-failure-examples)
    - [Testing PASSWORD phase](#testing-password-phase)
- [4. SESSION phase — After authentication](#4-session-phase--after-authentication)
    - [What SESSION phase does](#what-session-phase-does)
    - [SESSION failure cases](#session-failure-cases)
    - [Testing SESSION phase](#testing-session-phase)
- [Practical example of all phases working](#practical-example-of-all-phases-working)
- [Troubleshooting each phase](#troubleshooting-each-phase)
    - [AUTH problems](#auth-problems)
    - [ACCOUNT problems](#account-problems)
    - [PASSWORD problems](#password-problems)
    - [SESSION problems](#session-problems)
- [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

# Why PAM has four phases

Linux authentication is not just “check password”. PAM splits the logic into four phases so that different parts of authentication can be controlled independently.

The four phases are:
1. `auth` → Who are you?
2. `account` → Are you allowed to log in?
3. `password` → Can you change your password?
4. `session` → What happens after login?

Each PAM module belongs to one or more of these phases.

Whenever a user logs in through SSH, console, su, or sudo, PAM goes through these phases in order.

---

<br>
<br>

# 1. AUTH phase — Authentication (Password check)

This is the first and most important phase. It checks:
- Does the password match?
- Does the authentication provider confirm the identity?

Typical modules in this phase:
```bash
auth    required      pam_env.so
auth    sufficient    pam_unix.so
auth    sufficient    pam_sss.so
auth    required      pam_deny.so
```

### How AUTH phase works in reality

- If user is local → `pam_unix.so` verifies its password.
- If user is AD → `pam_sss.so` passes authentication to SSSD → Kerberos.

### AUTH failure cases

- Wrong password
- Kerberos failure inside pam_sss
- SSSD offline and cache disabled
- pam_deny.so placed too early

### Commands to test AUTH phase
```bash
su - testuser1
pamtester sshd testuser1 authenticate
```

If `pamtester` fails, check:
```bash
tail -f /var/log/secure
```

---

<br>
<br>

# 2. ACCOUNT phase — Account validation

This phase does **not** check password. Password has already succeeded.

ACCOUNT phase checks:
- Is the account locked?
- Is the account expired?
- Are login hours restricted?
- Is the user allowed to log in on this machine?
- AD account disabled?
- Access filter rules?

Example entries:
```bash
account     required     pam_unix.so
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
```

### How ACCOUNT phase works

If password is correct but AD account is disabled, ACCOUNT phase denies login.

Typical error:
```bash
sssd_pam.log: Access denied for user
```

### ACCOUNT failure scenarios

- AD account disabled
- User not member of allowed AD groups
- ad_access_filter denies user
- Login restricted by AD GPO

### Commands to test ACCOUNT phase
```bash
getent passwd testuser1
sssctl user-show testuser1
```

---

<br>
<br>

# 3. PASSWORD phase — Password changes

This phase only runs when a user is changing their password.

Modules:
```bash
password   required     pam_pwquality.so
password   sufficient   pam_unix.so
password   sufficient   pam_sss.so
```

### What PASSWORD phase does
- Enforces password complexity
- Performs password updates (local or AD)

If AD is used, password changes go through SSSD → AD.

### PASSWORD failure examples

- Password does not meet complexity rules
- AD denies password change
- Wrong module order
- pam_pwquality misconfigured

### Testing PASSWORD phase
```bash
passwd testuser1
```

If failure message:
```bash
pam_pwquality: Password fails quality check
```

---

<br>
<br>

# 4. SESSION phase — After authentication

This phase runs after authentication succeeds.

Typical modules:
```bash
session    required     pam_limits.so
session    required     pam_mkhomedir.so
session    required     pam_unix.so
session    optional     pam_sss.so
```

### What SESSION phase does
- Logs session start/stop
- Sets resource limits (pam_limits)
- Creates home directory if missing (pam_mkhomedir)
- Mounts directories (if configured)
- Initializes user environment

### SESSION failure cases

- Home directory not created (pam_mkhomedir missing)
- Limits not applied
- Session denied by restrictions

### Testing SESSION phase
Try SSH login:
```bash
ssh testuser1@server
```
Check logs:
```bash
grep session /var/log/secure
```

Permission error like:
```bash
Could not chdir to home directory: No such file or directory
```
means pam_mkhomedir.so missing.

---

<br>
<br>

# Practical example of all phases working

Here is a simplified but safe PAM stack for AD + local users:
```bash
auth        required      pam_env.so
auth        sufficient    pam_unix.so
auth        sufficient    pam_sss.so
auth        required      pam_deny.so

account     required      pam_unix.so
account     [default=bad success=ok user_unknown=ignore] pam_sss.so

password    requisite     pam_pwquality.so
password    sufficient    pam_unix.so
password    sufficient    pam_sss.so
password    required      pam_deny.so

session     required      pam_limits.so
session     required      pam_mkhomedir.so
session     optional      pam_sss.so
```

This ensures:
- Local users authenticate fast
- AD users authenticate via SSSD
- Password changes work for both
- Home directories are created automatically

---

<br>
<br>

# Troubleshooting each phase

### AUTH problems
- check `pam_sss.so` exists
- check Kerberos via kinit
- check SSSD logs

### ACCOUNT problems
- check AD account status
- check SSSD domain access rules
- check pam_succeed_if filters

### PASSWORD problems
- check pam_pwquality
- check AD password policies
- check passwd logs

### SESSION problems
- check pam_mkhomedir
- check file permissions
- check /var/log/secure for session errors

---

<br>
<br>

# What I achieve after this file

I now understand how PAM processes each authentication phase independently. When a login fails, I can identify whether it failed:
- in AUTH (password wrong or Kerberos broken)
- in ACCOUNT (AD denies login)
- in PASSWORD (policy violation)
- in SESSION (environment initialization failure)

This structured knowledge makes PAM debugging predictable and efficient.