# deny-groups.md

This file explains how to **deny SSH (and other) access to users who belong to specific AD groups**. The goal is practical: exact configurations, commands to apply, tests to run, and precise troubleshooting steps for every real failure you will meet in a VMware lab with Rocky Linux and Windows Server 2022 AD.

This file covers three reliable approaches you will use in real environments: host-level PAM denial, SSSD-based denial, and LDAP filter denial. Each approach includes exact configuration snippets, testing commands, caveats, and recovery steps.

---

# Why deny groups instead of allow lists

Deny lists are useful when you have a small number of groups that should never have access (contractors, service accounts, blocked users). They are faster to maintain in some environments and provide an explicit blacklist in addition to allow lists.

Deny rules should be used carefully — a mistake can accidentally block administrators. Always test on a single host first and keep a root console open.

---

# Two main strategies

1. Host-level denial using PAM (fast, immediate, per-host)
2. Centralized denial using SSSD (`simple_deny_groups` or `ad_access_filter`) — recommended for many hosts

A third option is to combine both for defense-in-depth.


---

# Strategy A — Deny groups using PAM (sshd-specific)

This places an early test in the SSH PAM stack to deny members of specific groups before the rest of the authentication stack runs.

## Use case
Deny members of `Contractors` and `ServiceAccounts` AD groups from SSH on a host.

## Exact steps (commands)

1. Verify AD group names visible on the host:
```
getent group Contractors
getent group ServiceAccounts
```
If groups are shown with domain suffixes, note the exact string returned.

2. Backup SSH PAM config:
```
cp /etc/pam.d/sshd /root/sshd.pam.bak-$(date +%F-%T)
```

3. Edit `/etc/pam.d/sshd` and add the denial lines **before** `auth substack password-auth` (deny early):

```
# deny members of Contractors and ServiceAccounts
auth [default=die] pam_succeed_if.so user ingroup "Contractors|ServiceAccounts"
auth requisite pam_deny.so
```

Explanation:
- `pam_succeed_if.so` returns success when user is in either group. The control `[default=die]` is strict: if the test returns default (i.e., group membership cannot be determined) PAM will stop. Use this carefully.
- `pam_deny.so` denies if the previous test did not short-circuit.

A safer variant (less risky if NSS is unreliable):
```
# safer: deny only if success (user is in deny groups); otherwise continue
auth [success=1 default=ignore] pam_succeed_if.so user ingroup "Contractors|ServiceAccounts"
auth requisite pam_deny.so
```
This ensures that the next rule is skipped only when the user is in deny groups; otherwise normal authentication proceeds.

4. Test from a second terminal as an allowed user and as a denied user:
```
ssh -vvv allowed_user@server
ssh -vvv denied_user@server
```

5. Monitor logs live:
```
tail -f /var/log/secure /var/log/sssd/sssd_pam.log
```
Look for `pam_succeed_if` and `pam_deny` messages.

6. Recovery (if you lock out admins):
```
cp /root/sshd.pam.bak-* /etc/pam.d/sshd
systemctl restart sshd
```
Use VM console if SSH is locked out.

## Caveats and tips
- `pam_succeed_if` uses NSS. If `id denied_user` fails, the test cannot determine group membership. Use the safer variant in unreliable environments.
- Exact group names matter. If `getent group` returns `Contractors@GOHEL.LOCAL`, use that string.
- Avoid `default=die` unless you are 100% sure NSS will always work.

---

# Strategy B — Deny groups using SSSD `simple_deny_groups` (recommended for many hosts)

SSSD supports a simple deny list which is evaluated after identity lookup. This centralizes denial in one location per host (sssd.conf) and is preferable when you manage many machines.

## Use case
Deny `Contractors` and `ServiceAccounts` across all hosts using the same `sssd.conf` template.

## Exact sssd.conf snippet (domain section)

```
[domain/GOHEL.LOCAL]
# existing config ...
access_provider = simple
simple_deny_groups = Contractors, ServiceAccounts
# If sssd returns FQDN group names, use those exact names:
# simple_deny_groups = "Contractors@gohel.local,ServiceAccounts@gohel.local"
```

## Steps (commands)

1. Backup and edit `/etc/sssd/sssd.conf`:
```
cp /etc/sssd/sssd.conf /root/sssd.conf.bak-$(date +%F-%T)
chmod 600 /root/sssd.conf.bak-*
# edit file with nano/vi and add simple_deny_groups under domain section
```

2. Restart SSSD:
```
systemctl restart sssd
systemctl status sssd
```

3. Clear SSSD cache and test:
```
sss_cache -E
getent passwd denied_user
ssh denied_user@server  # should be denied
ssh allowed_user@server # should be allowed
```

4. Check SSSD logs:
```
tail -f /var/log/sssd/sssd_pam.log /var/log/sssd/sssd_DOMAIN.log
```
Look for `Access denied for user` lines.

