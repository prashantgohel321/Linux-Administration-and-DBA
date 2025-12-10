# realm-discover.md

- In this file I am using `realm discover` to check if my Rocky Linux machine can actually see the AD domain before trying to join it. I need to understand what realm discovery does, what it checks, how to interpret the output, and what to do when it fails. This step prevents wasting time on failed joins.

---

- [realm-discover.md](#realm-discovermd)
  - [What `realm discover` actually does](#what-realm-discover-actually-does)
  - [Practical DNS checks before discovery](#practical-dns-checks-before-discovery)
  - [Running domain discovery](#running-domain-discovery)
  - [Meaning of important fields](#meaning-of-important-fields)
  - [If discovery fails](#if-discovery-fails)
  - [Verbose discovery](#verbose-discovery)
  - [Confirming Kerberos works before joining](#confirming-kerberos-works-before-joining)
  - [Confirm SSSD is ready](#confirm-sssd-is-ready)
  - [Typical troubleshooting workflow](#typical-troubleshooting-workflow)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## What `realm discover` actually does

- `realm discover` performs domain discovery by querying DNS for SRV records published by the Windows DC. It does not authenticate; it only checks that the AD domain is reachable and that Kerberos and LDAP services are visible.

The command:
```bash
realm discover gohel.local
```

will:
- query DNS for SRV records
- attempt to contact DC
- identify domain details
- find the appropriate realm configuration

If this command shows proper details, Linux can see the domain.

---

<br>
<br>

## Practical DNS checks before discovery

Before running `realm discover`, I always verify DNS resolution:
```bash
host prashantgohel.gohel.local
```

If this fails, discovery will fail.

Check SRV records:
```bash
dig _ldap._tcp.gohel.local SRV
```

If SRV records exist, the DC is publishing AD services correctly.

---

<br>
<br>

## Running domain discovery

```
realm discover gohel.local
```

Expected output example:
```bash
gohel.local
   type: kerberos
   realm-name: GOHEL.LOCAL
   domain-name: gohel.local
   configured: no
   server-software: active-directory
   client-software: sssd
```

This means realm located the domain and identified that AD is running Kerberos and LDAP.

---

<br>
<br>

## Meaning of important fields

- `realm-name`: The Kerberos realm (uppercase)
- `domain-name`: DNS domain name (lowercase)
- `server-software`: The DC software detected
- `client-software`: What realm will configure on Linux
- `configured`: no → means not joined yet

If it shows type "kerberos", that means realm detected a valid KDC.

---

<br>
<br>

## If discovery fails

Common error:
```bash
realm: No such realm found
```

This usually means:
- wrong DNS
- cannot resolve domain
- SRV records missing
- time issues

Check DNS:
```bash
host gohel.local
```

Check SRV:
```bash
dig _kerberos._tcp.gohel.local SRV
```

Check time:
```bash
timedatectl
```

---

<br>
<br>

## Verbose discovery

For more details:
```bash
realm discover -vv gohel.local
```

This shows detailed output including DNS queries and Kerberos checks. Useful when troubleshooting.

---

<br>
<br>

## Confirming Kerberos works before joining

After discovery, test Kerberos:
```bash
kinit Administrator # this command gets a Kerberos ticket for the Administrator account (basically I’m logging into Kerberos).
klist # this shows the Kerberos tickets I currently have.
```

If Kerberos fails, joining will fail.

---

<br>
<br>

## Confirm SSSD is ready

Verify SSSD is running:
```bash
systemctl status sssd
```

If SSSD is not running, discovery might succeed but authentication will fail after join.

---

<br>
<br>

## Typical troubleshooting workflow

1. Verify DNS resolution
2. Verify SRV records
3. Verify NTP/time sync
4. `realm discover -vv gohel.local`
5. `kinit Administrator`
6. Only after success → `realm join`

---

<br>
<br>

## What I achieve after this file

- I learn how to verify domain visibility before attempting a join. This prevents almost all failed joins caused by DNS or Kerberos issues. With proper discovery, I know Linux **sees** the domain and can proceed confidently to the join step.