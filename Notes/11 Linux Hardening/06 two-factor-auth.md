# two-factor-auth.md

This file is a practical, hands-on guide to implementing two‑factor authentication (2FA/MFA) on Linux systems. It covers the methods you will actually use in the lab or production: TOTP (Google Authenticator style), hardware tokens (YubiKey / U2F), and RADIUS/cloud MFA gateways (for AD/SSSD-integrated environments). For each method you get exact configuration fragments, enrollment steps, tests, and recovery procedures.

Everything here is written with Rocky Linux / RHEL-like servers in mind, but the same ideas apply to Debian/Ubuntu with small package-name differences.

---

# Overview — what MFA gives you and when to use which method

Two-factor authentication adds a second proof of identity on top of something the user knows (password) or has (SSH key). Use MFA for interactive access (SSH, sudo, web consoles), and for high-privilege operations. Choose the method that fits your environment:

- **TOTP (time-based one-time password)**: simple, cheap, works with authenticator apps (Google Authenticator, Authy). Good for small teams and lab environments.
- **Hardware tokens (YubiKey / U2F / FIDO2)**: stronger and phishing-resistant. Good for production, security-sensitive roles. Requires provisioning of physical keys.
- **RADIUS / Cloud MFA (Duo, Azure MFA, FreeRADIUS+privacyIDEA, etc.)**: best for enterprise AD integration. Lets you centralize policy and work with AD users without per-host secret files.

Important: MFA can be disruptive if misconfigured. Always keep a break-glass method (console access, emergency account, spare token) before enforcing MFA.

---

# 1. Planning and prerequisites

Before implementing MFA:
1. Confirm `UsePAM yes` in `/etc/ssh/sshd_config`. PAM is the usual enforcement point.  
2. Decide whether MFA applies to all users or only certain AD/local groups. If only some users, plan group membership and use PAM conditional logic (`pam_succeed_if.so`).
3. Keep at least one emergency admin account excluded from MFA or have a console-based recovery plan. Document recovery procedures and store backup codes/spare keys securely.
4. Ensure system clock is synchronized (`chronyd`/`ntpd`) — TOTP depends on accurate time.

Check clock:
```
timedatectl status
chronyc tracking   # if using chrony
```

---

# 2. TOTP (Google Authenticator) — simple and fast

This method uses the `libpam-google-authenticator` PAM module and the user runs `google-authenticator` to create a secret in `~/.google_authenticator`.

## Install

On RHEL/Rocky (EPEL may be required):

```
# as root
dnf install epel-release -y
dnf install google-authenticator qrencode -y   # qrencode optional, helps show QR
```

On Debian/Ubuntu:

```
apt update
apt install libpam-google-authenticator qrencode -y
```

## User enrollment (per user)

Each user runs the following once (on the server as that user):

```
google-authenticator
```

This interactive command will:
- create `~/.google_authenticator` containing the secret and scratch codes
- optionally show a QR code (if `qrencode` installed) you can scan into the Authenticator app
- ask whether to update the file, rate-limiting, etc.

Supply the QR to the user's authenticator app (Google Authenticator, Authy, etc.). Save the printed scratch codes in a secure place for account recovery.

## PAM configuration — SSH

Edit `/etc/pam.d/sshd` (or `system-auth` depending on your PAM layout). Example insertion to require TOTP after password:

```
# /etc/pam.d/sshd (auth section) - sample ordering
# ensure pam_sss/pam_unix run first to validate password
auth    required      pam_sepermit.so
auth    include       password-auth
# after password-auth or system-auth has processed password, require TOTP
auth    required      pam_google_authenticator.so nullok
```

`nullok` allows users who have not enrolled to log in without OTP; remove `nullok` to force enrolment. Use `nullok` during rollout and remove later.

Important: If you use `nullok` during rollout, unenrolled users continue to work.

## SSH server config

Set these values in `/etc/ssh/sshd_config`:

```
UsePAM yes
ChallengeResponseAuthentication yes
PasswordAuthentication yes   # if you are using password+TOTP
# Optionally require both publickey and keyboard-interactive (password/TOTP):
# AuthenticationMethods publickey,keyboard-interactive
```

After changes:
```
sshd -t && systemctl reload sshd
```

## For sudo

To require TOTP for sudo as well, edit `/etc/pam.d/sudo` and add:

```
auth required pam_google_authenticator.so nullok
```

Test with `sudo -i`.

## Testing

1. Enroll test user with `google-authenticator`.  
2. From client, try `ssh testuser@server`. You should be prompted for password and then OTP (keyboard-interactive). Use `ssh -vvv` for verbose debug.  
3. If not prompted, check `sshd_config` and PAM order. Tail logs:

```
tail -f /var/log/secure /var/log/auth.log
```

## Recovery & rollout notes

