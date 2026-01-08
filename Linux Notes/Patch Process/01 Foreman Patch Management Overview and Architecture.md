# Foreman Patch Management – Overview and Architecture

- This document explains **what Foreman is**, **how patch management works in Foreman**, and **how different components interact**.

<br>
<br>

- [Foreman Patch Management – Overview and Architecture](#foreman-patch-management--overview-and-architecture)
  - [1. What Foreman Is (In Simple Words)](#1-what-foreman-is-in-simple-words)
  - [2. What Foreman Is NOT](#2-what-foreman-is-not)
  - [3. Why Foreman Is Used for Patching](#3-why-foreman-is-used-for-patching)
  - [4. High-Level Patching Flow in Foreman](#4-high-level-patching-flow-in-foreman)
  - [5. Core Components Used in Patching](#5-core-components-used-in-patching)
    - [5.1 Foreman Server](#51-foreman-server)
    - [5.2 Smart Proxy](#52-smart-proxy)
    - [5.3 Katello (Most Important for Patching)](#53-katello-most-important-for-patching)
    - [5.4 Pulp (Backend Engine)](#54-pulp-backend-engine)
  - [6. How a Managed Server Connects to Foreman](#6-how-a-managed-server-connects-to-foreman)
  - [7. Command-Level View (Client Side)](#7-command-level-view-client-side)
  - [8. Web UI vs Command Line – How They Relate](#8-web-ui-vs-command-line--how-they-relate)
  - [9. Why Lifecycle Environments Matter (Preview)](#9-why-lifecycle-environments-matter-preview)
  - [10. Common Beginner Mistakes](#10-common-beginner-mistakes)
  - [11. What You Should Be Able to Explain After This File](#11-what-you-should-be-able-to-explain-after-this-file)

---

<br>
<br>


## 1. What Foreman Is (In Simple Words)

Foreman is a **central management tool** for Linux servers.

**In patching context, Foreman helps you:**

* Control **which packages** are available to servers
* Decide **when servers get updates**
* Apply patches **in a controlled way**
* Track **what was patched and when**

<br>

- Foreman does **not** directly replace `dnf`.
- It **controls and manages how `dnf` is used on many servers**.

---

<br>
<br>

## 2. What Foreman Is NOT

**Important to be very clear:**
* Foreman is **not** just a GUI for `dnf update`
* Foreman is **not** a package mirror only
* Foreman is **not** magic automation

<br>
<br>

**Foreman is a **control layer** on top of:**
* Repositories
* Package versions
* Environments
* Hosts

---

<br>
<br>

## 3. Why Foreman Is Used for Patching

**Manual patching problems:**
* Different admins patch differently
* Accidental extra packages get updated
* No clear rollback
* No central reporting

Foreman fixes this.

<br>
<br>

**With Foreman:**
* You patch **by policy**, not by habit
* Same rule applies to all servers
* You know exactly what changed
* Rollback is possible

---

<br>
<br>

## 4. High-Level Patching Flow in Foreman

This is the **big picture**. Details come later.

1. Foreman syncs packages from OS repositories
2. Packages are grouped into controlled versions
3. Servers are attached to those versions
4. Updates are executed using remote jobs
5. Results are recorded

No server pulls random updates from the internet.

---

<br>
<br>

## 5. Core Components Used in Patching

Foreman patching is not one single service.

It is a **set of components working together**.

---

<br>
<br>

### 5.1 Foreman Server

This is the **central UI and API**.



**Responsibilities:**
* Web UI
* API
* Host management
* Job scheduling
* Reporting

<br>
<br>

**UI path examples:**
* Hosts → All Hosts
* Configure → Host Groups
* Monitor → Jobs

---

<br>
<br>

### 5.2 Smart Proxy

Smart Proxy acts as a **helper service**.

**Responsibilities:**
* Executes commands on hosts
* Talks to content services
* Handles remote execution

<br>
<br>

**Usually installed:**
* On the same server as Foreman
* Or close to managed hosts

Without Smart Proxy, patch execution will not work.

---

<br>
<br>

### 5.3 Katello (Most Important for Patching)

Katello is the **content management engine**.

**Katello controls:**
* Repositories
* Package versions
* Lifecycle environments

If Katello is missing, Foreman patching becomes manual again.

<br>
<br>

**UI paths you will use:**
* Content → Products
* Content → Repositories
* Content → Content Views
* Content → Lifecycle Environments

---

<br>
<br>

### 5.4 Pulp (Backend Engine)

Pulp works in the background.

**It:**
* Downloads RPMs
* Stores metadata
* Publishes content to clients

Admins usually **do not interact directly** with Pulp.

---

<br>
<br>

## 6. How a Managed Server Connects to Foreman

**Every managed server:**
* Has Foreman subscription configuration
* Uses Foreman as its **content source**
* Does not directly reach public mirrors

**Key file on client:**

```bash
/etc/yum.repos.d/redhat.repo
```

(or Foreman-generated repo files)

This file is **managed by Foreman**.

Manual editing is not recommended.

---

<br>
<br>

## 7. Command-Level View (Client Side)

Even with Foreman, clients still use `dnf`.

**Example on managed host:**

```bash
dnf repolist
```

<br>

**You will see:**

* Repositories pointing to Foreman
* No public internet repos

**Example:**

```bash
dnf check-update
```

**Result:**

* Updates shown are **only what Foreman allows**

Foreman controls the source.
`dnf` still executes locally.

---

<br>
<br>

## 8. Web UI vs Command Line – How They Relate

| Action          | Foreman UI             | Client Command   |
| --------------- | ---------------------- | ---------------- |
| Repo sync       | Content → Repositories | (none)           |
| Package control | Content Views          | (none)           |
| Check updates   | (policy view)          | dnf check-update |
| Apply patches   | Jobs → Run job         | dnf update       |
| Verify install  | Host reports           | rpm / dnf        |

UI decides **what is allowed**.
Commands perform **what is allowed**.

---

<br>
<br>

## 9. Why Lifecycle Environments Matter (Preview)

Foreman patching is **environment-based**.

**Typical flow:**

* Dev → Test → Prod

Same packages move step by step.

No skipping.
No surprises.

Details covered in next files.

---

<br>
<br>

## 10. Common Beginner Mistakes

Avoid these early:

* Assigning Prod hosts directly to raw repos
* Syncing repos without version control
* Running `dnf update` manually on hosts
* Ignoring job results

Foreman fails only when admins bypass it.

---

<br>
<br>

## 11. What You Should Be Able to Explain After This File

You should clearly know:

* Why Foreman exists for patching
* Which component does what
* How Foreman and `dnf` work together
* Where patch control actually lives

If this is clear, next file will make sense.

---

