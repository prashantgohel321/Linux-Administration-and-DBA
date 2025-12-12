# Part 01 — Active Directory Authentication & PAM Access Control (Complete Step-by-Step)

**Author:** Prashant Gohel
**Date:** 2025-12-11

---

- [Part 01 — Active Directory Authentication \& PAM Access Control (Complete Step-by-Step)](#part-01--active-directory-authentication--pam-access-control-complete-step-by-step)
  - [Overview](#overview)
  - [Why I Needed a Custom Authselect Profile](#why-i-needed-a-custom-authselect-profile)
  - [Creating My Custom Authselect Profile](#creating-my-custom-authselect-profile)
    - [Step 1: Create the new profile](#step-1-create-the-new-profile)
    - [Step 2: Activate the profile with required features](#step-2-activate-the-profile-with-required-features)
  - [Adding sshd PAM File Inside Custom Profile](#adding-sshd-pam-file-inside-custom-profile)
  - [The Final Working PAM Logic (The Core Fix)](#the-final-working-pam-logic-the-core-fix)
    - [The three lines that actually solved the problem:](#the-three-lines-that-actually-solved-the-problem)
    - [What they mean:](#what-they-mean)
      - [`auth sufficient pam_sss.so`](#auth-sufficient-pam_sssso)
      - [`account [success=1 default=ignore] pam_sss.so`](#account-success1-defaultignore-pam_sssso)
      - [`account requisite pam_deny.so`](#account-requisite-pam_denyso)
    - [FINAL BEHAVIOR](#final-behavior)
  - [Final sshd PAM File (Inside Custom Profile)](#final-sshd-pam-file-inside-custom-profile)
  - [Failures I Faced \& Their Root Causes](#failures-i-faced--their-root-causes)
    - [Failure 1 — Using pam\_localuser](#failure-1--using-pam_localuser)
    - [Failure 2 — pam\_access with `-:LOCAL:ALL`](#failure-2--pam_access-with--localall)
    - [Failure 3 — `auth default=die`](#failure-3--auth-defaultdie)
    - [Failure 4 — Editing `/etc/pam.d/*` directly](#failure-4--editing-etcpamd-directly)
    - [✔ Final Solution — Account-phase control with pam\_sss + pam\_deny](#-final-solution--account-phase-control-with-pam_sss--pam_deny)
  - [Testing — What I Verified](#testing--what-i-verified)
    - [✔ AD user SSH login](#-ad-user-ssh-login)
    - [✔ Local user SSH login](#-local-user-ssh-login)
    - [✔ Console login as local user](#-console-login-as-local-user)
    - [✔ su between accounts](#-su-between-accounts)
    - [✔ Home directory creation](#-home-directory-creation)
  - [Final Summary for Part 01](#final-summary-for-part-01)
    - [What I have successfully implemented:](#what-i-have-successfully-implemented)
    - [The three-line logic that made everything work:](#the-three-line-logic-that-made-everything-work)


<br>
<br>

## Overview

This document explains **exactly what I did**, **how I did it**, and **why I did it** to implement AD-based SSH access control on Rocky Linux. 

**Goal of Part 01:**

* Allow **all AD users** to authenticate via SSH
* Block **all local Linux users** from SSH
* Still allow local users to log in via console
* Keep `su` usable for local accounts
* Ensure home directories for AD users are auto-created
* Implement everything through a **custom authselect profile**, not by modifying default SSSD config files

This is the foundation on which RBAC (Part 02) sits.

---

<br>
<br>

## Why I Needed a Custom Authselect Profile

Earlier, I was modifying files directly under `/etc/pam.d/`. The problem is:

* `authselect apply-changes` overwrites them
* System updates can overwrite them
* Behavior becomes inconsistent

So I rebuilt the entire PAM logic inside a **custom authselect profile**.

---

<br>
<br>

## Creating My Custom Authselect Profile

### Step 1: Create the new profile

```
sudo authselect create-profile myprofile --base-on sssd
```

This created:

```
/etc/authselect/custom/myprofile/
```

### Step 2: Activate the profile with required features

```
sudo authselect select custom/myprofile \
    --enable-feature with-sudo \
    --enable-feature with-pamaccess \
    --enable-feature with-mkhomedir --force
```

**Why these features?**

* `with-sudo`: ensures sudo PAM integration exists
* `with-pamaccess`: gives flexibility (even if I later disabled `pam_access`)
* `with-mkhomedir`: creates AD user home directories on first login

---

<br>
<br>

## Adding sshd PAM File Inside Custom Profile

The custom profile does **not include an sshd file by default**, so I created it manually:

```
sudo cp /etc/pam.d/sshd /etc/authselect/custom/myprofile/sshd
```

Then I replaced the entire content of that file with my **final working PAM stack**.

After modifying, I applied everything:

```
sudo authselect apply-changes
```

Now the system uses MY custom sshd file, not the default one.

---

<br>
<br>

## The Final Working PAM Logic (The Core Fix)

After a LOT of trial and error, I discovered that SSH access control should not be done in the `auth` phase. Instead, it must be controlled in the **account** phase.

### The three lines that actually solved the problem:

```text
auth       sufficient   pam_sss.so
account    [success=1 default=ignore] pam_sss.so
account    requisite    pam_deny.so
```

These lines create the exact behavior I wanted.

### What they mean:

#### `auth sufficient pam_sss.so`
- If the user is AD → SSSD authenticates → continue normally.
- If local user → SSSD fails → PAM continues to next modules.

#### `account [success=1 default=ignore] pam_sss.so`
- If SSSD recognizes the user (AD user) → skip the next line.
- If not recognized (local user) → go to the next line.

#### `account requisite pam_deny.so`
- If we reached this line → immediately deny access.

### FINAL BEHAVIOR

| User Type      | SSH       | Console Login | su/sudo              |
| -------------- | --------- | ------------- | -------------------- |
| **AD User**    | Allowed | N/A           | According to sudoers |
| **Local User** | Blocked | Allowed     | Allowed            |

This matches the enterprise requirement perfectly.

---

<br>
<br>

## Final sshd PAM File (Inside Custom Profile)

This is the exact file I placed in:

```bash
/etc/authselect/custom/myprofile/sshd
```

```bash
#%PAM-1.0

# =====================================================
auth       sufficient   pam_sss.so # This is the line that i've added
# =====================================================

auth       substack     password-auth
# auth required pam_access.so  # optional, not needed

auth       include      postlogin

account    required     pam_sepermit.so
account    required     pam_nologin.so

# Main access control logic
# =====================================================
account    [success=1 default=ignore] pam_sss.so
account    requisite    pam_deny.so
# =====================================================

account    include      password-auth

password   include      password-auth
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_keyinit.so force revoke
session    required     pam_selinux.so open env_params
session    include      password-auth
session    include      postlogin
```

---

<br>
<br>

## Failures I Faced & Their Root Causes

### Failure 1 — Using pam_localuser
- Sometimes allowed locals, sometimes blocked AD users depending on position.
- **Reason:** Very order-sensitive.

### Failure 2 — pam_access with `-:LOCAL:ALL`
- Sometimes blocked AD users too.
- **Reason:** Incorrect evaluation order in sshd stack.

### Failure 3 — `auth default=die`
- This broke everything when SSSD took time to respond.
- **Reason:** Too aggressive.

### Failure 4 — Editing `/etc/pam.d/*` directly
- Changes were overwritten by authselect.
- **Reason:** Authselect manages those files.

### ✔ Final Solution — Account-phase control with pam_sss + pam_deny
- Stable, predictable, and enterprise-approved.

---

<br>
<br>

## Testing — What I Verified

### ✔ AD user SSH login

```bash
ssh user12@rocky01
```
> Worked.

### ✔ Local user SSH login

```bash
ssh pgohel@rocky01
```
> Denied.

### ✔ Console login as local user
- Allowed — as required.

### ✔ su between accounts
- Worked as expected.

### ✔ Home directory creation
- `with-mkhomedir` feature took care of it.
- Everything was working exactly as expected.

---

<br>
<br>

## Final Summary for Part 01

### What I have successfully implemented:

* A custom `authselect` profile based on SSSD
* A clean PAM design that allows AD users and blocks local SSH users
* Correct placement of sshd PAM stack inside custom profile
* Automatic creation of home directories for AD users
* Fully working and production-ready authentication design

### The three-line logic that made everything work:

```bash
auth       sufficient   pam_sss.so
account    [success=1 default=ignore] pam_sss.so
account    requisite    pam_deny.so
```

Part 01 is a complete, stable, and enterprise-grade foundation for AD authentication.

---

**Part 02 (RBAC/Sudoers) is documented separately.**
