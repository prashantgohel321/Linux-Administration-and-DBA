# restrict-root.md

This file explains **how to restrict root access on Linux systems** in a practical, production-ready way. Root is the single most powerful account on a system; protecting it reduces blast radius, improves auditability, and forces use of safer privilege escalation workflows (sudo, RBAC). This document gives exact commands, multiple strategies, real-world caveats, testing steps, and recovery procedures so you can change root access safely in your VMware lab.

No theory-only sections — everything here is actionable and tested in enterprise-like setups.

---

# Why restrict root

Root has unlimited power. If an attacker or misconfigured service obtains root, the entire host is compromised. Best practice in modern operations is to disable direct root login (especially over the network) and require operators to use sudo from individual accounts. This gives you:

- accountability: sudo logs who ran what as root
- control: fine-grained privileges via sudoers
- auditability: easier to trace actions
- resilience: minimal direct exposure of the root credential

But restricting root must be done safely — one wrong step and you can lock yourself out of the machine.

---

# Overview of methods (use a combination)

1. Disable root SSH login (`sshd_config: PermitRootLogin no`) — **must** keep alternative access.  
2. Use PAM to block root at service level (`pam_succeed_if.so uid != 0`) for additional defense.  
3. Enforce `wheel` or AD-admin group membership for `su` via `pam_wheel.so`.  
4. Require 2FA for privileged sudoers (OTP or hardware token) — adds MFA before escalation.  
5. Use `sudo` and restrict `sudo` to AD groups instead of allowing root SSH.  
6. Temporarily allow emergency root access via console only (no network access) for maintenance.  
7. Audit and monitoring: auditd, sudo logs, syslog forwarding.

Use a layered approach: disable direct root SSH, restrict `su`, and require sudo for admin tasks.

---

# Method 1 — Disable root SSH (sshd_config)

This is the first and simplest step. Edit `/etc/ssh/sshd_config` and set:

```
PermitRootLogin no
# or more granular: PermitRootLogin without-password  (disallow password but allow keys)
```

Exact commands:

```
cp /etc/ssh/sshd_config /root/sshd_config.bak-$(date +%F-%T)
# edit with your preferred editor; example with sed to set PermitRootLogin no
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload sshd
```

Testing:

1. Keep an active non-root session open with sudo access before reloading.  
2. In a separate terminal, try: `ssh root@server` — it should fail.  
3. Test a normal user can `sudo -i` or `sudo -s` to become root.

Caveats:
- If you rely on key-based root login for automation, update automation to use a different service account or sudo.  
- Some cloud providers or images expect root SSH. Confirm before rolling out.

Emergency rollback (if you are locked out):
- Use VM console in VMware.
- Restore backup:

```
cp /root/sshd_config.bak-* /etc/ssh/sshd_config
systemctl restart sshd
```

---

# Method 2 — Disallow root via PAM (additional hardening)

This adds a PAM-level block so even if sshd_config misconfigured or another service tries to allow root, PAM denies it.

Edit `/etc/pam.d/sshd` or `/etc/pam.d/password-auth` and add near the top (before auth substack include):

```
# deny direct root login via PAM
auth    requisite   pam_succeed_if.so uid != 0
```

Explanation: The rule checks the **calling** user's UID; if UID is 0, the test fails and control returns with failure.

Exact steps:

```
cp /etc/pam.d/sshd /root/sshd.pam.bak-$(date +%F-%T)
# insert line before any include/substack that handles password auth
# using awk or sed is risky; prefer editing with vi/nano in lab
```

Testing:
- Try `ssh root@server` — should be denied.  
- Try `su -` from a sudoer account — behavior depends on su PAM config; see method 3.

Caveats:
- pam_succeed_if depends on NSS (id lookups). If NSS fails in early boot, this may behave unexpectedly. Use with care and keep console access.

Rollback:
```
cp /root/sshd.pam.bak-* /etc/pam.d/sshd
systemctl restart sshd
```

---

# Method 3 — Restrict `su` to wheel (or AD admin) group

`su` allows users to switch identity to root. Restrict who can `su` to root by enabling `pam_wheel.so`.

Edit `/etc/pam.d/su` and ensure this line exists and is active:

```
auth    required    pam_wheel.so use_uid
```

This requires the calling user to be in the local `wheel` group to `su` to root.

To add an AD group to wheel (example `LinuxAdmins`):

```
# add AD group to wheel; syntax depends on your NSS/SSSD mapping
# if group appears as 'LinuxAdmins' in getent group:
gpasswd -a 'LinuxAdmins' wheel
# if group appears as 'LinuxAdmins@GOHEL.LOCAL':
gpasswd -a 'LinuxAdmins@GOHEL.LOCAL' wheel
```

Testing:
- Try `su -` as a non-wheel user — should be denied.  
- Try `su -` as a wheel member — should succeed (if password correct).

Caveats:
- Adding AD groups to wheel must be done using the exact group string as returned by `getent group`.
- If you rely only on wheel, ensure at least one admin is in wheel or you'll lock out access.

---

# Method 4 — Use sudo for privilege escalation (recommended practice)

Sudo gives auditability and fine-grained control. Steps to use sudo instead of root login:

1. Create AD groups for admins (e.g., `LinuxAdmins`).
2. Add the group to sudoers via `/etc/sudoers.d/`:

