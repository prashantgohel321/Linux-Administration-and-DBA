# kerberos-validation.md

- In this file I am validating Kerberos **after** the realm join. The join might succeed, but Kerberos may still be broken due to DNS, time, or configuration issues. I want clear steps, exact commands, expected results, and what failure messages actually mean. This validation proves that authentication against the DC is genuinely working.

---

- [kerberos-validation.md](#kerberos-validationmd)
  - [Goal of validation](#goal-of-validation)
  - [Step 1: Check Kerberos configuration file](#step-1-check-kerberos-configuration-file)
  - [Step 2: Test KDC reachability using kinit](#step-2-test-kdc-reachability-using-kinit)
  - [Step 3: Validate ticket expiration times](#step-3-validate-ticket-expiration-times)
  - [Step 4: Validate service tickets](#step-4-validate-service-tickets)
  - [Step 5: Test LDAP service ticket](#step-5-test-ldap-service-ticket)
  - [Step 6: Confirm Kerberos identity matches AD user](#step-6-confirm-kerberos-identity-matches-ad-user)
  - [Common error messages and meanings](#common-error-messages-and-meanings)
    - ["Cannot contact any KDC"](#cannot-contact-any-kdc)
    - ["Clock skew too great"](#clock-skew-too-great)
    - ["Preauthentication failed"](#preauthentication-failed)
    - ["Client not found in Kerberos database"](#client-not-found-in-kerberos-database)
  - [Testing Kerberos without interactive password](#testing-kerberos-without-interactive-password)
  - [Verify SSSD and Kerberos together](#verify-sssd-and-kerberos-together)
  - [Kerberos logs on Linux](#kerberos-logs-on-linux)
  - [When Kerberos should be trusted](#when-kerberos-should-be-trusted)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## Goal of validation

After joining the domain, I must prove:
- the Linux machine can obtain a TGT (Ticket Granting Ticket)
- Kerberos service tickets work
- the KDC is reachable
- DNS SRV discovery works

If Kerberos fails here, SSH login using AD accounts will fail later.

---

<br>
<br>

## Step 1: Check Kerberos configuration file

Kerberos config lives at:
```bash
/etc/krb5.conf
```

I verify the default realm:
```bash
grep default_realm /etc/krb5.conf
```

Expected:
```bash
default_realm = GOHEL.LOCAL
```

If another realm appears or the case is wrong, Kerberos may fail.

---

<br>
<br>

## Step 2: Test KDC reachability using kinit

Try to obtain a ticket:
```bash
kinit testuser1
```

If the prompt asks for a password and returns silently, Kerberos succeeded.

Now check tickets:
```bash
klist
```

Expected output includes something like:
```bash
Default principal: testuser1@GOHEL.LOCAL
```

This confirms Kerberos authentication.

---

<br>
<br>

## Step 3: Validate ticket expiration times

```bash
klist
```

Look for:
```bash
Valid starting     Expires
```

This shows the ticket lifetime. If lifetime is extremely short or invalid, time sync might be wrong.

---

<br>
<br>

## Step 4: Validate service tickets

After obtaining a TGT, try obtaining a service ticket:
```bash
kinit -kt /etc/krb5.keytab
```

or list service tickets automatically created during login:
```bash
klist -e
```

If service tickets do not appear, AD might not be issuing them properly.

---

<br>
<br>

## Step 5: Test LDAP service ticket

Kerberos must locate the DC for LDAP. Test SRV records:
```bash
dig _ldap._tcp.gohel.local SRV
```

If no answer, DNS is wrong.

---

<br>
<br>

## Step 6: Confirm Kerberos identity matches AD user

Try:
```bash
kinit Administrator
klist
```

If Administrator gets a ticket, the DC recognises the principal format.

---

<br>
<br>

## Common error messages and meanings

### "Cannot contact any KDC"
- DNS not pointing to DC.

### "Clock skew too great"
- Time is not synchronized. Fix chrony.

### "Preauthentication failed"
- Wrong password or incorrect key settings.

### "Client not found in Kerberos database"
- User might not exist in AD or replication delay.

---

<br>
<br>

## Testing Kerberos without interactive password

If the machine keytab is set correctly:
```bash
kinit -k
```

This uses the keytab instead of asking for a password. If this works, machine authentication works fine.

Check keytab entries:
```bash
klist -k
```

Expected hostname principals like:
```bash
host/linux01.gohel.local@GOHEL.LOCAL
```

---

<br>
<br>

## Verify SSSD and Kerberos together

Even if Kerberos works, SSSD might not. Test identity mapping:
```bash
id testuser1
```

If `kinit` works but `id` fails, identity lookup is broken.

If `id` works but `kinit` fails, Kerberos is broken.

---

<br>
<br>

## Kerberos logs on Linux

Useful logs:
```bash
/var/log/secure
/var/log/messages
```

Look for KDC errors, authentication failures, clock issues.

---

<br>
<br>

## When Kerberos should be trusted

Kerberos is good when:
- kinit works for multiple users
- klist shows valid tickets
- service tickets appear
- DNS SRV lookups succeed
- time is synchronized

Only then do I consider Kerberos valid.

---

<br>
<br>

## What I achieve after this file

- By validating Kerberos immediately after join, I confirm that Linux can authenticate AD users using real Kerberos tickets. This prevents later problems in PAM, SSH, and SSSD flows, and gives confidence that authentication is functioning end-to-end.