- Keep `nullok` during initial rollout so unenrolled users can still log in. Remove `nullok` after everyone enrolls.
- Save scratch codes produced during enrollment in a secure password manager.
- Provide a small script and instructions to help users enroll from their machine.
- If locked out, use console to remove `pam_google_authenticator.so` line or restore a PAM file backup.

---

# 3. Hardware tokens (YubiKey / U2F) — phishing-resistant

There are multiple ways to integrate YubiKey/U2F with PAM. Two common modules:
- `pam_yubico` — verifies OTPs produced by YubiKey against Yubico cloud or local validation server (requires API key for Yubico cloud)  
- `pam_u2f` (pamu2fcfg / libu2f-host) — uses U2F/FIDO interface; binds a key pair to a user account locally. This approach is preferred for private deployments because it does not rely on an external validation service.

## Install pam_u2f (U2F) on Rocky

Packages and names vary by distro. On RHEL/Rocky you may need EPEL and building some packages. On Debian/Ubuntu `libpam-u2f` is usually available.

Example (Debian/Ubuntu):
```
apt install libpam-u2f -y
```

On Rocky, you might need to build or find the package in EPEL:
```
dnf install pam_u2f -y   # if available
```

## Enroll a YubiKey for a user

As the user (on the host) run `pamu2fcfg` and save output to a mapping file in the user's home. Example:

```
# as the user
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys
chmod 600 ~/.config/Yubico/u2f_keys
```

`pamu2fcfg` will prompt you to touch the YubiKey; it outputs a key mapping line with the key handle.

Alternatively, for a centrally managed mapping file (system-wide), collect each user's public key lines and store them in `/etc/u2f_keys` with owner root and file readable by root only.

## PAM configuration

Edit `/etc/pam.d/sshd` and add (example requiring U2F after password):

```
# run after password authentication
auth required pam_u2f.so
```

If you want to allow either password+U2F or only U2F with pubkey, use `AuthenticationMethods publickey,keyboard-interactive` with proper PAM setup.

## SSH server config

Enable challenge-response:
```
ChallengeResponseAuthentication yes
UsePAM yes
```

## Testing

1. Enroll user with `pamu2fcfg`.  
2. Try `ssh user@server` — authenticate with password then touch the key when prompted.  
3. If using pubkey+U2F flow, test publickey and then keyboard-interactive.

## Recovery

- Keep a spare YubiKey per user stored in a secure location.  
- Have a break-glass admin account exempted from U2F during rollout.  
- If `pamu2fcfg` mappings lost, restore from central backup or re-enroll keys via console.

---

# 4. RADIUS / Centralized MFA (recommended for AD/SSSD environments)

In enterprise AD environments you usually do not want per-host secret files for AD users. Instead, centralize MFA using a RADIUS gateway that integrates with your MFA provider (Duo, Azure MFA NPS extension, privacyIDEA + FreeRADIUS, etc.). Linux hosts use a PAM RADIUS module or `pam_radius_auth.so` to forward authentication (or second factor) to the central service.

### Model 1 — Password validated locally / AD via SSSD; second factor validated by RADIUS

This model keeps AD for identity and password and delegates second factor to RADIUS. The PAM stack calls the RADIUS module after local or SSSD password validation.

### Model 2 — Full RADIUS authentication (password + 2FA)

PAM delegates entire auth to RADIUS. Limitations: you lose local password prompts and `pam_sss` flow; best for enterprise centralized policies.

## Example: integrate `pam_radius` for second factor

Install module (package name varies):

```
# example
dnf install pam_radius -y      # or apt install libpam-radius-auth
```

Configure `/etc/radiusclient/radiusclient.conf` or `/etc/pam_radius.conf` with RADIUS server IP, secret, and timeout. File format depends on the package. Example `/etc/pam_radius.conf` content:

```
# server[:port]    shared_secret    timeout
192.0.2.10         verysecret       3
```

PAM snippet (in `/etc/pam.d/sshd`) to call radius after password phase:

```
# after password validation via pam_unix/pam_sss
auth required pam_radius_auth.so try_first_pass
```

Duo and other cloud providers typically provide a RADIUS proxy you can point your PAM/RADIUS client to, or they provide a `pam_duo` module with direct integration.

## Testing

- Ensure RADIUS server reachable from host: `nc -zv radius.example 1812` (UDP) — use proper tools.  
- Use `pamtester` to exercise PAM with radius: `pamtester sshd username authenticate` (but radius module may require network access).

## Recovery

- Keep an offline admin or console access in case the RADIUS server is unreachable.  
- Configure `onerr` behavior in PAM (e.g., `onerr=fail` vs `onerr=ok`) depending on whether you want to fail-open or fail-closed.

---

# 5. Strategies to require MFA only for certain users or groups

You will often want to enforce MFA only for sudoers, admin groups, or SSH on production servers. Use PAM conditional tests to apply MFA for group members only.

