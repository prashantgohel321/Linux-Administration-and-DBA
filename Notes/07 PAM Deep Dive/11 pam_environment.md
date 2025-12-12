# pam_environment.md

This file explains **pam_env.so** and the related configuration file **/etc/security/pam_env.conf**. Although pam_env looks small and simple, it controls how the user environment variables are set during login — and this matters more than people realize.

Environment variables influence:
- locale and language
- PATH and secure paths
- proxy settings
- application behavior
- AD/SSSD behavior (in rare cases)

Bad or missing pam_env configurations can lead to login failures, broken shells, missing PATH values, or inconsistent SSH vs console environments.

This file covers:
- how pam_env works
- every configuration file involved
- how it behaves in SSH vs console
- how environment variables apply to AD users
- testing & troubleshooting
- safe examples

---

- [pam\_environment.md](#pam_environmentmd)
- [What pam\_env.so actually does](#what-pam_envso-actually-does)
- [Where pam\_env reads configuration](#where-pam_env-reads-configuration)
  - [1. `/etc/security/pam_env.conf`](#1-etcsecuritypam_envconf)
  - [2. `/etc/environment`](#2-etcenvironment)
- [Example pam\_env settings (practical)](#example-pam_env-settings-practical)
  - [1. Force default locale for all users](#1-force-default-locale-for-all-users)
  - [2. Set proxy for all AD users](#2-set-proxy-for-all-ad-users)
  - [3. Load per-user custom language file](#3-load-per-user-custom-language-file)
- [Dynamic variables using built-in tokens](#dynamic-variables-using-built-in-tokens)
- [How pam\_env behaves in SSH vs console](#how-pam_env-behaves-in-ssh-vs-console)
    - [Console login (`/etc/pam.d/login`)](#console-login-etcpamdlogin)
    - [SSH login (`/etc/pam.d/sshd`)](#ssh-login-etcpamdsshd)
    - [AD users via SSSD](#ad-users-via-sssd)
- [How to test pam\_env behavior](#how-to-test-pam_env-behavior)
- [Common mistakes and fixable problems](#common-mistakes-and-fixable-problems)
  - [Problem 1: PATH is wrong or missing in SSH](#problem-1-path-is-wrong-or-missing-in-ssh)
  - [Problem 2: LANG not applied for AD users](#problem-2-lang-not-applied-for-ad-users)
  - [Problem 3: Environment variables ignored in SSH](#problem-3-environment-variables-ignored-in-ssh)
  - [Problem 4: pam\_env.conf syntax issues](#problem-4-pam_envconf-syntax-issues)
- [Advanced usage](#advanced-usage)
  - [1. Per-group environment variables (SSSD + pam\_env)](#1-per-group-environment-variables-sssd--pam_env)
  - [2. Disable environment variables completely](#2-disable-environment-variables-completely)
- [Safe default configuration](#safe-default-configuration)
- [Checklist for pam\_env troubleshooting](#checklist-for-pam_env-troubleshooting)
- [What you achieve after this file](#what-you-achieve-after-this-file)


<br>
<br>

# What pam_env.so actually does

`pam_env.so` loads environment variables **before the AUTH phase** completes.

This module is usually placed at the top of the auth stack:
```bash
auth    required    pam_env.so
```

It reads:
1. `/etc/security/pam_env.conf`
2. `/etc/environment`

Then sets environment variables for the session.

pam_env does **not** authenticate anyone.  
It only sets environment variables early enough for other PAM modules to use them.

Example: If your login shell depends on LANG being correct, pam_env ensures it is set.

---

<br>
<br>

# Where pam_env reads configuration

## 1. `/etc/security/pam_env.conf`
This file allows conditional, dynamic variable setting.

Format:
```bash
VARIABLE   DEFAULT_VALUE   OVERRIDE_VALUE
```

Example:
```bash
LANG   DEFAULT=en_US.UTF-8   OVERRIDE=@{HOME}/.lang
```

## 2. `/etc/environment`
This file is **static** and not PAM-specific. pam_env reads it automatically.

Example:
```bash
PATH=/usr/local/bin:/usr/bin:/usr/sbin
HTTP_PROXY=http://proxy.local:8080
```

---

<br>
<br>

# Example pam_env settings (practical)

## 1. Force default locale for all users
```bash
LANG   DEFAULT=en_US.UTF-8
LC_ALL DEFAULT=en_US.UTF-8
```

## 2. Set proxy for all AD users
```bash
HTTP_PROXY  DEFAULT=http://proxy.gohel.local:8080
HTTPS_PROXY DEFAULT=http://proxy.gohel.local:8080
```

## 3. Load per-user custom language file
```bash
LANG   DEFAULT=en_US.UTF-8   OVERRIDE=@{HOME}/.lang
```
If the user creates ~/.lang, that value overrides the default.

---

<br>
<br>

# Dynamic variables using built-in tokens

pam_env supports dynamic values:
- `@{HOME}` → user home directory
- `@{USER}` → username
- `@{LOGNAME}` → login name
- `@{TTY}` → TTY device

Example:
```bash
HISTFILE  DEFAULT=@{HOME}/.bash_history
```

---

<br>
<br>

# How pam_env behaves in SSH vs console

### Console login (`/etc/pam.d/login`)
pam_env works normally and loads all variables.

### SSH login (`/etc/pam.d/sshd`)
Behavior depends on:
```bash
AcceptEnv LANG LC_* HTTP_PROXY HTTPS_PROXY
```
from `/etc/ssh/sshd_config`.

If `AcceptEnv` is not configured, SSH will **ignore** incoming environment variables.

To allow them:
```bash
AcceptEnv LANG LC_* http_proxy https_proxy
```
Restart SSH:
```bash
systemctl restart sshd
```

### AD users via SSSD
pam_env works **exactly the same** as for local users.  
AD identity does not affect pam_env functionality.

---

<br>
<br>

# How to test pam_env behavior

Log in and check environment variables:
```bash
env | sort
```
Or:
```bash
printenv
```

Look specifically for variables defined in pam_env.conf.

If missing:
1. Check that pam_env is present:
```bash
grep pam_env /etc/pam.d/*
```
2. Check permissions on pam_env.conf:
```bash
ls -l /etc/security/pam_env.conf
```
3. Run SSH with verbose mode:
```bash
ssh -vvv user@server
```
Look for `Setting environment variables` entries.

---

<br>
<br>

# Common mistakes and fixable problems

## Problem 1: PATH is wrong or missing in SSH
Cause: `/etc/environment` not loaded or overwritten.
Fix:
```bash
echo "PATH=/usr/local/bin:/usr/bin" >> /etc/environment
```
Re-login.

<br>
<br>

## Problem 2: LANG not applied for AD users
Cause: pam_env missing in system-auth.
Fix:
Ensure:
```bash
auth required pam_env.so
```
is in both system-auth and password-auth.

<br>
<br>

## Problem 3: Environment variables ignored in SSH
Cause: sshd_config missing AcceptEnv.
Fix:
```bash
AcceptEnv LANG LC_* http_proxy https_proxy
systemctl restart sshd
```

<br>
<br>

## Problem 4: pam_env.conf syntax issues
Example error:
```bash
# wrong – missing columns
LANG=en_US.UTF-8
```
Correct:
```bash
LANG   DEFAULT=en_US.UTF-8
```

Check logs:
```bash
grep pam_env /var/log/secure
```

---

<br>
<br>

# Advanced usage

## 1. Per-group environment variables (SSSD + pam_env)
Not directly supported by pam_env, but you can load a script via pam_exec:
```bash
session optional pam_exec.so seteuid /usr/local/bin/set-env-based-on-group.sh
```
Script can check:
```bash
groups $PAM_USER
```
and export values.

<br>
<br>

## 2. Disable environment variables completely
Remove pam_env from PAM files:
```bash
sed -i '/pam_env.so/d' /etc/pam.d/system-auth
```
Not recommended unless required.

---

<br>
<br>

# Safe default configuration

Put this in `/etc/security/pam_env.conf`:
```bash
LANG        DEFAULT=en_US.UTF-8
LC_ALL      DEFAULT=en_US.UTF-8
PATH        DEFAULT=/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin
HISTSIZE    DEFAULT=2000
EDITOR      DEFAULT=vim
```

---

<br>
<br>

# Checklist for pam_env troubleshooting

- pam_env.so present in auth phase?  
- AcceptEnv enabled in sshd_config?  
- Syntax in pam_env.conf correct?  
- /etc/environment contains valid variables?  
- Does `env` output show expected values?  
- Do AD users receive correct variables?  
- Any overrides in shells (bashrc, profile)?

---

<br>
<br>

# What you achieve after this file

You now understand:
- how pam_env loads and applies environment variables
- how SSH interacts with environment loading
- how AD users inherit environment settings
- how to debug missing or incorrect variables
- safe and practical usage patterns for pam_env

pam_env is not flashy, but it is foundational for predictable and secure login environments — especially in enterprise systems.