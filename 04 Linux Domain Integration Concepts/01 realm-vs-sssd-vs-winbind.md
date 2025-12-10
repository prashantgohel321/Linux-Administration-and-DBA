# **`realm`**-vs-**`SSD`**-vs-**`winbind`**.md

- In this file I am comparing and explaining **`**`realm`**`**, **`**`SSD`**`**, and **`**`winbind`**`** in the context of <mark><b>joining a Linux system to AD</b></mark>. These components are often mentioned together, and it is easy to confuse their roles. I want a deep, practical explanation that helps me understand which tool is actually doing what, why each exists, and how they interact in domain integration scenarios.

- I also need to know which commands are relevant, how they behave, and what happens behind the scenes when I join Rocky Linux to AD.

---

- [**`realm`**-vs-**`SSD`**-vs-**`winbind`**.md](#realm-vs-ssd-vs-winbindmd)
  - [Why This Topic Matters](#why-this-topic-matters)
  - [What **`realm`** Is](#what-realm-is)
    - [How **`realm`** works](#how-realm-works)
  - [What **`SSD`** Is](#what-ssd-is)
    - [What **`SSD`** actually does](#what-ssd-actually-does)
  - [What **`winbind`** Is](#what-winbind-is)
  - [When To Use Which](#when-to-use-which)
    - [Use **`realm`** when](#use-realm-when)
    - [Use **`SSD`** when](#use-ssd-when)
    - [Use **`winbind`** when](#use-winbind-when)
  - [Practical Commands](#practical-commands)
    - [Discovering a domain](#discovering-a-domain)
    - [Joining the domain](#joining-the-domain)
    - [Leave the domain](#leave-the-domain)
    - [Check domain status](#check-domain-status)
  - [What **`realm`** modifies](#what-realm-modifies)
  - [How **`SSD`** caches identities](#how-ssd-caches-identities)
    - [Checking cache status](#checking-cache-status)
  - [Testing Authentication After Join](#testing-authentication-after-join)
    - [Check if AD user is visible](#check-if-ad-user-is-visible)
    - [Check ID mapping](#check-id-mapping)
    - [Test Kerberos](#test-kerberos)
    - [View tickets](#view-tickets)
  - [Common Problems](#common-problems)
    - [DNS issues](#dns-issues)
    - [Time mismatch](#time-mismatch)
    - [**`SSD`** service not running](#ssd-service-not-running)
  - [Summary](#summary)


<br>
<br>

## Why This Topic Matters

- When joining Linux to AD, several moving parts are involved. If I misunderstand the components, troubleshooting becomes extremely difficult. Many failed domain integrations happen because the administrator assumes **`realm`** performs authentication by itself or does not understand what **`SSD`** actually does.

- Understanding **`**`realm`**`**, **`**`SSD`**`**, and **`**`winbind`**`** lets me choose the right integration method and troubleshoot login issues correctly.

---

<br>
<br>

## What **`realm`** Is

- **`**`realm`**`** is a high-level tool <mark><b>used to join Linux systems to AD</b></mark>. It is <mark><b>not an authentication daemon</b></mark>. **`**`realm`**`** performs domain discovery, installs required packages, configures settings, and modifies certain system files. It simplifies the joining process.

- **`**`realm`**`** itself does not authenticate users. Instead, it configures other components like **`SSD`** so the system can authenticate against AD.

### How **`realm`** works

- When I run a command such as:

```bash
**`realm`** join gohel.local
```

- **`**`realm`**`**:
  - discovers the domain
  - checks DNS
  - contacts the Domain Controller
  - installs **`SSD`** and related packages
  - configures Kerberos
  - modifies **`/etc/**`SSD`**/**`SSD`**.conf`**
  - updates PAM and NSS

- After these steps, **`**`realm`**`** is finished. Authentication is handled by **`SSD`**.

---

<br>
<br>

## What **`SSD`** Is

- **`SSD`** stands for <mark><b>System Security Services Daemon</b></mark>. **`SSD`** is the component that actually <mark><b>performs identity lookups and authentication against AD</b></mark> once the system is joined.

- **`SSD`** communicates with AD domain controllers <mark><b>using LDAP and Kerberos</b></mark>, caches identity information, and handles offline authentication. Without **`SSD`**, **`realm`** joining would not provide authentication.

### What **`SSD`** actually does

- **`SSD`**:
  - handles user ID lookups
  - performs authentication using Kerberos
  - communicates with LDAP for directory data
  - manages caching of identity information
  - supports offline authentication

- For example, when I run:

```bash
id testuser1
```

- **`SSD`** queries AD, returns **`UID`**, **`GID`**, and **`group`** membership. The Linux system then treats that AD user as a normal Linux user.

---

<br>
<br>

## What **`winbind`** Is

- **`**`winbind`**`** is a component of Samba. Before **`SSD`** existed, **`**`winbind`**`** was <mark><b>used to integrate Linux with AD</b></mark>. It still works, but modern distributions prefer **`SSD`** because it integrates better with system services.

- **`winbind`** can still be used when Samba file sharing or older systems are involved. It provides similar capabilities to **`SSD`** but is less commonly used on enterprise Linux servers today unless Samba file sharing is required.

---

<br>
<br>

## When To Use Which

### Use **`realm`** when
- I want an easy way to join the domain
- I am using **`SSD`** as the authentication backend
- I want automatic configuration

### Use **`SSD`** when
- I need reliable authentication
- I want caching
- I want Kerberos integration
- I need clean AD integration on enterprise Linux

### Use **`winbind`** when
- dealing with Samba file services
- Samba domain members require it
- older systems depend on it

---

<br>
<br>

## Practical Commands

### Discovering a domain
```bash
realm discover gohel.local
```
- This checks if the domain is reachable and retrieves information. It confirms DNS is working.

### Joining the domain
```bash
realm join gohel.local -U Administrator
# -U tells the command which user account I’m using to join the domain (in this case, Administrator).
```

- I enter the password for the domain Administrator. **`realm`** installs packages and configures **`SSD`**.

### Leave the domain
```bash
realm leave gohel.local
```

### Check domain status
```bash
realm list
```

This shows the current domain information and confirms the system is joined.

---

<br>
<br>

## What **`realm`** modifies

**`realm`** modifies several system files:
  - **`/etc/krb5.conf`**
  - **`/etc/SSD/SSD.conf`**
  - **`/etc/nsswitch.conf`**
  - PAM configuration files

**`realm`** also pulls Kerberos configuration from the Domain Controller. DNS and time must be correct or Kerberos will fail.

---

<br>
<br>

## How **`SSD`** caches identities

- **`SSD`** stores identity information locally, so if the Domain Controller is unavailable, authentication can still happen. This is called offline authentication. It allows AD users to log in even without immediate domain controller connectivity.

### Checking cache status

```bash
sssctl domain-list
```

```bash
sssctl user-show testuser1
```

---

<br>
<br>

## Testing Authentication After Join

### Check if AD user is visible
```bash
getent passwd testuser1
```

If successful, Linux recognises the user.

### Check ID mapping
```bash
id testuser1
```

This shows UID and group membership. It proves **`SSD`** is working.

### Test Kerberos

```bash
kinit testuser1
```

If I get a ticket, Kerberos is functional.

### View tickets
```bash
klist
```

---

<br>
<br>

## Common Problems

### DNS issues
If DNS is wrong, **`realm`** discovery fails. **`SSD`** cannot find domain controllers. Authentication fails.

### Time mismatch
Kerberos requires time synchronisation. If the clock is off, authentication fails.

### **`SSD`** service not running
If **`SSD`** is not running, identity lookups and authentication fail.

```bash
systemctl status SSD
```

---

<br>
<br>

## Summary

- **`realm`** joins the domain, configures things, and then stops
- **`SSD`** actually performs authentication and identity lookup
- **`winbind`** is older and used mainly with Samba

**`SSD`** is the modern and preferred approach for enterprise Linux AD integration.

Understanding this separation allows me to troubleshoot correctly and analyse failures logically.
