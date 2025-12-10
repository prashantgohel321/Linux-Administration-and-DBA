# sssd.conf-detailed.md

- The **sssd.conf** file explanation line by line in a practical way. I want to understand every important directive, why it exists, how it affects authentication, and what happens if it is wrong. This is the core configuration file for SSSD and directly controls identity lookup, authentication, and access control on Linux when joined to Active Directory.

---

- [sssd.conf-detailed.md](#sssdconf-detailedmd)
  - [Location and permissions](#location-and-permissions)
  - [Basic structure](#basic-structure)
  - [\[sssd\] section explained](#sssd-section-explained)
  - [Domain section explained](#domain-section-explained)
  - [Servers and lookup:](#servers-and-lookup)
  - [Access control](#access-control)
  - [Enumeration (optional and expensive)](#enumeration-optional-and-expensive)
  - [Fallback servers](#fallback-servers)
  - [Offline logins](#offline-logins)
  - [Case sensitivity](#case-sensitivity)
  - [Group and UID mapping](#group-and-uid-mapping)
  - [Forcing short names](#forcing-short-names)
  - [Enabling sudo integration](#enabling-sudo-integration)
  - [Restart SSSD after changes](#restart-sssd-after-changes)
  - [Validate domain configuration](#validate-domain-configuration)
    - [Show user details](#show-user-details)
  - [Troubleshooting tips](#troubleshooting-tips)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## Location and permissions

The file is located at:
```bash
/etc/sssd/sssd.conf
```

It must have strict permissions:
```bash
chmod 600 /etc/sssd/sssd.conf
```

If the permissions are wrong, SSSD may refuse to start.

---

<br>
<br>

## Basic structure

A typical sssd.conf created by realm has the following structure:

```bash
[sssd]
services = nss, pam
config_file_version = 2
domains = gohel.local

[domain/gohel.local]
id_provider = ad
auth_provider = ad
chpass_provider = ad
access_provider = ad

[domain/gohel.local]
... other options ...
```

There are two main sections:
- `[sssd]` – general settings
- `[domain/<name>]` – configuration for each identity source

---

<br>
<br>

## [sssd] section explained

```
[sssd]
services = nss, pam
```

- This tells SSSD which internal services to run. `nss` handles identity lookup and `pam` handles authentication. If these are missing, AD logins fail.

```bash
domains = gohel.local
```

This defines which domain sections SSSD should load. If the domain name here does not match the domain section below, SSSD will not process that configuration.

```
config_file_version = 2
```

Version of the config syntax. Usually left as is.

---

<br>
<br>

## Domain section explained

Example:
```
[domain/gohel.local]
id_provider = ad
auth_provider = ad
chpass_provider = ad
access_provider = ad
```

These directives tell SSSD that Active Directory provides identity, authentication, password changes, and access control.

If `id_provider = ad` is missing, SSSD cannot fetch user/group information.
If `auth_provider = ad` is missing, password validation fails.

---

<br>
<br>

## Servers and lookup:

```bash
ad_domain = gohel.local
# Specifies the AD domain. This must match your actual domain.
```


```bash
ad_server = dc01.gohel.local
# Specifies which DC to use. Often optional because SSSD discovers DCs automatically using DNS.
```


```bash
kdc = dc01.gohel.local
# Specifies Kerberos KDC. Again, can be discovered via DNS.
```


---

<br>
<br>

## Access control

```
access_provider = ad
```

This allows AD to enforce access rules, such as disabled accounts and login restrictions.

I can also enforce group-based access using:
```
ad_access_filter = "(memberOf=CN=LinuxUsers,CN=Users,DC=gohel,DC=local)"
```

If specified, only users matching this filter can log in.

---

<br>
<br>

## Enumeration (optional and expensive)

```
enumerate = false
```

If set to true, SSSD tries to download all users/groups at startup. This is slow and usually disabled in enterprise environments.

---

<br>
<br>

## Fallback servers

```
ad_backup_server = dc02.gohel.local
```

If you have a second DC, you can list it here.

---

<br>
<br>

## Offline logins

SSSD cache allows logins when DC is unreachable. Timeout values are controlled by options such as:
```
cache_credentials = true
entry_cache_timeout = 5400
```

Users who logged in recently can authenticate without DC.

---

<br>
<br>

## Case sensitivity

```
default_shell = /bin/bash
fallback_homedir = /home/%u
```

Specifies default shell and home directory template. `%u` expands to username.

---

<br>
<br>

## Group and UID mapping

SSSD dynamically maps domain users to Linux UIDs and GIDs. This can be customized using:
```
ad_id_mapping = true
```

If disabled, you must manually configure UID/GID attributes in AD.

---

<br>
<br>

## Forcing short names

```
use_fully_qualified_names = False
```

If false:
```
testuser1
```

If true:
```
testuser1@gohel.local
```

Short names are convenient but may conflict with local users.

---

<br>
<br>

## Enabling sudo integration

```
sudo_provider = ad
```

This lets SSSD fetch sudo rules from AD (advanced enterprise use).

---

<br>
<br>

## Restart SSSD after changes

Every time I modify sssd.conf:
```
systemctl restart sssd
```

Check logs for errors:
```
tail -f /var/log/sssd/sssd.log
```

---

<br>
<br>

## Validate domain configuration

```
sssctl domain-list
```

If the domain does not show, SSSD is not loading the config.

### Show user details
```
sssctl user-show testuser1
```

This confirms identity lookup and authentication.

---

<br>
<br>

## Troubleshooting tips

- If SSSD refuses to start, check permissions on sssd.conf
- If AD users are not resolvable, check id_provider and nss configuration
- If authentication fails, check auth_provider and Kerberos settings
- If users are denied access, check access_provider and filters
- If logins work once and fail later, inspect cache and offline settings

---

<br>
<br>

## What I achieve after this file

By understanding sssd.conf in detail, I know exactly how SSSD talks to Active Directory, where to configure identity lookup, authentication, and access control, and how to modify the file safely. This prepares me for debugging real authentication problems in enterprise environments.