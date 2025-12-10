# SSSD-authentication-flow.md

In this file I am explaining the actual authentication flow that happens when a user logs in on Linux after joining Active Directory. I want a clear, step-by-step, practical description of what each component does from the moment a username and password is entered until Linux decides to grant or deny access. I also want to know where to check when something breaks.

---

## The starting point: a login attempt

A user tries to log in using SSH, console login, su, or any PAM-based method. The components involved are:
1. SSHD (or login, or su)
2. PAM
3. pam_sss.so
4. SSSD (pam service)
5. Active Directory (Kerberos authentication + LDAP identity)
6. SSSD cache (possibly)

---

## Step-by-step flow

### Step 1: SSHD hands off to PAM

When a user logs in via SSH, sshd does not authenticate by itself. Instead, sshd calls PAM using the PAM configuration in:
```
/etc/pam.d/sshd
```

This file includes the stack defined in:
```
/etc/pam.d/system-auth
```

So ultimately, system-auth controls everything.

---

### Step 2: PAM processes modules in system-auth

system-auth lists modules in order. Typically:
```
auth required pam_env.so
auth sufficient pam_unix.so
auth sufficient pam_sss.so
auth required pam_deny.so
```

PAM goes one-by-one. If local pam_unix.so succeeds, it might end early. If not, it reaches pam_sss.so, which calls SSSD.

---

### Step 3: pam_sss talks to SSSD

pam_sss.so is the bridge between PAM and SSSD.
- It sends the authentication request to SSSD
- SSSD decides how to handle it
- SSSD returns allow or deny back to PAM.

---

### Step 4: SSSD checks cache first

Before talking to AD, SSSD may check cache:
- If the user authenticated recently and cache_credentials=true, SSSD can authenticate offline
- If SSSD is online, it will verify with AD

This is why offline logins are possible.

---

### Step 5: SSSD sends authentication request to AD

SSSD uses Kerberos to authenticate passwords against the Domain Controller. Under the hood:
- SSSD contacts the KDC (usually the DC)
- Attempts Kerberos pre-auth
- Validates password

If Kerberos fails, SSSD returns authentication failure.

---

### Step 6: SSSD retrieves identity from AD (LDAP)

Authentication is separate from identity lookup. Even if authentication works, SSSD still needs user details and group membership for access control. SSSD queries AD using LDAP for attributes.

If identity lookup fails, login may be denied even if password is correct.

---

### Step 7: Access control phase

SSSD applies AD-based access rules:
- Account disabled
- Login hours
- Group-based access filters
- GPO restrictions (optional)

If any rule denies access, SSSD tells PAM to reject login.

---

### Step 8: Session phase

If authentication succeeds, PAM enters the session phase. This is where:
- pam_mkhomedir.so can create home directories
- session logging happens

---

## How to trace each stage in practice

When troubleshooting a login failure, I check these in order:

1. SSHD logs
```
tail -f /var/log/secure
```

2. PAM logs (in secure)

3. SSSD logs (especially sssd_pam.log)
```
tail -f /var/log/sssd/sssd_pam.log
```

4. Kerberos test
```
kinit testuser1
klist
```

5. Identity test
```
id testuser1
```

6. getent test
```
getent passwd testuser1
```

---

## Decision points

- If kinit fails → DNS or time issue
- If id fails but kinit works → NSS or SSSD identity issue
- If id works but login fails → PAM configuration issue
- If login works but no groups → LDAP or mapping issue

Understanding these forks makes troubleshooting fast.

---

## Offline authentication path

If DC is unreachable and cache_credentials=true:
- pam_sss calls SSSD
- SSSD validates using cached credentials
- login succeeds if user logged in before

If user never logged in before, offline login fails.

---

## Complete end-to-end test

1. kinit testuser1 (tests Kerberos)
2. id testuser1 (tests SSSD identity)
3. getent passwd testuser1 (tests NSS)
4. su - testuser1 (tests PAM)
5. ssh testuser1@host (tests SSH + PAM)

Each step validates a different layer.

---

## What I achieve after this file

I have a complete picture of what actually happens during authentication flows from SSHD to PAM to SSSD to AD and back. I know where to check when something fails and how to trace each step real-time using logs and commands. This gives me real control over troubleshooting AD authentication on Linux.