Example: require Google Authenticator only for members of `LinuxAdmins`:

```
# In /etc/pam.d/sshd, before the pam_google_authenticator line
auth [success=1 default=ignore] pam_succeed_if.so user ingroup LinuxAdmins
auth required pam_google_authenticator.so nullok
```

This skips the TOTP module for users who are not in `LinuxAdmins` (because it will jump past the `pam_google_authenticator` line when the test succeeds). Add `nullok` during rollout.

For SSSD/AD groups that appear as `LinuxAdmins@GOHEL.LOCAL`, use the exact group name shown by `getent group`.

---

# 6. Combining MFA with Public Key authentication

The strongest practical pattern for SSH is to require a SSH public key and a second factor. OpenSSH supports `AuthenticationMethods` to require both:

```
# require publickey followed by keyboard-interactive (e.g., TOTP via PAM)
AuthenticationMethods publickey,keyboard-interactive
UsePAM yes
ChallengeResponseAuthentication yes
```

This prevents attackers from using stolen passwords; they must also possess the private key.

Be careful: requiring both means users must present a key *and* correct password/OTP when connecting. Test before rolling out.

---

# 7. Testing MFA deployments — exact steps

1. Enroll test users with chosen method (TOTP or U2F). Keep enrollment logs.  
2. Keep one console session open during changes.  
3. Use `pamtester` to exercise PAM stacks: `pamtester sshd testuser authenticate` — this helps isolate PAM issues without full SSH.  
4. Use verbose SSH client: `ssh -vvv testuser@server` to view server-client exchange and see when keyboard-interactive prompts are sent.  
5. Tail logs on the server while testing:

```
tail -f /var/log/secure /var/log/auth.log /var/log/sssd/sssd_pam.log
```

6. Test every service you protect (SSH, sudo, su) — they may use different PAM files.

---

# 8. Emergency access and recovery

Always prepare for lockout:
- Keep a break-glass account exempt from MFA and stored securely. Rotate its secret and audit its use.  
- Keep spare hardware tokens in a secure safe. Issue at least two tokens per admin (primary + backup).  
- Store TOTP scratch codes in a secure password manager.  
- Document step-by-step rollback: how to remove the MFA module from PAM via console or how to restore PAM backups.

Rollback example (if you are locked out of SSH):

1. Open VMware console and log in as root.  
2. Edit `/etc/pam.d/sshd` and remove or comment the MFA lines. Restore backup if needed:

```
cp /root/sshd.pam.bak-* /etc/pam.d/sshd
systemctl restart sshd
```

3. For TOTP immediate user bypass: move or rename `~/.google_authenticator` for the affected user.

---

# 9. Auditing and logging MFA events

- TOTP: `pam_google_authenticator` writes normal PAM events to `/var/log/secure`. Monitor for repeated failures.  
- U2F: `pam_u2f` logs failures and key touches to the auth logs; capture these centrally.  
- RADIUS: your RADIUS server will have its own logs — centralize them into SIEM for correlation.

For compliance, keep MFA enrollment and revocation records in your identity store or CMDB.

---

# 10. Example PAM snippets (summary)

**TOTP required for everyone (system-auth or sshd):**
```
auth required pam_google_authenticator.so
```

**TOTP required only for LinuxAdmins group:**
```
auth [success=1 default=ignore] pam_succeed_if.so user ingroup LinuxAdmins
auth required pam_google_authenticator.so nullok
```

**Require publickey + keyboard-interactive (PAM/TOTP):**
```
# /etc/ssh/sshd_config
AuthenticationMethods publickey,keyboard-interactive
UsePAM yes
ChallengeResponseAuthentication yes
```

**U2F (pam_u2f) required after password:**
```
auth required pam_u2f.so
```

**RADIUS second-factor (example):**
```
auth required pam_radius_auth.so try_first_pass
```

---

# 11. Common pitfalls and how to avoid them

- **Missing clock sync**: TOTP fails if system clock skew >30s. Ensure chrony/ntp configured.
- **Forgetting console access**: Always keep a console session or break-glass account while testing.  
- **Using `nullok` blindly**: `nullok` permits unenrolled accounts; remove only after full rollout.  
- **Not storing recovery codes**: Users lose phones; provide secure scratch codes or spare tokens.  
- **Relying on cloud provider MFA only**: Ensure your RADIUS proxy is highly available; otherwise you can lock out many users.

---

# 12. What you achieve after this file

You now have a practical toolkit to deploy MFA in your lab and production: TOTP for quick rollouts, U2F/YubiKey for stronger authentication, and RADIUS/cloud integration for AD-managed users. You know how to enroll users, configure PAM and SSH, test flows, restrict MFA to groups, and recover from lockouts. Use the break-glass procedures, document the rollout, and test thoroughly before enforcing MFA broadly.