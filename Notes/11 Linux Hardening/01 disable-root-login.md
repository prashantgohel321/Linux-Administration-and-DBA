# disable-root-login.md

This file explains **exact, practical, production-safe methods to disable root login on Linux**.  
Root login is one of the biggest attack surfaces on any Linux system. Disabling it forces all administrators to authenticate using individual accounts and elevate using sudo. This increases accountability, forensics quality, and reduces brute-force exposure.

This document covers:
- all technical methods to disable root login
- correct order of applying them
- what each method protects against
- testing steps
- rollback and recovery procedures

Nothing theoretical — everything is real commands and real scenarios you will face.

---

# 1. Why disable root login

Direct root login means:
- no audit trail (impossible to know WHO used root)
- attackers can brute-force one account (root)
- misconfiguration can allow passwordless root abuse
- automation or scripts may be dangerously tied to root SSH

Industry best practice is:
- disable root SSH entirely
- restrict local root use to sudo only
- use MFA for escalation if possible

---

# 2. Disable root login through SSH (primary method)

OpenSSH supports `PermitRootLogin` directive to control root login behavior.

## Step 1 — Edit sshd_config

```
cp /etc/ssh/sshd_config /root/sshd_config.bak-$(date +%F-%T)
```

Modify or append:

```
PermitRootLogin no
```

This blocks ALL root login methods, including:
- password
- public key
- keyboard-interactive

You can also use more granular options:

```
PermitRootLogin prohibit-password  # allow only key-based root login
PermitRootLogin without-password   # older equivalent
```

## Step 2 — Validate config

```
sshd -t
```

If no output, configuration is valid.

## Step 3 — Reload SSHD

```
systemctl reload sshd
```

## Step 4 — Test

Open a **new terminal** (keeping current session active):

```
ssh root@server
```
You should get:
```
Access denied
```

---

# 3. Disable root password (lock root account)

Even if SSH is blocked, the root password still exists. Locking it adds another layer of protection.

```
passwd -l root
```

This prepends `!` to the password hash in `/etc/shadow`, making password auth impossible.

Verify:
```
sudo grep '^root' /etc/shadow
```
Should show:
```
root:!...
```

Unlock if needed:
```
passwd -u root
```

**Note:** Locking root password does NOT prevent:
- root login using SSH keys (if PermitRootLogin allows it)
- root login from console (if PAM allows it)
- sudo escalation from users

---

# 4. Disable root login using PAM (stronger, deeper control)

PAM controls authentication for many services.  
To block root at PAM level:

Edit one of these depending on scope:
- `/etc/pam.d/sshd` (SSH only)
- `/etc/pam.d/login` (console login)
- `/etc/pam.d/system-auth` (global)

Add at the TOP of the `auth` section:

```
auth requisite pam_succeed_if.so uid != 0
```

Explanation:
- `uid != 0` means: fail if the user is root
- `requisite` stops the stack immediately

Test carefully — this can block all root access including console.

Safer variant (SSH only):

```
# In /etc/pam.d/sshd
auth [success=1 default=ignore] pam_succeed_if.so uid != 0
auth requisite pam_deny.so
```

This only denies root in SSH, not globally.

---

# 5. Restrict `su` so users cannot become root

Disable `su` unless user is in wheel (or an AD admin group).

Edit `/etc/pam.d/su`:

```
auth required pam_wheel.so use_uid
```

Add valid admin user or AD admin group to wheel:

```
gpasswd -a adminuser wheel
# or for AD group
gpasswd -a 'LinuxAdmins@GOHEL.LOCAL' wheel
```

Test:
```
su -   # should fail for non-wheel users
```

---

# 6. Force all admins to use sudo instead

Create `/etc/sudoers.d/admins`:

```
%LinuxAdmins ALL=(ALL) ALL
```

Test:
```
sudo -l
sudo -i
```

This ensures:
- every privileged command is logged
- admins authenticate individually

---

# 7. Optional: Disable root TTY access (console lock)

Edit `/etc/securetty` and remove all contents:

```
>/etc/securetty
```

This blocks root from logging in on TTY consoles.

Risk:  
If you break sudo and lock root console, you may lock yourself out completely.

Use only if you have reliable out-of-band console access (VMware, iDRAC, etc.).

---

# 8. Optional: MFA before privilege escalation (very strong security)

Adding MFA (TOTP / Google Authenticator) for sudo or SSH.

Example for sudo in `/etc/pam.d/sudo`:

```
auth required pam_google_authenticator.so nullok
```

Then regular sudo stack continues.

Test:
```
sudo -i
```

---

# 9. Testing checklist

Before applying ANY hardening:
1. Ensure you have at least one user with sudo.
2. Ensure sudoers entry works:
```
sudo -l
```
3. Start a persistent SSH session.
4. Apply root restrictions.
5. Try new SSH session as root — should fail.
6. Try sudo escalation — should work.
7. Try su escalation if configured.

If ANYTHING breaks, revert immediately.

---

# 10. Rollback steps (if you get locked out)

## SSHD rollback
```
cp /root/sshd_config.bak-* /etc/ssh/sshd_config
systemctl restart sshd
```

## PAM rollback
```
cp /root/sshd.pam.bak-* /etc/pam.d/sshd
systemctl restart sshd
```

## Unlock root password
```
passwd -u root
```

If all else fails:  
Use **VMware console** to log in as root and fix configs manually.

---

# 11. Common failure scenarios and fixes

### 1. Root login still works after changes
Check:
```
grep -i PermitRootLogin /etc/ssh/sshd_config
```
Possible reasons:
- Duplicate PermitRootLogin lines
- Wrong file edited
- Missing sshd reload

### 2. Sudo stopped working for admins
Likely sudoers syntax error. Check:
```
visudo -c
```
Fix the sudoers file.

### 3. `pam_succeed_if` denies legitimate root actions
Move PAM rule to SSH-specific file only.

### 4. AD group not recognized in sudoers
Check:
```
getent group LinuxAdmins
id adminuser
```
Fix SSSD if identity resolution fails.

---

# 12. Minimal recommended hardening combo

For almost all environments, use:

1. Disable root SSH:
```
PermitRootLogin no
```
2. Lock root password:
```
passwd -l root
```
3. Restrict su to wheel:
```
auth required pam_wheel.so use_uid
```
4. Sudo for admin group:
```
%LinuxAdmins ALL=(ALL) ALL
```

This gives strong security without risking unnecessary lockouts.

---

# What you achieve after this file

You will:
- fully protect root from direct abuse
- shift all admin operations to audited channels
- understand each hardening layer, how it works, and how to revert
- be able to deploy root restrictions safely across lab and production

This is real, enterprise-grade root-access hardening.