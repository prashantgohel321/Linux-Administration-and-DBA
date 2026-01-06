# SELinux – Practical, Explainable Admin Notes

<br>
<br>

- [SELinux – Practical, Explainable Admin Notes](#selinux--practical-explainable-admin-notes)
  - [1. SELinux in real life (what it actually is)](#1-selinux-in-real-life-what-it-actually-is)
    - [The problem with only DAC](#the-problem-with-only-dac)
  - [2. Is SELinux installed by default?](#2-is-selinux-installed-by-default)
  - [3. SELinux modes (very important to understand)](#3-selinux-modes-very-important-to-understand)
    - [1. `Enforcing`](#1-enforcing)
    - [2. `Permissive`](#2-permissive)
    - [3. `Disabled`](#3-disabled)
  - [4. Checking SELinux status](#4-checking-selinux-status)
    - [Command 1: `sestatus`](#command-1-sestatus)
    - [Command 2: `getenforce`](#command-2-getenforce)
  - [5. Changing SELinux mode temporarily](#5-changing-selinux-mode-temporarily)
    - [Meaning:](#meaning)
    - [Important points:](#important-points)
  - [6. Setting SELinux mode permanently](#6-setting-selinux-mode-permanently)
  - [7. Where SELinux logs violations](#7-where-selinux-logs-violations)
  - [8. File relabeling using fixfiles](#8-file-relabeling-using-fixfiles)
    - [What this does:](#what-this-does)
    - [Meaning of options:](#meaning-of-options)
    - [When to use this:](#when-to-use-this)
  - [9. Two core concepts of SELinux](#9-two-core-concepts-of-selinux)
  - [10. SELinux labeling (deep explanation)](#10-selinux-labeling-deep-explanation)
    - [Breakdown (slow and clear)](#breakdown-slow-and-clear)
      - [user](#user)
      - [role](#role)
      - [type (MOST IMPORTANT)](#type-most-important)
      - [level](#level)
  - [11. Checking SELinux labels on files](#11-checking-selinux-labels-on-files)
    - [What `-Z` means](#what--z-means)
  - [12. Checking SELinux labels on processes](#12-checking-selinux-labels-on-processes)
    - [Options explained:](#options-explained)
  - [13. SELinux and sockets (network access)](#13-selinux-and-sockets-network-access)
    - [Options explained:](#options-explained-1)
    - [What is a socket?](#what-is-a-socket)
  - [14. Real-world labeling problem (Apache example)](#14-real-world-labeling-problem-apache-example)
    - [Why?](#why)
  - [15. Checking logs using journalctl](#15-checking-logs-using-journalctl)
    - [Explanation:](#explanation)
    - [Why useful?](#why-useful)
  - [16. Fixing wrong labels using restorecon](#16-fixing-wrong-labels-using-restorecon)
    - [What this does:](#what-this-does-1)
    - [Options:](#options)
  - [17. Changing labels manually (chcon)](#17-changing-labels-manually-chcon)
    - [Warning](#warning)
  - [18. Where file contexts are defined](#18-where-file-contexts-are-defined)
  - [19. SELinux Booleans (feature switches)](#19-selinux-booleans-feature-switches)
    - [Check all booleans:](#check-all-booleans)
    - [Set boolean permanently:](#set-boolean-permanently)
  - [20. semanage (advanced management tool)](#20-semanage-advanced-management-tool)
  - [Final admin mindset](#final-admin-mindset)

---


<br>
<br>

## 1. SELinux in real life (what it actually is)

SELinux is an **extra security layer** on top of normal Linux permissions.

**Normally, we manage security using:**
* `chmod` (permissions)
* `chown` (ownership)

<br>

**This normal permission model is called:**
- **`DAC` – Discretionary Access Control**

<br>

**Discretionary means:**
* The owner of a file decides who can access it
* If permissions allow it, the access is allowed

<br>
<br>

### The problem with only DAC

- DAC trusts **users**.
- But attackers don’t log in as users. They exploit **processes**.

<br>

**Example:**
* Apache is running as a process
* It has permission to read files
* If Apache is compromised, attacker can access everything Apache can

<br>

- Linux permissions alone cannot limit *what a process is allowed to do*.
- That’s where SELinux comes in.

<br>

**SELinux uses:**
- **`MAC` – Mandatory Access Control**

<br>

**Mandatory means:**
* Rules are enforced by the system
* Even root cannot bypass them

If SELinux says **NO**, access is denied — even if permissions say YES.

---

<br>
<br>





## 2. Is SELinux installed by default?

- On **Red Hat based OS** (RHEL, Rocky, Alma, CentOS):
- SELinux is installed and enabled by default.

<br>

**If for some reason it is missing, these packages are required:**
* `selinux-policy`
  * Core SELinux policy definitions

* `selinux-policy-targeted`
  * Most common policy (protects important services like httpd, sshd, etc.)

* `policycoreutils`
  * Tools like `sestatus`, `semanage`, `restorecon`

Without these packages, SELinux cannot function properly.

---

<br>
<br>




## 3. SELinux modes (very important to understand)

SELinux has **three modes**. 

### 1. `Enforcing`

* SELinux **actively blocks** forbidden actions
* Violations are logged
* Used in production

### 2. `Permissive`

* SELinux **does not block** actions
* Violations are **logged only**
* Used for testing and debugging

### 3. `Disabled`

* SELinux is completely turned off
* No protection at all

Disabled means SELinux is **not in use**.

---

<br>
<br>




## 4. Checking SELinux status

### Command 1: `sestatus`

**This gives detailed information:**
* Is SELinux `enabled` or `disabled`
* Current mode (`enforcing` / `permissive`)
* Policy name
* Policy version
* Where SELinux is mounted

<br>
<br>

### Command 2: `getenforce`

This shows **only the current mode**:
* Enforcing
* Permissive
* Disabled

Use this when you only care about the mode.

---

<br>
<br>

## 5. Changing SELinux mode temporarily

You can change modes **temporarily** using:

```bash
setenforce 0
setenforce 1
```

<br>

### Meaning:

* `setenforce 0` → Permissive mode
* `setenforce 1` → Enforcing mode

<br>

### Important points:

* This change is **temporary**
* It resets after reboot
* You **cannot disable** SELinux using `setenforce`

**After changing mode, always verify:**

```bash
getenforce
```

---

<br>
<br>



## 6. Setting SELinux mode permanently

**Permanent mode changes are done via config file:**

```bash
/etc/selinux/config
```

<br>
<br>

**Inside this file:**

```bash
SELINUX=enforcing
SELINUX=permissive
SELINUX=disabled
```

This change takes effect **after reboot**.

---

<br>
<br>

## 7. Where SELinux logs violations

**SELinux logs security violations in:**

```bash
/var/log/audit/audit.log
```

<br>
<br>

**Every blocked action generates a detailed log entry explaining:**
* Which process
* Tried what action
* On which object
* Why it was denied

These logs are critical for troubleshooting.

---

<br>
<br>

## 8. File relabeling using fixfiles

**Command:**

```bash
fixfiles -F onboot
```

<br>
<br>

### What this does:

* Creates `/.autorelabel`
* Forces full filesystem relabel on next reboot

<br>
<br>

### Meaning of options:

* `-F` → Force relabel even if files look correct
* `onboot` → Do it during next boot

<br>
<br>

### When to use this:
* After changing SELinux from disabled → enforcing
* After restoring files from backup
* After incorrect labels break services
* When too many files have wrong contexts

This is heavy but sometimes necessary.

---

<br>
<br>

## 9. Two core concepts of SELinux

**SELinux works mainly on two concepts**:
1. Labeling
2. Type Enforcement

Everything else is built on top of these.

---

<br>
<br>

## 10. SELinux labeling (deep explanation)

**SELinux labels everything**:
* Files
* Directories
* Processes
* Sockets
* Devices

<br>
<br>

**Label format:**

```bash
user:role:type:level
```

**Example:**

```bash
unconfined_u:object_r:httpd_sys_content_t:s0
```

<br>
<br>

### Breakdown (slow and clear)


#### user

* SELinux user
* Not Linux user
* Mostly ignored in daily admin work

<br>
<br>

#### role

* Defines what role an object or process has
* Common values: `object_r`, `system_r`

<br>
<br>

#### type (MOST IMPORTANT)

* Controls access rules
* Almost all decisions depend on **type**

<br>
<br>

#### level

* Sensitivity level
* Mostly unused in servers

**If you understand types, you understand SELinux.**

---

<br>
<br>

## 11. Checking SELinux labels on files

**Command:**

```bash
ls -lZ
```

### What `-Z` means

* Shows SELinux context
* Shows how SELinux sees the file
* Decides whether access is allowed or denied

If permissions are correct but access fails — this is the first command to run.

---

<br>
<br>

## 12. Checking SELinux labels on processes

Command:

```bash
ps axZ | grep httpd
```

### Options explained:

* `a` → Processes of all users
* `x` → Processes without terminal (background services)
* `Z` → SELinux context

<br>
<br>

**Example output:**

```bash
system_u:system_r:httpd_t:s0
```

**This shows:**
* Apache process type is `httpd_t`

---

<br>
<br>

## 13. SELinux and sockets (network access)

**To check socket labels:**

```bash
netstat -taZ | grep httpd
```

<br>
<br>

### Options explained:

* `-t` → TCP connections
* `-a` → All (listening + established)
* `-Z` → SELinux context

<br>
<br>

### What is a socket?

Think simply:

* IP + Port = Address
* Socket = Door at that address

**Apache listens on:**

```
0.0.0.0:80
```

**That means:**
* Apache opened a door
* Clients connect through it
* Data flows through the socket

SELinux also controls access to this door.

---

<br>
<br>

## 14. Real-world labeling problem (Apache example)

**Scenario:**
* File created in `/root/test`
* File moved to `/var/www/html`
* Apache shows default page

Linux permissions are fine.

Apache still cannot access the file.

### Why?

Because file label is wrong.

It still has `admin_home` type.

---

<br>
<br>

## 15. Checking logs using journalctl

**Command:**

```bash
journalctl -b 0
```

<br>
<br>

### Explanation:

* `journalctl` → Reads systemd journal
* `-b` → Filter by boot
* `0` → Current boot

<br>
<br>

### Why useful?

* Debug services after reboot
* See SELinux errors clearly
* View kernel + service logs together

SELinux will suggest a fix directly.

---

<br>
<br>

## 16. Fixing wrong labels using restorecon

**Command:**

```bash
/sbin/restorecon -v /var/www/html/index.html
```

### What this does:
* Resets label to default policy value
* Fixes incorrect contexts

### Options:

* `-v` → Verbose

**Use this when:**
* Files copied from other locations
* Permissions look fine
* SELinux blocks access

After this, label becomes:

```bash
httpd_sys_content_t
```

Apache works again.

---

<br>
<br>

## 17. Changing labels manually (chcon)

Command:

```bash
chcon -t <type> filename
```

### Warning
* This is **temporary**
* Lost after relabel or reboot

Use only for testing, never for permanent fixes.

---

<br>
<br>

## 18. Where file contexts are defined

File context definitions live in:

```bash
/etc/selinux/targeted/contexts/files/file_contexts
```

**This file maps:**
* Paths → Expected SELinux types

`restorecon` uses this database.

---

<br>
<br>

## 19. SELinux Booleans (feature switches)

Booleans are **on/off switches** that control optional behavior.

Example:

* Allow FTP to access home directories

### Check all booleans:

```bash
getsebool -a
```

### Set boolean permanently:

```bash
setsebool -P boolean_name on
```

`-P` makes it permanent.

---

<br>
<br>

## 20. semanage (advanced management tool)

`semanage` is used to:
* Define permanent file contexts
* Manage ports
* Manage booleans

It is the **correct tool** for production SELinux management.

---

<br>
<br>

## Final admin mindset

SELinux is not the problem.

It exposes configuration mistakes.

**If SELinux blocks something:**
* Don’t disable it
* Read logs
* Fix labels
* Fix design

That’s how real admins work.
