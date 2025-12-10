# realm-install.md

- In this file I am installing the packages needed for joining Rocky Linux to AD using **realm** and **SSSD**. The goal is not just to install realm, but to fully understand what packages are required, why they are required, and how to verify everything before attempting a join. I want to avoid the typical mistake of running `realm join` without preparing the system.

---

- [realm-install.md](#realm-installmd)
  - [What realm actually installs](#what-realm-actually-installs)
  - [Install required packages](#install-required-packages)
  - [Check installation](#check-installation)
  - [Enable oddjobd](#enable-oddjobd)
  - [Enable SSSD](#enable-sssd)
  - [Verify DNS BEFORE join](#verify-dns-before-join)
  - [Verify Kerberos BEFORE join](#verify-kerberos-before-join)
  - [Check realm status BEFORE join](#check-realm-status-before-join)
  - [Common installation problems](#common-installation-problems)
    - [Missing adcli](#missing-adcli)
    - [No Kerberos tools](#no-kerberos-tools)
    - [SSSD not running](#sssd-not-running)
  - [Checklist BEFORE join](#checklist-before-join)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## What realm actually installs

- realm is part of the **realmd** framework. When installed, it pulls in dependencies required for AD integration. This may include:
  - realmd
  - SSSD
  - SSSD AD backend
  - Kerberos client
  - oddjob-mkhomedir

- These components work together. realm itself just orchestrates configuration and discovery.

---

<br>
<br>

## Install required packages

- On Rocky Linux:
```bash
dnf install realmd sssd sssd-tools oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation
```

- This installs everything needed for:
  - realm functionality
  - Kerberos client tools
  - SSSD identity service
  - automatic home directory creation
  - Samba tools for AD communication

- oddjob-mkhomedir creates user home directories automatically on login. Without it, AD logins might succeed but the system might not create a home directory.

<br>
<details>
<summary><b>Samba</b></summary>
<br>

- Samba lets my Linux system use Windows file sharing and AD integration features, so I can access Windows shares and work inside a Windows domain from Linux.

</details>
<br>

---

<br>
<br>

## Check installation

Verify realmd is installed:
```bash
which realm
```

Verify SSSD:
```bash
rpm -qa | grep sssd
```

Verify Kerberos tools:
```bash
kinit --version
```

---

<br>
<br>

## Enable oddjobd

After installation, I enable and start oddjobd:
```bash
systemctl enable oddjobd
systemctl start oddjobd
```

oddjobd handles automatic home directory creation.

---

<br>
<br>

## Enable SSSD

SSSD must be running:
```bash
systemctl enable sssd
systemctl start sssd
```

Without SSSD running, realm join may work but authentication will later fail.

---

<br>
<br>

## Verify DNS BEFORE join

Before running any realm command, verify DNS resolution:
```bash
host prashantgohel.gohel.local
```

If this fails, do NOT run realm join yet. Fix DNS first.

---

<br>
<br>

## Verify Kerberos BEFORE join

Test Kerberos discovery:
```bash
kinit Administrator
```

If it asks for a password and issues a ticket, Kerberos works. If it cannot find a KDC, DNS is wrong.

Show tickets:
```bash
klist
```

If kinit fails, joining will fail. Fix DNS or time.

---

<br>
<br>

## Check realm status BEFORE join

```bash
realm list
```

If no domains listed (this is normal at installation), at least confirm realm command works.

---

<br>
<br>

## Common installation problems

### Missing adcli
realm may fail to install required backend tools if adcli is missing. Installing realmd package should pull in adcli. If not, install manually:
```bash
dnf install adcli
```

<br>
<details>
<summary><b>adcli</b></summary>
<br>

- **`adcli`** is the tool I use on Linux to join the machine to AD and create the computer account in the domain.

</details>
<br>

### No Kerberos tools
If kinit is missing, install kerb5-workstation.

### SSSD not running
Authentication depends on SSSD. Always check:
```bash
systemctl status sssd
```

---

<br>
<br>

## Checklist BEFORE join

1. Packages installed
2. SSSD running
3. oddjobd running
4. DNS set to Domain Controller
5. Kerberos working (kinit test)
6. Time synchronized

Only AFTER this checklist do I run realm join.

---

<br>
<br>

## What I achieve after this file

By understanding realm installation, I set up the system correctly before attempting a domain join. I also verify DNS, Kerberos, SSSD, and required services. This prevents most real-world join failures and makes troubleshooting much easier when moving to the domain join step.