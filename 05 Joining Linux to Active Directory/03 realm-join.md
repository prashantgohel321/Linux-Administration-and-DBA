# realm-join.md

- In this file I am performing the actual join operation of Rocky Linux to AD using `realm join`. This is where most people hit errors because they skip DNS checks, Kerberos checks, and time configuration. I want to handle every common scenario, include every command, and understand exactly what happens behind the scenes.

---

- [realm-join.md](#realm-joinmd)
  - [Preconditions I must already have working](#preconditions-i-must-already-have-working)
  - [Basic join command](#basic-join-command)
  - [What realm join actually does](#what-realm-join-actually-does)
  - [Joining with UPN username format](#joining-with-upn-username-format)
  - [Join with verbose debugging](#join-with-verbose-debugging)
  - [Verify join](#verify-join)
  - [Check AD computer object](#check-ad-computer-object)
  - [Test identity lookup](#test-identity-lookup)
  - [Test home directory creation](#test-home-directory-creation)
  - [Test Kerberos after join](#test-kerberos-after-join)
  - [Common failure: "Cannot contact KDC"](#common-failure-cannot-contact-kdc)
  - [Common failure: "Clock skew too great"](#common-failure-clock-skew-too-great)
  - [Common failure: "Client not found in Kerberos database"](#common-failure-client-not-found-in-kerberos-database)
  - [Restart SSSD](#restart-sssd)
  - [Leave domain if something broke](#leave-domain-if-something-broke)
  - [Typical workflow](#typical-workflow)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## Preconditions I must already have working

Before running `realm join`, ALL of the following must be correct:

- DNS points to the DC
- Kerberos can obtain a ticket using kinit
- Time is synchronized
- SSSD running
- oddjobd running
- domain discovery succeeds

If any of these are broken, `realm join` will either fail or succeed partially and authentication will break later.

---

<br>
<br>

## Basic join command

```bash
realm join gohel.local -U Administrator
```

It asks for the domain Administrator password. Do not use a normal domain user here.

---

<br>
<br>

## What realm join actually does

When I run this command, realm:
- contacts the domain
- performs Kerberos authentication
- configures SSSD
- updates `/etc/sssd/sssd.conf`
- updates `/etc/krb5.conf`
- updates `/etc/nsswitch.conf`
- updates PAM
- registers the computer in AD

All of these steps must succeed.

---

<br>
<br>

## Joining with UPN username format

Sometimes using the UPN format helps:
```bash
realm join gohel.local -U Administrator@gohel.local
```

---

<br>
<br>

## Join with verbose debugging

```bash
realm join -vv gohel.local -U Administrator
```

This prints detailed debugging information. Very useful when something fails.

---

<br>
<br>

## Verify join

After running join, check status:
```bash
realm list
```

Expected output should show:
- domain name
- configured: kerberos-member
- AD software
- sssd enabled

If configured: no → join failed.

---

<br>
<br>

## Check AD computer object

- On the DC, open AD Users and Computers and check under Computers. A computer object should exist with the Linux hostname.

- If it does not appear, join failed or AD write permissions failed.

---

<br>
<br>

## Test identity lookup

Now that joined, test ID mapping:
```bash
id testuser1
```

If it prints UID, GID, and groups, then SSSD resolved the user.

If it fails, SSSD is not working or caches are stale.

---

<br>
<br>

## Test home directory creation

```bash
su - testuser1@gohel.local
```

- If oddjobd is running and PAM is configured correctly, a home directory should be created.

- If home directory not created, ensure oddjobd is running and oddjob-mkhomedir is installed.

---

<br>
<br>

## Test Kerberos after join

```bash
kinit testuser1
klist
```

This ensures Kerberos authentication works.

---

<br>
<br>

## Common failure: "Cannot contact KDC"

- This usually means DNS is not pointing to DC. Fix DNS and retry.

---

<br>
<br>

## Common failure: "Clock skew too great"

- Fix NTP. Restart chronyd, then retry.

---

<br>
<br>

## Common failure: "Client not found in Kerberos database"

- This can happen if the user does not exist or AD replication has delay. Test with Administrator.

---

<br>
<br>

## Restart SSSD

- After join, I always restart SSSD:
```bash
systemctl restart sssd
```

- SSSD reloads domain configuration.

---

<br>
<br>

## Leave domain if something broke

```bash
realm leave gohel.local
```

- Then fix DNS/time and try again.

---

<br>
<br>

## Typical workflow

1. DNS set to DC
2. kinit Administrator
3. realm discover gohel.local
4. realm join gohel.local -U Administrator
5. restart sssd
6. id testuser1
7. su - testuser1
8. kinit testuser1

If these all work, join is successful.

---

<br>
<br>

## What I achieve after this file

- By performing and verifying the join, I know Linux is now part of the AD domain, SSSD is configured, Kerberos is working, and user authentication should function. This prepares me for deeper understanding of PAM, SSSD, and full authentication flows.