## Advantages
- Centralized control (useful for fleet management)
- Clear SSSD logging
- Easy to deploy via configuration management tools

## Caveats
- SSSD caching may delay enforcement; use `sss_cache -E` during tests or adjust `entry_cache_timeout` for faster propagation (testing only).
- If NSS cannot resolve the group names, SSSD cannot evaluate the deny list; ensure `getent group` returns expected names.

---

# Strategy C — Deny groups using AD filters (`ad_access_filter`) (most powerful)

Use LDAP filters to make complex denial rules. This is appropriate when filters depend on OU membership, attribute values, or nested group rules.

## Example
Deny users who are members of `CN=Contractors,OU=External,DC=gohel,DC=local`:

```
[domain/GOHEL.LOCAL]
access_provider = ad
ad_access_filter = (!(memberOf=CN=Contractors,OU=External,DC=gohel,DC=local))
```

Note: This example is written as a deny filter inverted into allow; ad_access_filter selects users who match the filter — invert logic accordingly.

## Steps

1. Backup `/etc/sssd/sssd.conf`.
2. Add the filter under the domain section.
3. Restart SSSD:
```
systemctl restart sssd
sssctl domain-status
```
4. Test with `sssctl user-show denied_user` and `ssh denied_user@server`.

## Caveats
- LDAP filters are powerful but dangerous. A malformed filter can deny everyone.
- Test filters with `ldapsearch` or AD tools before deploying.
- `access_provider = ad` changes how SSSD uses AD; use with caution.

---

# Additional host-level option — `pam_listfile` to deny by file

You can also deny based on a local file of usernames using `pam_listfile`. This is useful for temporary manual blocks.

Example `/etc/ssh/denied_users.txt` contains:
```
user1
user2
contractor1
```

Add to `/etc/pam.d/sshd` before `auth substack password-auth`:

```
auth required pam_listfile.so item=user sense=deny file=/etc/ssh/denied_users.txt onerr=succeed
```

`onerr=succeed` is safer: if the file cannot be read, PAM will allow authentication (avoid lockout).

Test by adding a username to the file and attempting login.

---

# Testing and verification checklist

1. Confirm group names and membership:
```
getent group Contractors
id denied_user
```

2. Apply rule on one test host first.
3. Clear cache:
```
sss_cache -E
```
4. Test SSH login (allowed and denied users):
```
ssh -vvv allowed_user@server
ssh -vvv denied_user@server
```
5. Monitor logs:
```
tail -f /var/log/secure /var/log/sssd/sssd_pam.log /var/log/sssd/sssd_nss.log
```
6. If using PAM, verify `/etc/pam.d/sshd` contains your new lines and they appear before `auth substack password-auth`.

---

# Common failure scenarios and fixes

## Failure: Denied users are still able to log in
- Check exact group name returned by `getent`. Use that string in config.
- SSSD cache not refreshed. Run `sss_cache -E` or restart SSSD.
- PAM rule placed after `auth substack password-auth` — move it earlier.

## Failure: Allowed users are denied unexpectedly
- Check PAM control flags; `[default=die]` is risky and can deny when NSS resolution fails. Use the safer `[success=1 default=ignore]` variant.
- Bad LDAP filter in `ad_access_filter` may deny everyone. Restore backup and test simpler filters.

## Failure: Everyone is denied after applying SSSD filter
- Immediately revert `/etc/sssd/sssd.conf` from backup using VM console.
- Check SSSD logs for parse errors. Correct filter syntax.

## Failure: `pam_listfile` denies despite file missing
- Check file path and permissions. If `onerr` is not set to `succeed`, PAM may fail open/closed depending on your setting.

---

# Audit and logging

To track denied logins, monitor:
```
/var/log/secure
/var/log/sssd/sssd_pam.log
/var/log/sssd/sssd_DOMAIN.log
```
Look for entries containing `Access denied` or `pam_deny`.

For longer-term audit, configure `auditd` rules to log `sshd` authentication attempts.

---

# Rollout and best practices

- Test on one host, then roll to a small group.
- Use configuration management (Ansible, Salt) to deploy sssd.conf changes.
- Prefer SSSD `simple_deny_groups` or `ad_access_filter` for fleet-wide policies.
- Use PAM denial only for host-specific emergency blocks or quick tests.
- Keep `sss_cache -E` handy for testing.
- Always keep VM console/alternative access before applying deny rules.

---

# What you achieve after this file

You will be able to:
- implement deny-by-group policies using PAM, SSSD, or LDAP filters
- test and verify deny rules safely in a lab environment
- troubleshoot common failures and recover quickly
- choose the right method (host vs centralized) for your environment

This document gives you production-ready deny-group controls that integrate with AD and SSSD and can be used across fleets of Linux hosts.
