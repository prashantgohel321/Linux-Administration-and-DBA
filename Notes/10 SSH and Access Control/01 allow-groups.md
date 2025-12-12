# allow-groups.md

This file explains how to **allow only users who belong to specific AD groups to access a Linux server** (SSH, console, services) using PAM, SSSD, and NSS. The goal is practical: exact configurations, commands to apply, tests to run, and precise troubleshooting steps for every real failure you’ll hit.

This is not theoretical. Every example here is intended to work in a real VMware lab with Rocky Linux and a Windows Server 2022 AD domain.

---

- [allow-groups.md](#allow-groupsmd)
- [1. Why you would restrict access by AD groups](#1-why-you-would-restrict-access-by-ad-groups)
- [2. Two approaches — which to choose](#2-two-approaches--which-to-choose)
- [3. Method A — Allow groups using PAM (sshd-specific)](#3-method-a--allow-groups-using-pam-sshd-specific)
  - [Example requirement](#example-requirement)
  - [Steps (exact commands)](#steps-exact-commands)
  - [Notes and caveats](#notes-and-caveats)
- [4. Method B — Allow groups using SSSD `access_provider` (recommended)](#4-method-b--allow-groups-using-sssd-access_provider-recommended)
  - [Example requirement](#example-requirement-1)
  - [sssd.conf snippet (exact)](#sssdconf-snippet-exact)
  - [Steps (exact commands)](#steps-exact-commands-1)
  - [Benefits](#benefits)
  - [Caveats](#caveats)
- [5. Method C — Allow groups using `ad_access_filter` (LDAP filter)](#5-method-c--allow-groups-using-ad_access_filter-ldap-filter)
  - [Example](#example)
  - [Steps](#steps)
  - [Notes](#notes)
- [6. How to test access rules safely](#6-how-to-test-access-rules-safely)
- [7. Common failure scenarios and exact fixes](#7-common-failure-scenarios-and-exact-fixes)
  - [Failure: allowed users are denied](#failure-allowed-users-are-denied)
  - [Failure: disallowed users can still log in](#failure-disallowed-users-can-still-log-in)
  - [Failure: rule works sometimes, not always](#failure-rule-works-sometimes-not-always)
  - [Failure: everyone is denied after enabling SSSD filter](#failure-everyone-is-denied-after-enabling-sssd-filter)
- [8. Logging and auditing](#8-logging-and-auditing)
- [9. Performance and caching considerations](#9-performance-and-caching-considerations)
- [10. Quick reference examples](#10-quick-reference-examples)
- [11. Final checklist before rolling to production](#11-final-checklist-before-rolling-to-production)
- [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

# 1. Why you would restrict access by AD groups

You restrict access to reduce attack surface and enforce least privilege. Centralizing SSH access control in AD groups makes administration predictable: add or remove a user from the AD group, and access changes across all Linux hosts immediately.

Common use cases:
- only developers can SSH into dev servers
- only ops team can access production servers
- contractors are given temporary group membership

---

<br>
<br>

# 2. Two approaches — which to choose

There are two practical ways to allow groups:

1. **PAM `pam_succeed_if.so` checks** (fast, done on the host)
2. **SSSD access_provider** (centralized via SSSD config, recommended when many hosts)

Use PAM checks for quick host-specific rules. Use SSSD access_provider when you need a uniform policy across many hosts and want AD to be the single source of truth.

---

<br>
<br>

# 3. Method A — Allow groups using PAM (sshd-specific)

This method modifies `/etc/pam.d/sshd` or `/etc/pam.d/password-auth` to fail early for users not in allowed groups.

## Example requirement
Allow only members of `LinuxUsers` and `DevOps` AD groups to SSH.

## Steps (exact commands)

1. Verify AD group resolution and membership on the host:
```bash
getent group LinuxUsers
getent group DevOps
id testuser
```

2. Backup SSH PAM config:
```bash
cp /etc/pam.d/sshd /root/sshd.pam.bak-$(date +%F-%T)
```

3. Edit `/etc/pam.d/sshd` and add this line **before** `auth substack password-auth` (so it denies early):

```bash
# allow only AD groups LinuxUsers and DevOps
auth [success=1 default=ignore] pam_succeed_if.so user ingroup "LinuxUsers|DevOps"
auth requisite pam_deny.so
```

Explanation:
- The `pam_succeed_if.so` line returns success when user is in either group. The control flag `[success=1 default=ignore]` tells PAM to skip the next rule on success.
- If the test fails, control falls through to the `pam_deny.so` line which denies the login immediately.

4. Test safely from a second terminal:
```bash
# keep one root/working session open
ssh -vvv testuser@server
```

5. If you lock yourself out, restore backup via console:
```bash
cp /root/sshd.pam.bak-* /etc/pam.d/sshd
systemctl restart sshd
```

## Notes and caveats
- Use exact group names as shown by `getent group`. If SSSD exposes groups as `LinuxUsers@GOHEL.LOCAL`, use that exact string.
- Quote the group list if it contains special characters.
- `pam_succeed_if` uses the NSS view — if `id` or `getent` fail, the test fails.

---

<br>
<br>

# 4. Method B — Allow groups using SSSD `access_provider` (recommended)

SSSD can be configured to allow or deny users based on AD groups. This centralizes control in `/etc/sssd/sssd.conf` and reduces per-host PAM edits.

## Example requirement
Allow only `LinuxUsers` and `DevOps` AD groups to log in.

## sssd.conf snippet (exact)

Edit `/etc/sssd/sssd.conf` within the relevant domain section and add:

```bash
[domain/GOHEL.LOCAL]
# existing config ...
access_provider = simple
simple_allow_groups = LinuxUsers, DevOps
# or use fully qualified names if your SSSD uses them:
# simple_allow_groups = "LinuxUsers@gohel.local,DevOps@gohel.local"
```

## Steps (exact commands)

1. Backup config:
```bash
cp /etc/sssd/sssd.conf /root/sssd.conf.bak-$(date +%F-%T)
chmod 600 /root/sssd.conf.bak-*
```

2. Edit and save the domain section as shown. Keep syntax exact — SSSD is picky.

3. Restart SSSD:
```bash
systemctl restart sssd
```

4. Test immediately:
```bash
sssctl domain-status
getent passwd testuser
# try login from an allowed and disallowed user in separate terminals
ssh allowed_user@server
ssh disallowed_user@server
```

## Benefits
- Centralized: change the group membership in AD and all hosts obey.
- Clear logging in SSSD: denied users show `Access denied` lines in SSSD logs.

## Caveats
- If you misconfigure DNS or SSSD, all AD logins can be blocked. Always keep a root console.
- `simple_allow_groups` uses the NSS view. If groups do not appear via `getent`, the rule fails.
- Caution with caches: SSSD caches group membership. Use `sss_cache -E` to clear during tests.

---

<br>
<br>

# 5. Method C — Allow groups using `ad_access_filter` (LDAP filter)

For complex rules, use LDAP filters. This is powerful and lets you implement membership conditions, OU-based rules, or complex DN checks.

## Example
Only allow users who are members of `CN=LinuxUsers,OU=Groups,DC=gohel,DC=local`:

```bash
[domain/GOHEL.LOCAL]
access_provider = ad
ad_access_filter = (memberOf=CN=LinuxUsers,OU=Groups,DC=gohel,DC=local)
```

## Steps
1. Backup sssd.conf
2. Add `access_provider = ad` and `ad_access_filter` under domain section
3. Restart SSSD
4. Test
```bash
sssctl user-show testuser
tail -f /var/log/sssd/sssd_pam.log
```

## Notes
- LDAP filters must be valid and tested. A wrong filter can deny everyone.
- Use `ad` provider when you need complex LDAP filtering or integration with AD controls.

---

<br>
<br>

# 6. How to test access rules safely

1. Always keep an existing root or working session open before changing authentication rules.
2. Test identity and group membership:
```bash
getent passwd allowed_user
id allowed_user
getent group LinuxUsers
```
3. Apply rule and restart services (`systemctl restart sssd` or `systemctl restart sshd`).
4. Test login from another terminal. Use `ssh -vvv` to see debugging from client side.
5. Tail logs while testing:
```bash
tail -f /var/log/secure /var/log/sssd/sssd_pam.log /var/log/sssd/sssd_nss.log
```
6. If using SSSD filters, clear cache during tests:
```bash
sss_cache -E
```
7. If something fails, restore backups immediately.

---

<br>
<br>

# 7. Common failure scenarios and exact fixes

## Failure: allowed users are denied
- Check `getent group` and `id` for the user. If they fail, fix SSSD/DNS first.
- If using SSSD `simple_allow_groups`, ensure the exact group names are listed. Use fully qualified names if necessary.
- Check SSSD logs for `Access denied` and the reason.

Fix commands:
```bash
sssctl domain-status
sssctl user-show username
sss_cache -E
systemctl restart sssd
```

## Failure: disallowed users can still log in
- If using PAM `pam_succeed_if`, confirm you added lines to `/etc/pam.d/sshd` before `auth substack password-auth`.
- If using SSSD, ensure `access_provider` is set and SSSD restarted.

## Failure: rule works sometimes, not always
- SSSD cache delay. Use `sss_cache -E` or lower cache timeout in `sssd.conf` for testing.
- Multiple DCs with inconsistent group membership due to replication lag.

## Failure: everyone is denied after enabling SSSD filter
- Bad filter syntax. Restore backup and test simpler filters.
- DNS or SSSD misconfiguration. Verify DC reachability.

---

<br>
<br>

# 8. Logging and auditing

SSSD logs relevant messages in:
```bash
/var/log/sssd/sssd_pam.log
/var/log/sssd/sssd_DOMAIN.log
/var/log/sssd/sssd_nss.log
```

Look for:
```bash
Access denied for user
User allowed by simple_allow_groups
```

PAM/sshd logs go to:
```bash
/var/log/secure
```

For audit trails, enable `auditd` rules to capture login attempts and user changes.

---

<br>
<br>

# 9. Performance and caching considerations

SSSD caches identities and groups. This speeds up logins but can delay policy changes.

Useful commands:
```bash
sss_cache -E        # clear entire cache
sssctl user-show user    # show cached info
sssctl domain-status
```

Tuning options in `sssd.conf` (testing only):
- `entry_cache_timeout` — lower for testing
- `cache_credentials` — true/false depending on offline needs

---

<br>
<br>

# 10. Quick reference examples

Allow via PAM (sshd):
```bash
# insert before `auth substack password-auth`
auth [success=1 default=ignore] pam_succeed_if.so user ingroup "LinuxUsers|DevOps"
auth requisite pam_deny.so
```

Allow via SSSD (simple provider):
```bash
[domain/GOHEL.LOCAL]
access_provider = simple
simple_allow_groups = LinuxUsers, DevOps
```

Allow via SSSD (AD filter):
```bash
[domain/GOHEL.LOCAL]
access_provider = ad
ad_access_filter = (memberOf=CN=LinuxUsers,OU=Groups,DC=gohel,DC=local)
```

---

<br>
<br>

# 11. Final checklist before rolling to production

1. Verify AD group names via `getent group`.
2. Confirm user membership via `id username`.
3. Backup PAM and SSSD configs.
4. Apply rules on one host first and test thoroughly.
5. Monitor logs while testing.
6. Consider cache implications and use `sss_cache -E` during testing.
7. Document the change and how to revert.

---

<br>
<br>

# What you achieve after this file

You will be able to enforce group-based SSH access using PAM or SSSD reliably and safely. You will know which method to pick for each scenario, how to implement it step-by-step, how to test it without risking lockout, and how to recover quickly if something goes wrong.

This is a production-ready guide for access-control by AD groups on Linux.
