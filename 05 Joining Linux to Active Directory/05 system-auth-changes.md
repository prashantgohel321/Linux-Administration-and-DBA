# system-auth-changes.md

- In this file I am focusing on what changes happen to the **system-auth** and related PAM files when I run `realm join`. Many people correctly join Linux to AD but fail to understand PAM changes. That leads to broken authentication, blocked users, or unexpected login failures. I want a practical, line-by-line understanding of how PAM integrates with SSSD and Kerberos.

---

- [system-auth-changes.md](#system-auth-changesmd)
  - [What system-auth is](#what-system-auth-is)
  - [What realm modifies during join](#what-realm-modifies-during-join)
  - [Example PAM changes](#example-pam-changes)
  - [Why pam\_sss order matters](#why-pam_sss-order-matters)
  - [password-auth](#password-auth)
  - [account phase](#account-phase)
  - [session phase](#session-phase)
  - [Verify PAM includes pam\_sss](#verify-pam-includes-pam_sss)
  - [Testing PAM after changes](#testing-pam-after-changes)
  - [Inspect PAM debug logs](#inspect-pam-debug-logs)
  - [Rollback / revert changes](#rollback--revert-changes)
  - [Restart services](#restart-services)
  - [Practical workflow](#practical-workflow)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## What system-auth is

- `system-auth` is a core PAM configuration file. It defines how authentication is handled for most system services (login, sudo, SSH, su, etc.)

- Linux authentication flows through PAM, and PAM uses `system-auth` as a common stack file. Any service that uses PAM includes the `system-auth` stack.

- Therefore, if anything here breaks, **all authentication breaks**, including AD authentication.

---

<br>
<br>

## What realm modifies during join

When I run:
```bash
realm join gohel.local -U Administrator
```

realm updates:
- /etc/pam.d/system-auth
- /etc/pam.d/password-auth
- /etc/nsswitch.conf
- /etc/sssd/sssd.conf
- PAM stack modules

realm adds PAM modules that allow authentication against SSSD.

---

<br>
<br>

## Example PAM changes

Before join, system-auth might look like:
```bash
auth        required      pam_env.so
auth        sufficient    pam_unix.so
auth        required      pam_deny.so
```

After join, realm inserts SSSD modules:
```bash
auth        sufficient    pam_sss.so
```

So the sequence becomes something like:
```bash
auth        required      pam_env.so
auth        sufficient    pam_unix.so
auth        sufficient    pam_sss.so
auth        required      pam_deny.so
```

This means:
- Local authentication still works (pam_unix)
- AD authentication happens via pam_sss
- pam_deny blocks anything not handled

---

<br>
<br>

## Why pam_sss order matters

- If pam_sss.so is placed incorrectly, Linux may refuse AD logins or may try only local authentication. The module must be in the correct position (“sufficient”) so that successful AD authentication completes the chain.

---

<br>
<br>

## password-auth

password-auth controls authentication for network logins like SSH. realm modifies it similarly to system-auth.

Typical pam_sss additions:
```bash
auth        sufficient    pam_sss.so
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
password    sufficient    pam_sss.so
session     required      pam_sss.so
```

---

<br>
<br>

## account phase

Account phase checks account restrictions. pam_sss.so enforces AD policies such as:
- disabled accounts
- locked accounts
- login hours

So even if password is correct, account may be denied based on AD rules.

---

<br>
<br>

## session phase

Session phase controls session setup, including home directory creation with:
```bash
pam_mkhomedir.so
```

realm normally enables this via oddjob.

---

<br>
<br>

## Verify PAM includes pam_sss

After join, check:
```bash
grep sss /etc/pam.d/system-auth
```

and
```bash
grep sss /etc/pam.d/password-auth
```

If no output, PAM integration failed.

---

<br>
<br>

## Testing PAM after changes

Test AD user authentication locally:
```bash
su - testuser1@gohel.local
```

If system-auth is correct, I should be able to authenticate.

Test SSH:
```bash
ssh testuser1@gohel.local@rocky-linux-ip
```

If SSH fails but su works, password-auth is misconfigured.

---

<br>
<br>

## Inspect PAM debug logs

PAM messages appear in:
```bash
/var/log/secure
```

Look for:
- pam_sss.so errors
- authentication failures
- unknown user messages

---

<br>
<br>

## Rollback / revert changes

If something broke, I can temporarily disable AD PAM modules by editing system-auth and removing pam_sss lines, but this should only be done for troubleshooting. Always keep a backup:
```bash
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak
```

---

<br>
<br>

## Restart services

After editing PAM, restart SSSD:
```bash
systemctl restart sssd
```

Also restart SSH if needed:
```bash
systemctl restart sshd
```

---

<br>
<br>

## Practical workflow

1. Join domain
2. Inspect system-auth and password-auth
3. Verify pam_sss lines exist
4. Test su and SSH logins
5. Check logs
6. Restart SSSD if issues occur

---

<br>
<br>

## What I achieve after this file

- By understanding system-auth changes, I know exactly how PAM links the Linux authentication flow to SSSD and AD. I also know where to check if authentication fails, how to confirm PAM configuration, and how to test the entire chain realistically.