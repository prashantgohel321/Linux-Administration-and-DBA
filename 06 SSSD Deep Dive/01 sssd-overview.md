# sssd-overview.md

know exactly:
- what SSSD is
- what problems it solves
- what processes it runs
- how it talks to AD
- how it interacts with NSS and PAM
- how to check if it is actually working

This understanding is critical, because after the domain join, **SSSD is the main engine** behind AD logins on Linux.

---

- [sssd-overview.md](#sssd-overviewmd)
  - [What SSSD actually is](#what-sssd-actually-is)
  - [Where SSSD fits in the stack](#where-sssd-fits-in-the-stack)
  - [Key SSSD files](#key-sssd-files)
  - [SSSD services](#sssd-services)
  - [SSSD domains](#sssd-domains)
  - [How SSSD caches data](#how-sssd-caches-data)
  - [How to check if SSSD is running](#how-to-check-if-sssd-is-running)
  - [Testing SSSD identity resolution](#testing-sssd-identity-resolution)
    - [`id` command](#id-command)
    - [`getent` command](#getent-command)
  - [SSSD and NSS](#sssd-and-nss)
  - [SSSD and PAM](#sssd-and-pam)
  - [SSSD and Kerberos](#sssd-and-kerberos)
  - [Useful SSSD commands](#useful-sssd-commands)
    - [List domains known to SSSD](#list-domains-known-to-sssd)
    - [Show information about a user](#show-information-about-a-user)
    - [Clear SSSD cache (for testing)](#clear-sssd-cache-for-testing)
  - [SSSD logs for troubleshooting](#sssd-logs-for-troubleshooting)
  - [Typical SSSD-related failure scenarios](#typical-sssd-related-failure-scenarios)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## What SSSD actually is

- SSSD stands for <mark><b>System Security Services Daemon</b></mark>. It is a background service (daemon) that provides:
  - identity lookup (users, groups)
  - authentication (via Kerberos)
  - caching of identity and credential information
  - integration with enterprise directories like AD, LDAP, FreeIPA

- <mark><b>SSSD sits between my Linux system and external identity sources</b></mark>. When Linux needs to know who I am or whether my password is valid, SSSD checks with AD and gives the answer.

- SSSD isn’t one single program doing everything; it’s a set of components working together, each handling different parts of the identity process.

---

<br>
<br>

## Where SSSD fits in the stack

From a high-level view:

1. A user tries to log in (SSH, console, su, etc.).
2. PAM handles the authentication flow and calls `pam_sss.so`.
3. `pam_sss.so` talks to the SSSD daemon.
4. SSSD talks to the remote directory (AD) using LDAP and Kerberos.
5. SSSD returns success/failure to PAM.
6. NSS (Name Service Switch) may call `sss` to resolve user and group information.

So SSSD integrates with:
- PAM via `pam_sss.so`
- NSS via the `sss` entry in `/etc/nsswitch.conf`

Without SSSD, the system could not resolve AD users or validate their logins.

![alt text](<../Diagrams/SSSD Auth Flow.png>)

---

<br>
<br>

## Key SSSD files

Main configuration:
```bash
/etc/sssd/sssd.conf
```

The config file defines:
- which domains SSSD knows
- which services are enabled (nss, pam, sudo, etc.)
- how to connect to AD (servers, schema, options)
- caching settings

<br>
<details>
<summary><b>NSS (Name Server Switch)</b></summary>
<br>

- NSS decides where my system looks up user and group information (and other name lookups). It tells Linux whether to check local files, LDAP, SSSD, etc., when it needs identity or name info.

</details>
<br>

SSSD logs:
```bash
/var/log/sssd/
```

Inside this directory there are domain-specific logs like:
- `sssd.log`
- `sssd_nss.log`
- `sssd_pam.log`
- `sssd_$(domain).log`

These logs are essential for troubleshooting.

---

<br>
<br>

## SSSD services

SSSD runs multiple internal services. These are configured in the `services` section of `sssd.conf`.

Typical services:
- `nss` – provides user/group info to the system
- `pam` – handles authentication requests from PAM
- `sudo` – can provide sudo rules from directory (if used)
- `ssh` – can provide SSH keys from directory (if used)

If `nss` or `pam` are missing from the services list, AD logins will fail.

---

<br>
<br>

## SSSD domains

- A **domain** in SSSD configuration is not the same as an AD domain, but it usually maps to one. In `sssd.conf`, each `[domain/<name>]` section defines how to talk to a specific identity source.

- When I join `gohel.local`, realm usually creates a section like:

```bash
[domain/gohel.local]
```

- This section controls:
  - `id_provider = ad`
  - `auth_provider = ad`
  - servers and backup servers
  - access control rules
  - how to map UIDs/GIDs

---

<br>
<br>

## How SSSD caches data

- SSSD caches user and group information locally. That means:
  - first time `id testuser1` is run, SSSD queries AD
  - SSSD stores the result in its local cache
  - subsequent calls are faster and work even if AD is temporarily unavailable

- Caching also allows **offline logins**. If a user has logged in before, and the DC is down, SSSD can still allow login using cached credentials.

- This is controlled by cache settings in `sssd.conf`, such as `entry_cache_timeout`.

---

<br>
<br>

## How to check if SSSD is running

- Basic check:
```bash
systemctl status sssd
```

If it is not active and running, no AD logins will work, even if realm join succeeded.

To start and enable:
```bash
systemctl enable sssd
systemctl start sssd
```

---

<br>
<br>

## Testing SSSD identity resolution

Once joined and SSSD running, I test identity lookups.

### `id` command

```bash
id testuser1
```

If everything works, I should see output like:

```bash
uid=123456789(testuser1@gohel.local) gid=123456789(domain users@gohel.local) groups=...
```

- If I get "no such user", either SSSD is not configured correctly, SSSD is not running, or there is a communication issue with AD.

### `getent` command

```bash
getent passwd testuser1
```

This uses NSS, which calls the `sss` module to ask SSSD about the user. If a line appears, SSSD served the information.

---

<br>
<br>

## SSSD and NSS

The file `/etc/nsswitch.conf` tells Linux where to look for users and groups. For AD integration, `passwd` and `group` lines must include `sss`, for example:

```bash
passwd:     files sss
group:      files sss
```

- `files` means local `/etc/passwd`. `sss` means SSSD.

- If `sss` is missing, `id` and `getent` will not show AD users even if SSSD is working.

---

<br>
<br>

## SSSD and PAM

- PAM modules handle authentication. The module `pam_sss.so` passes authentication requests to SSSD.

- In `/etc/pam.d/system-auth` and `/etc/pam.d/password-auth`, I expect to see lines like:

```bash
auth        sufficient    pam_sss.so
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
password    sufficient    pam_sss.so
session     optional      pam_sss.so
```

If these are missing, PAM never calls SSSD, so AD logins fail.

---

<br>
<br>

## SSSD and Kerberos

- SSSD does not replace Kerberos. It uses Kerberos for authentication. When PAM asks SSSD to authenticate a user, SSSD:
  - talks to the KDC (DC) using Kerberos
  - verifies the password
  - may obtain tickets

- If Kerberos is misconfigured, SSSD will log errors and deny access.

---

<br>
<br>

## Useful SSSD commands

- SSSD provides a useful tool `sssctl`.

### List domains known to SSSD
```bash
sssctl domain-list
```

### Show information about a user
```bash
sssctl user-show testuser1
```

### Clear SSSD cache (for testing)

To clear all cached data:
```bash
sssctl cache-remove -o
systemctl restart sssd
```

- Sometimes old cache entries cause confusing results. Clearing cache forces fresh queries to AD.

---

<br>
<br>

## SSSD logs for troubleshooting

SSSD logs live in `/var/log/sssd`. Common files:

- `sssd.log` – main log
- `sssd_pam.log` – PAM-related events
- `sssd_nss.log` – NSS-related events
- `sssd_gohel.local.log` – domain-specific issues

When a login fails, I always check `sssd_pam.log` to see why SSSD denied access.

Example:
```bash
tail -f /var/log/sssd/sssd_pam.log
```

Then attempt a login and watch the logs.

---

<br>
<br>

## Typical SSSD-related failure scenarios

1. **SSSD not running**  
   - `systemctl status sssd` shows inactive
   - Fix: start and enable SSSD

2. **NSS not configured for sss**  
   - `getent passwd testuser1` returns nothing  
   - Fix: add `sss` to `passwd` and `group` in `/etc/nsswitch.conf`

3. **PAM not configured for pam_sss**  
   - `id testuser1` works, but login fails  
   - Fix: add `pam_sss.so` lines to system-auth/password-auth

4. **Kerberos failure underneath**  
   - SSSD logs show KDC errors  
   - Fix: check DNS, time sync, `kinit` tests

5. **Access control rules in SSSD**  
   - `access_provider = ad` with restrictions  
   - Some users denied based on group membership  
   - Fix: adjust `ad_access_filter` or related options

---

<br>
<br>

## What I achieve after this file

By understanding SSSD at this level, I know:
- where it sits in the authentication stack
- which files and services it uses
- how it integrates with NSS and PAM
- how to test its functionality
- where to look when AD users cannot log in

This overview is the base. The next SSSD files will go deeper into `sssd.conf` sections, domains, services, caching, and troubleshooting in more detail.