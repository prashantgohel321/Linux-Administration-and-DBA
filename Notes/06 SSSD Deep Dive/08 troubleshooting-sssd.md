# troubleshooting-sssd.md

- In this file I am focusing only on **practical, real-world troubleshooting for SSSD**. I want predictable methods, clear commands, and a structured approach to debug any login or identity issue related to SSSD. Most problems with AD logins come from SSSD misbehavior, misconfiguration, stale cache, wrong DNS, or Kerberos issues. This file gives me a repeatable troubleshooting playbook.

---

- [troubleshooting-sssd.md](#troubleshooting-sssdmd)
- [The four main failure categories](#the-four-main-failure-categories)
- [Step 1 — Check SSSD service state](#step-1--check-sssd-service-state)
- [Step 2 — Kerberos validation (before SSSD debugging)](#step-2--kerberos-validation-before-sssd-debugging)
- [Step 3 — Identity lookup: id \& getent](#step-3--identity-lookup-id--getent)
- [Step 4 — Access control failures](#step-4--access-control-failures)
- [Step 5 — Real-time debugging workflow](#step-5--real-time-debugging-workflow)
- [Step 6 — Increase SSSD debug level](#step-6--increase-sssd-debug-level)
- [Step 7 — Test communication with AD](#step-7--test-communication-with-ad)
- [Step 8 — Validate SSSD domain configuration](#step-8--validate-sssd-domain-configuration)
- [Step 9 — Test offline authentication](#step-9--test-offline-authentication)
- [Step 10 — Check PAM stack integrity](#step-10--check-pam-stack-integrity)
- [Common failure examples and fixes](#common-failure-examples-and-fixes)
    - [1. `id testuser1` works but login fails](#1-id-testuser1-works-but-login-fails)
    - [2. Login works but wrong groups show](#2-login-works-but-wrong-groups-show)
    - [3. `id` fails but Kerberos works](#3-id-fails-but-kerberos-works)
    - [4. Kerberos fails but DNS seems fine](#4-kerberos-fails-but-dns-seems-fine)
    - [5. SSSD crashes after restart](#5-sssd-crashes-after-restart)
- [Emergency recovery](#emergency-recovery)
- [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

# The four main failure categories
All SSSD issues fall into exactly four categories:

1. SSSD is not running or crashed
2. Kerberos authentication failure
3. Identity lookup failure (NSS/SSSD)
4. Access control failure (filters, disabled accounts, wrong group)

If I diagnose them in this order, I find the issue quickly.

---

<br>
<br>

# Step 1 — Check SSSD service state

```bash
systemctl status sssd
```

If inactive, failed, or dead → fix this first.

Start or restart:
```bash
systemctl restart sssd
systemctl enable sssd
```

If SSSD fails to start, check the main log:
```bash
tail -f /var/log/sssd/sssd.log
```

Common startup issues:
- Permission errors on `/etc/sssd/sssd.conf`
- Syntax errors in sssd.conf
- Unsupported directive names

Ensure correct permissions:
```bash
chmod 600 /etc/sssd/sssd.conf
```

---

<br>
<br>

# Step 2 — Kerberos validation (before SSSD debugging)

SSSD relies on Kerberos. If Kerberos fails, authentication will fail.

Test Kerberos:
```bash
kinit testuser1
klist
```

If kinit fails:
- DNS is wrong (most common)
- Time drift > 5 mins
- Wrong domain name
- KDC unreachable
- Wrong password

Check DNS:
```bash
host dc01.gohel.local
```

Check time:
```bash
timedatectl
```

---

<br>
<br>

# Step 3 — Identity lookup: id & getent

If Kerberos works but Linux still cannot find the user:
```bash
id testuser1
```

If "no such user":
1. `sss` missing in /etc/nsswitch.conf
```bash
passwd: files sss
group:  files sss
```

2. SSSD cache stale or corrupt
```bash
sssctl cache-remove -o
systemctl restart sssd
```

3. SSSD domain misconfigured (check domain section)
```bash
tail -f /var/log/sssd/sssd_gohel.local.log
```

4. AD unreachable → test LDAP SRV
```bash
dig _ldap._tcp.gohel.local SRV
```

Also test:
```bash
getent passwd testuser1
```

getent uses NSS, so if getent fails → NSS or SSSD is the issue.

---

<br>
<br>

# Step 4 — Access control failures

Even if:
- Kerberos works
- `id` works
- SSSD runs

Login can still fail due to access control rules.

Check SSSD access logs:
```bash
tail -f /var/log/sssd/sssd_pam.log
```

Possible causes:
- ad_access_filter denies login
- account disabled in AD
- login hours restriction
- GPO restricting access

Check for lines containing:
```bash
access denied
user is not allowed
PAM_AUTH_ERR
```

---

<br>
<br>

# Step 5 — Real-time debugging workflow

Open two terminals.

Terminal 1:
```bash
tail -f /var/log/sssd/sssd_pam.log
```

Terminal 2:
```bash
su - testuser1
```

This lets me watch SSSD handle the request live.

---

<br>
<br>

# Step 6 — Increase SSSD debug level

In `/etc/sssd/sssd.conf` inside domain section:
```bash
debug_level = 9
```

Restart:
```bash
systemctl restart sssd
```

Now check logs again.

---

<br>
<br>

# Step 7 — Test communication with AD

Test LDAPS/LDAP visibility:
```bash
ldapsearch -LLL -x -H ldap://dc01.gohel.local -b "DC=gohel,DC=local"
```

If ldapsearch fails:
- firewall issue
- wrong domain base DN
- DC down
- network routing issue

---

<br>
<br>

# Step 8 — Validate SSSD domain configuration

```bash
sssctl domain-list
sssctl domain-info gohel.local
```

If domain missing or inactive → misconfigured sssd.conf.

---

<br>
<br>

# Step 9 — Test offline authentication

Disconnect from AD (disable network or DNS resolution temporarily) and test:
```bash
su - testuser1
```

If offline login works → cache ok.
If it fails → caching disabled or user never authenticated before.

---

<br>
<br>

# Step 10 — Check PAM stack integrity

Sometimes the issue is NOT SSSD but PAM.

Check for `pam_sss.so` in:
```bash
/etc/pam.d/system-auth
/etc/pam.d/password-auth
```

If missing → add them back or rejoin realm.

---

<br>
<br>

# Common failure examples and fixes

### 1. `id testuser1` works but login fails
Cause: PAM missing pam_sss.so or access_filter denying the user.

### 2. Login works but wrong groups show
Cause: stale cache → clear cache.

### 3. `id` fails but Kerberos works
Cause: NSS misconfigured or SSSD domain misconfigured.

### 4. Kerberos fails but DNS seems fine
Cause: time not in sync.

### 5. SSSD crashes after restart
Cause: wrong permissions on sssd.conf.

---

<br>
<br>

# Emergency recovery

If everything is broken and login fails:

1. Switch to console or use root
2. Disable SSSD temporarily:
```bash
systemctl stop sssd
```
3. Remove `sss` from /etc/nsswitch.conf
4. Remove pam_sss.so entries from PAM
5. Fix sssd.conf
6. Rejoin domain

This ensures you don’t get completely locked out.

---

<br>
<br>

# What I achieve after this file

- I now have a complete, practical troubleshooting playbook for SSSD. I can isolate failures, interpret logs correctly, validate each layer (Kerberos, LDAP, NSS, PAM), and quickly find the root cause of AD login issues on Linux. This makes me capable of diagnosing enterprise-level authentication problems with confidence.