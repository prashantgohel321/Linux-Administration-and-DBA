# domain-sections.md

- In this file I am going deep into the **[domain/<name>]** section inside **`sssd.conf`**. This is the most important part of SSSD configuration because this section defines exactly how SSSD communicates with AD. When something fails during authentication or identity lookup, the root cause is almost always inside this domain block.

- I am treating this file as a reference and a practical troubleshooting guide.

---

- [domain-sections.md](#domain-sectionsmd)
  - [What a domain section looks like](#what-a-domain-section-looks-like)
  - [ad\_domain](#ad_domain)
  - [id\_provider](#id_provider)
  - [auth\_provider](#auth_provider)
  - [access\_provider](#access_provider)
  - [chpass\_provider](#chpass_provider)
  - [ad\_server and kdc](#ad_server-and-kdc)
  - [use\_fully\_qualified\_names](#use_fully_qualified_names)
  - [ad\_access\_filter](#ad_access_filter)
  - [ad\_gpo\_access\_control](#ad_gpo_access_control)
  - [ad\_id\_mapping](#ad_id_mapping)
  - [fallback\_homedir](#fallback_homedir)
  - [sudo rules](#sudo-rules)
  - [Enabling SSH key retrieval (optional)](#enabling-ssh-key-retrieval-optional)
  - [Offline behavior](#offline-behavior)
  - [Testing domain configuration](#testing-domain-configuration)
  - [Restart SSSD after editing](#restart-sssd-after-editing)
  - [What breaks if this section is wrong](#what-breaks-if-this-section-is-wrong)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## What a domain section looks like

Example:
```bash
[domain/gohel.local]
ad_domain = gohel.local
id_provider = ad
auth_provider = ad
access_provider = ad
chpass_provider = ad
```

- This block defines everything from AD domain name to identity provider, authentication protocol, and access control.

---

<br>
<br>

## ad_domain

```bash
ad_domain = gohel.local
```

- This must match the AD domain exactly, case-insensitive for domain naming but the spelling must be correct. If this is wrong, SSSD will not locate domain services.

---

<br>
<br>

## id_provider

```bash
id_provider = ad
```

- This tells SSSD that identity lookup for users and groups comes from AD. If I change this to `ldap`, then SSSD expects a generic LDAP server instead of AD.

- If <mark><b>identity lookup fails</b></mark>, check this value first.

---

<br>
<br>

## auth_provider

```bash
auth_provider = ad
```

- This tells SSSD that <mark><b>authentication</b></mark> is done using AD via Kerberos. If this is changed or missing, <mark><b>password authentication will fail</b></mark> even if `id` shows the user.

---

<br>
<br>

## access_provider

```bash
access_provider = ad
```

- This enables AD based access rules, such as disabled accounts, or group-based login restrictions. If access_provider is misconfigured, users may authenticate but login may be denied.

---

<br>
<br>

## chpass_provider

```bash
chpass_provider = ad
```

- This allows users <mark><b>to change passwords via AD</b></mark> (if permitted by policy). Optional, but normally configured.

---

<br>
<br>

## ad_server and kdc

```bash
ad_server = prashantgohel.gohel.local
kdc = prashantgohel.gohel.local
```

- Normally `realm` join discovers these automatically via DNS, but specifying them can help during troubleshooting.

- If DNS discovery fails, explicitly setting these values forces SSSD to use a specific DC.

---

<br>
<br>

## use_fully_qualified_names

```bash
use_fully_qualified_names = False
```

If false, I log in with:
```bash
testuser1
```

If true, I must use:
```bash
testuser1@gohel.local
```

Short names are convenient but may cause naming conflicts with local users.

---

<br>
<br>

## ad_access_filter

```bash
ad_access_filter = "(memberOf=CN=LinuxUsers,CN=Users,DC=gohel,DC=local)"
```

- This filter <mark><b>restricts login only to members of a specific AD group</b></mark>. If someone outside the group tries to log in, access is denied.

- This is one of the most powerful ways to control who can SSH or log in to Linux.

---

<br>
<br>

## ad_gpo_access_control

```bash
ad_gpo_access_control = enforcing
```

- This enforces Windows <mark><b>Group Policy Objects</b></mark> for access decisions. It is more advanced and requires correct GPO configuration.

- For labs, access_provider based filters are easier to manage.

---

<br>
<br>

## ad_id_mapping

```bash
ad_id_mapping = true
```

- This means SSSD dynamically <mark><b>maps AD user accounts to Linux UID/GID</b></mark>. If set to false, AD must store UNIX attributes like uidNumber and gidNumber. That requires AD schema extensions or RSAT.

- Most people keep id mapping enabled.

---

<br>
<br>

## fallback_homedir

```bash
fallback_homedir = /home/%u
```

- This defines where home directories are created. `%u` expands to the login username.

---

<br>
<br>

## sudo rules

```bash
sudo_provider = ad
```

- This allows `sudo` access rules to come from AD. This is enterprise-level and not required in basic labs, but powerful for centralized administration.

---

<br>
<br>

## Enabling SSH key retrieval (optional)

```bash
ssh_service = true
ssh_provider = ad
```

- This is used if I want to store SSH keys in AD. Not common in beginner setups.

---

<br>
<br>

## Offline behavior

```bash
cache_credentials = true
entry_cache_timeout = 5400
```

- These settings make sure <mark><b>SSSD allows offline logins</b></mark> if AD is temporarily unavailable.

---

<br>
<br>

## Testing domain configuration

List domain configuration:
```bash
sssctl domain-list
```

Show domain-specific info:
```bash
sssctl domain-info gohel.local
```

Look for errors or missing services.

---

<br>
<br>

## Restart SSSD after editing

Always do:
```bash
systemctl restart sssd
```

Then check logs:
```bash
tail -f /var/log/sssd/sssd_gohel.local.log
```

This log is where domain-specific issues show up.

---

<br>
<br>

## What breaks if this section is wrong

1. identity lookup fails (id, getent fail)
2. authentication fails
3. access control blocks valid users
4. home directory not created
5. offline logins fail

Most SSSD failures come from bad settings inside this domain section.

---

<br>
<br>

## What I achieve after this file

- By understanding domain sections, I know exactly how SSSD connects to AD and applies identity, authentication, and access rules. When something goes wrong, I know which field controls which behavior and how to test and fix it practically.
