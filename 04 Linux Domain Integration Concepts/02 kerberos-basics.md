# kerberos-basics.md

- Understand what Kerberos actually does in Linux to AD authentication, how tickets work, what configuration files matter, how to test Kerberos, and how to troubleshoot it when joining Rocky Linux to AD.

---

- [kerberos-basics.md](#kerberos-basicsmd)
  - [Why Kerberos matters in Linux + AD](#why-kerberos-matters-in-linux--ad)
  - [What Kerberos actually is](#what-kerberos-actually-is)
  - [Key Distribution Center (KDC)](#key-distribution-center-kdc)
  - [Ticket Granting Ticket (TGT)](#ticket-granting-ticket-tgt)
  - [Service tickets](#service-tickets)
  - [Important Linux Kerberos files](#important-linux-kerberos-files)
  - [Testing Kerberos](#testing-kerberos)
    - [kinit](#kinit)
    - [klist](#klist)
  - [Common Kerberos failures](#common-kerberos-failures)
    - [DNS wrong](#dns-wrong)
    - [Time skew](#time-skew)
    - [Wrong default realm](#wrong-default-realm)
    - [Incorrect domain join](#incorrect-domain-join)
  - [Example failure output and meaning](#example-failure-output-and-meaning)
    - ["Cannot contact any KDC"](#cannot-contact-any-kdc)
    - ["Preauthentication failed"](#preauthentication-failed)
    - ["Clock skew too great"](#clock-skew-too-great)
  - [Kerberos logs](#kerberos-logs)
  - [Kerberos and SSSD together](#kerberos-and-sssd-together)
  - [Practical workflow after domain join](#practical-workflow-after-domain-join)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## Why Kerberos matters in Linux + AD

- AD uses Kerberos as the default authentication protocol. When a Linux machine joins AD using realm and SSSD, all authentication still goes through Kerberos in the background. If Kerberos is broken, logins fail even if realm join looks successful.

- Kerberos removes the need to send passwords again and again. Instead of sending a password every time, the client gets tickets. These tickets prove identity without exposing the password repeatedly.

- Without Kerberos, Linux cannot authenticate AD users securely.

---

<br>
<br>

## What Kerberos actually is

- Kerberos is <mark><b>an authentication protocol</b></mark> based on shared secret keys and encrypted tickets. A client proves its identity to the Domain Controller (specifically the Key Distribution Center). Once trusted, the client receives a ticket that can be presented to other services.

- Kerberos has two main parts:
  - Authentication Service (AS)
  - Ticket Granting Service (TGS)

- Both are provided by the Domain Controller.

---

<br>
<br>

## Key Distribution Center (KDC)

- A KDC is the server that manages Kerberos authentication. In AD, the Domain Controller is the KDC. When a Linux client requests authentication, it contacts the KDC.

- The KDC issues two kinds of tickets:
  - Ticket Granting Ticket (TGT)
  - Service Tickets

---

<br>
<br>

## Ticket Granting Ticket (TGT)

- A TGT proves that you authenticated successfully. After login, the client stores the TGT locally and uses it to request access to services without re-entering a password.

- Example: if I authenticate as testuser1, Kerberos issues a TGT. When testuser1 later accesses a file share or SSH service, the TGT is used to request a service ticket.

---

<br>
<br>

## Service tickets

- A service ticket allows access to a specific service. If I want to use LDAP or SSH, the TGT requests a service ticket from the KDC. The service ticket is then presented to the service.

- This prevents password exposure and reduces authentication load.

---

<br>
<br>

## Important Linux Kerberos files

- Kerberos configuration in Linux mainly lives in:

```bash
/etc/krb5.conf
```

- This file contains:
  - default realm
  - domain to realm mapping
  - KDC addresses
  - encryption types

- realm modifies this file when joining the domain.

---

<br>
<br>

## Testing Kerberos

### kinit

```bash
kinit testuser1
```

- This asks for a password and requests a TGT from the Domain Controller. If it succeeds, Kerberos is working.

- If it fails, Kerberos is broken or DNS/time is wrong.

### klist

```bash
klist
```

- This lists current tickets. After kinit, I should see a valid TGT.

Example output:

```bash
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: testuser1@GOHEL.LOCAL
```

---

<br>
<br>

## Common Kerberos failures

### DNS wrong
- Kerberos relies on correct domain DNS records. If Linux is using public DNS or incorrect DNS, kinit fails.

### Time skew
- Kerberos requires clocks to be in sync. Even a few minutes difference causes errors. I always ensure NTP is configured.

### Wrong default realm
- If `/etc/krb5.conf` points to the wrong realm, Kerberos cannot reach the KDC.

### Incorrect domain join
- If realm join partially succeeded but SSSD is not properly configured, Kerberos tests will fail.

---

<br>
<br>

## Example failure output and meaning

### "Cannot contact any KDC"
- This usually means DNS or time is wrong. Linux cannot locate the domain controller.

### "Preauthentication failed"
- This usually means a wrong password or wrong encryption setting.

### "Clock skew too great"
- Time between Linux and domain controller is not synchronized.

---

<br>
<br>

## Kerberos logs

Linux stores Kerberos logs in:
```bash
/var/log/secure
```

A lot of Kerberos-related messages appear here. I check this log when troubleshooting.

---

<br>
<br>

## Kerberos and SSSD together

- Kerberos handles authentication. SSSD performs identity lookups and coordinates Kerberos interaction. Even if Kerberos works, if SSSD is misconfigured, logins still fail.

- SSSD uses <mark><b>Kerberos for authentication</b></mark> and <mark><b>LDAP for identity data</b></mark>.

---

<br>
<br>

## Practical workflow after domain join

After joining the domain:

```bash
realm join gohel.local -U Administrator
# -U tells the command which user account I’m using to join the domain (in this case, Administrator).
```

Check Kerberos:

```bash
kinit testuser1
klist
```

Then check identity:

```bash
id testuser1
```

- If kinit works but id fails, Kerberos is fine but SSSD is broken.
- If id works but kinit fails, authentication is broken.

---

<br>
<br>

## What I achieve after this file

- By understanding Kerberos practically, I know:
  - how tickets work
  - how to test Kerberos
  - how to read krb5.conf
  - how to debug common failures

This knowledge will be critical when doing realm join troubleshooting, PAM debugging, and verifying authentication flows end-to-end.