```
echo '%LinuxAdmins ALL=(ALL) ALL' > /etc/sudoers.d/linux-admins
chmod 440 /etc/sudoers.d/linux-admins
visudo -c
```

3. Require password and optionally 2FA for sudo. For OTP via Google Authenticator/pam, add in PAM stack for sudo or SSH as needed.

Testing:
- As an AD admin, run: `sudo -l` and `sudo -i`.
- Check logs: `/var/log/secure` or `/var/log/auth.log` and sudo logs (`/var/log/secure` contains sudo entries by default).

Caveats:
- Sudo does not log every action by default; enable `log_output` or use session recording tools for higher audit.

---

# Method 5 — Disable root password (lock root account)

Lock the root account password so local password-based root access is impossible while keeping UID 0 available for sudo and system use.

```
passwd -l root   # locks the password
# or edit /etc/shadow to prepend '!' to the root password field
```

To unlock later:
```
passwd -u root
```

Caveats:
- `passwd -l root` only prevents password auth. Key-based or PAM methods may still allow root if not blocked elsewhere. Combine with sshd_config changes.

---

# Method 6 — Require MFA before allowing escalation

Implement an OTP method (e.g., `pam_google_authenticator.so`) or hardware tokens integrated into PAM for sudo or SSH. Example placement for sudo in `/etc/pam.d/sudo` (or globally in `system-auth`):

```
auth required pam_google_authenticator.so nullok
```
Followed by the standard sudo PAM stack. This ensures OTP is required before `sudo` grants privileges.

Testing:
- Configure OTP for a user, then `sudo -i` — OTP prompt should appear.

Caveats:
- MFA rollout requires user enrollment and backup codes. Plan before enforcement.

---

# Method 7 — Emergency access and rollback plans

Always plan for emergency access before enforcing restrictions.

Options:
- Keep VMware console access available for root recovery.  
- Use cloud provider serial consoles where applicable.  
- Maintain one break-glass account: a local user in wheel with physical or console-only access. Document its use and rotate credentials.  

Emergency recovery steps:
1. Open VM console.  
2. Login as root locally (console ignores sshd restrictions).  
3. Restore configuration backups for sshd, PAM, or sudoers.  

Example restore commands:

```
cp /root/sshd_config.bak-* /etc/ssh/sshd_config
cp /root/sshd.pam.bak-* /etc/pam.d/sshd
cp /root/sudoers.d.bak-* /etc/sudoers.d/yourfile
systemctl restart sshd
systemctl restart sssd
```

---

# Auditing and monitoring root activity

1. Enable sudo logging: configure `Defaults logfile=/var/log/sudo.log` in `/etc/sudoers` or rely on syslog.  
2. Use `auditd` to capture execve and other root actions:

Example rule to log all uses of `setuid` calls or shell execs (tune as needed):

```
# /etc/audit/rules.d/root-actions.rules
-a always,exit -F arch=b64 -S execve -F uid=0 -k root-actions
-a always,exit -F arch=b32 -S execve -F uid=0 -k root-actions
```

Reload audit rules and verify:
```
systemctl restart auditd
ausearch -k root-actions | aureport -f
```

3. Forward auth logs to centralized logging (syslog server or SIEM) for long-term retention and alerting.

---

# SELinux and root restrictions

SELinux can add another layer: restrict which daemons can run as root, control capabilities, and confine system services. Use SELinux booleans and policies to limit root-privileged actions when possible.

Check SELinux status:
```
sestatus
getsebool -a | grep ssh
```

Be careful: SELinux misconfiguration can block legitimate recovery steps. Test policies in permissive mode before enforcing.

---

# Testing checklist (apply in lab before production)

1. Ensure you have an active admin session open.  
2. Create at least one admin user in AD group and ensure `id` resolves.  
3. Apply sshd_config change (PermitRootLogin no) and reload sshd.  
4. Test non-root login + `sudo -i` and `ssh root@server` from another terminal.  
5. Add PAM block and test again.  
6. Configure `pam_wheel.so` and test `su -` behavior.  
7. Configure sudoers for AD group and test `sudo -l`.  
8. Enable auditd rule and verify sudo actions are logged.  
9. Confirm you can recover via VM console.

---

# Common mistakes and how to avoid them

- Changing sshd_config and restarting SSH without a fallback console. Always keep a root session open.  
- Using `pam_succeed_if` without confirming NSS resolution works — test `id root` first.  
- Removing all members from wheel group. Keep at least one emergency account.  
- Relying on a single authentication method (e.g., keys) for admin automation — migrate automation to managed service accounts before disabling root.

---

# Quick recipes

Disable root SSH but allow root via console only:

```
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload sshd
passwd -l root   # lock root password
```

Restrict `su` to wheel only:

```
# ensure pam_wheel is present and active in /etc/pam.d/su
usermod -aG wheel adminuser
```

Grant sudo to AD group:

```
echo '%LinuxAdmins ALL=(ALL) ALL' > /etc/sudoers.d/linux-admins
chmod 440 /etc/sudoers.d/linux-admins
visudo -c
```

---

# What you achieve after this file

After applying the guidance here, you will have a layered, defend-in-depth approach to protect the root account: no direct network exposure, controlled local escalation, audit trails for privileged actions, MFA options, and a tested emergency rollback plan. You will be able to enforce these safely in your VMware lab and adapt them to production.
