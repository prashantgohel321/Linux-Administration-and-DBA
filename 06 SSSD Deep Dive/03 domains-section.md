# domain-sections.md

In this file I am going deep into the **[domain/<name>]** section inside sssd.conf. This is the most important part of SSSD configuration because this section defines exactly how SSSD communicates with Active Directory. When something fails during authentication or identity lookup, the root cause is almost always inside this domain block.

I am treating this file as a reference and a practical troubleshooting guide.

---

## What a domain section looks like

Example:
```
[domain/gohel.local]
ad_domain = gohel.local
id_provider = ad
auth_provider = ad
access_provider = ad
chpass_provider = ad
```

This block defines everything from AD domain name to identity provider, authentication protocol, and access control.

---

## ad_domain

```
ad_domain = gohel.local
```

This must match the Active Directory domain exactly, case-insensitive for domain naming but the spelling must be correct. If this is wrong, SSSD will not locate domain services.

---

## id_provider

```
id_provider = ad
```

This tells SSSD that identity lookup for users and groups comes from AD. If I change this to `ldap`, then SSSD expects a generic LDAP server instead of AD.

If identity lookup fails, check this value first.

---

## auth_provider

```
auth_provider = ad
```

This tells SSSD that authentication is done using Active Directory via Kerberos. If this is changed or missing, password authentication will fail even if `id` shows the user.

---

## access_provider

```
access_provider = ad
```

This enables Active Directory based access rules, such as disabled accounts, or group-based login restrictions. If access_provider is misconfigured, users may authenticate but login may be denied.

---

## chpass_provider

```
chpass_provider = ad
```

This allows users to change passwords via AD (if permitted by policy). Optional, but normally configured.

---

## ad_server and kdc

```
ad_server = dc01.gohel.local
kdc = dc01.gohel.local
```

Normally realm join discovers these automatically via DNS, but specifying them can help during troubleshooting.

If DNS discovery fails, explicitly setting these values forces SSSD to use a specific Domain Controller.

---

## use_fully_qualified_names

```
use_fully_qualified_names = False
```

If false, I log in with:
```
testuser1
```

If true, I must use:
```
testuser1@gohel.local
```

Short names are convenient but may cause naming conflicts with local users.

---

## ad_access_filter

```
ad_access_filter = "(memberOf=CN=LinuxUsers,CN=Users,DC=gohel,DC=local)"
```

This filter restricts login only to members of a specific AD group. If someone outside the group tries to log in, access is denied.

This is one of the most powerful ways to control who can SSH or log in to Linux.

---

## ad_gpo_access_control

```
ad_gpo_access_control = enforcing
```

This enforces Windows Group Policy Objects for access decisions. It is more advanced and requires correct GPO configuration.

For labs, access_provider based filters are easier to manage.

---

## ad_id_mapping

```
ad_id_mapping = true
```

This means SSSD dynamically maps AD user accounts to Linux UID/GID. If set to false, AD must store UNIX attributes like uidNumber and gidNumber. That requires AD schema extensions or RSAT.

Most people keep id mapping enabled.

---

## fallback_homedir

```
fallback_homedir = /home/%u
```

This defines where home directories are created. `%u` expands to the login username.

---

## sudo rules

```
sudo_provider = ad
```

This allows sudo access rules to come from AD. This is enterprise-level and not required in basic labs, but powerful for centralized administration.

---

## Enabling SSH key retrieval (optional)

```
ssh_service = true
ssh_provider = ad
```

This is used if I want to store SSH keys in AD. Not common in beginner setups.

---

## Offline behavior

```
cache_credentials = true
entry_cache_timeout = 5400
```

These settings make sure SSSD allows offline logins if AD is temporarily unavailable.

---

## Testing domain configuration

List domain configuration:
```
sssctl domain-list
```

Show domain-specific info:
```
sssctl domain-info gohel.local
```

Look for errors or missing services.

---

## Restart SSSD after editing

Always do:
```
systemctl restart sssd
```

Then check logs:
```
tail -f /var/log/sssd/sssd_gohel.local.log
```

This log is where domain-specific issues show up.

---

## What breaks if this section is wrong

1. identity lookup fails (id, getent fail)
2. authentication fails
3. access control blocks valid users
4. home directory not created
5. offline logins fail

Most SSSD failures come from bad settings inside this domain section.

---

## What I achieve after this file

By understanding domain sections, I know exactly how SSSD connects to AD and applies identity, authentication, and access rules. When something goes wrong, I know which field controls which behavior and how to test and fix it practically.
