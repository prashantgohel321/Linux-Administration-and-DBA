# Ansible – Practical Notes (Real‑World Focus)

- This file contains my **hands‑on Ansible notes**, written from a real operations and enterprise perspective. These are not copied definitions or certification-style notes. Everything here is based on how Ansible is actually used to manage Linux servers at scale, especially in environments integrated with **Active Directory, SSSD, PAM, and role‑based access**.

---

- [Ansible – Practical Notes (Real‑World Focus)](#ansible--practical-notes-realworld-focus)
  - [What This filesitory Covers](#what-this-filesitory-covers)
  - [Ansible Architecture (Practical View)](#ansible-architecture-practical-view)
  - [Control Node Setup](#control-node-setup)
    - [Installing Ansible (Ubuntu Example)](#installing-ansible-ubuntu-example)
  - [SSH Key‑Based Authentication (Mandatory)](#ssh-keybased-authentication-mandatory)
    - [Generate SSH Key on Control Node](#generate-ssh-key-on-control-node)
    - [Copy Public Key to Target Servers](#copy-public-key-to-target-servers)
  - [Inventory File (Custom and Practical)](#inventory-file-custom-and-practical)
    - [Example: inventory.ini](#example-inventoryini)
  - [Bootstrapping Python on Fresh Servers](#bootstrapping-python-on-fresh-servers)
  - [Ad‑Hoc Commands (Daily Operations)](#adhoc-commands-daily-operations)
  - [Playbooks (Repeatable Automation)](#playbooks-repeatable-automation)
    - [Basic Playbook Example](#basic-playbook-example)
  - [Installing and Managing Nginx](#installing-and-managing-nginx)
    - [install-nginx.yml](#install-nginxyml)
  - [Deploying Static Website](#deploying-static-website)
  - [Enterprise Scenario: AD + SSSD + PAM](#enterprise-scenario-ad--sssd--pam)
  - [Creating Custom authselect Profile](#creating-custom-authselect-profile)
  - [Replacing sssd.conf Using Ansible](#replacing-sssdconf-using-ansible)
  - [Managing sudo Access via AD Groups](#managing-sudo-access-via-ad-groups)
    - [Example: sudoers file](#example-sudoers-file)
    - [Deploy Using Ansible](#deploy-using-ansible)
  - [Why This Approach Works in Enterprises](#why-this-approach-works-in-enterprises)
  - [Final Note](#final-note)


<br>
<br>

## What This filesitory Covers

- This file focuses on using Ansible as a **post‑provisioning automation tool**. Infrastructure is assumed to already exist. Ansible is used to standardize, secure, and manage servers.

It covers:

* Managing multiple Linux servers from one control node
* SSH key‑based authentication at scale
* Custom Ansible inventory with groups and variables
* Installing packages and managing services
* Bootstrapping Python on fresh servers
* Using ad‑hoc commands vs playbooks
* Creating and applying playbooks
* Deploying nginx and static content
* Enterprise scenarios with AD, SSSD, PAM, and sudo

---

<br>
<br>

## Ansible Architecture (Practical View)

- Ansible works on a **push‑based model**.

- There is one machine where Ansible is installed. This is called the **control node**. From this machine, Ansible connects to all other servers using <mark><b>SSH</b></mark> and pushes configuration changes.

The target servers:

* do not need Ansible installed
* only require SSH access
* must have Python available (or bootstrapped)

This design keeps Ansible simple and easy to adopt in enterprises.

---

<br>
<br>

## Control Node Setup

The control node must be a Linux machine. In most environments, this is:

* a jump server
* a bastion host
* or a dedicated automation server

### Installing Ansible (Ubuntu Example)

Ansible is written in Python, so it is installed using OS package managers.

```bash
sudo apt update
sudo apt install software-properties-common -y
sudo add-apt-filesitory --yes --update ppa:ansible/ansible
sudo apt install ansible -y
```

Verify installation:

```bash
ansible --version
```

---

<br>
<br>

## SSH Key‑Based Authentication (Mandatory)

Ansible uses SSH. Password-based SSH does not scale and should not be used.

### Generate SSH Key on Control Node

```bash
ssh-keygen -t rsa -b 4096 -C "ansible-control"
```

This creates:

* private key: `~/.ssh/id_rsa`
* public key: `~/.ssh/id_rsa.pub`

### Copy Public Key to Target Servers

```bash
ssh-copy-id user@server-ip
```

After this, the control node can connect to servers without passwords.

---

<br>
<br>

## Inventory File (Custom and Practical)

The inventory tells Ansible **which servers exist and how to connect to them**.

Instead of using `/etc/ansible/hosts`, this file uses a custom inventory file.

### Example: inventory.ini

```ini
[all_servers]
server1 ansible_host=10.10.10.11
server2 ansible_host=10.10.10.12

[linux_admin]
server1

[linux_readonly]
server2

[all_servers:vars]
ansible_user=ansible
ansible_ssh_private_key_file=/home/ansible/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

This approach allows grouping servers by **role or department**, which is critical in enterprise environments.

---

<br>
<br>

## Bootstrapping Python on Fresh Servers

Some minimal servers do not have Python installed. Ansible cannot run modules without Python.

Ansible solves this using a <mark><b>raw</b></mark> SSH command.

```bash
ansible all_servers -m raw -a "apt install -y python3"
```

The `raw` module runs pure SSH commands and does not require Python.

---

<br>
<br>

## Ad‑Hoc Commands (Daily Operations)

Ad‑hoc commands are used for **quick, one‑time tasks**.

Examples:

Check connectivity:

```bash
ansible all_servers -m ping
```

Check disk usage:

```bash
ansible all_servers -a "df -h"
```

Restart a service:

```bash
ansible all_servers -b -m service -a "name=nginx state=restarted"
```

These commands replace logging into servers one by one.

---

<br>
<br>

## Playbooks (Repeatable Automation)

Playbooks are YAML files that define **desired state**.

### Basic Playbook Example

```yaml
- name: Show date on servers
  hosts: all_servers
  tasks:
    - name: Print date
      command: date
```

Run it using:

```bash
ansible-playbook playbook.yml
```

---

<br>
<br>

## Installing and Managing Nginx

### install-nginx.yml

```yaml
- name: Install and start nginx
  hosts: all_servers
  become: yes
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: latest

    - name: Start nginx service
      service:
        name: nginx
        state: started
        enabled: yes
```

This ensures nginx is installed, running, and enabled on boot.

---

<br>
<br>

## Deploying Static Website

```yaml
- name: Deploy static website
  hosts: all_servers
  become: yes
  tasks:
    - name: Copy index file
      copy:
        src: index.html
        dest: /var/www/html/index.html
```

Re-running this playbook is safe and idempotent.

---

<br>
<br>

## Enterprise Scenario: AD + SSSD + PAM

In enterprise Linux environments, authentication is handled using **Active Directory**.

Ansible is used to:

* create consistent SSSD configuration
* deploy PAM settings
* control sudo access via AD groups

---

<br>
<br>

## Creating Custom authselect Profile

On each server, a custom authselect profile is created instead of modifying system files directly.

```bash
authselect create-profile ad-custom --base-on sssd
```

This creates a new profile that can be managed safely.

Enable it:

```bash
authselect select custom/ad-custom --force
```

---

<br>
<br>

## Replacing sssd.conf Using Ansible

A standard `sssd.conf` is maintained in the file.

```yaml
- name: Deploy sssd configuration
  hosts: all_servers
  become: yes
  tasks:
    - name: Copy sssd.conf
      copy:
        src: sssd.conf
        dest: /etc/sssd/sssd.conf
        owner: root
        group: root
        mode: '0600'

    - name: Restart sssd
      service:
        name: sssd
        state: restarted
```

This guarantees **every server uses the same AD configuration**.

---

<br>
<br>

## Managing sudo Access via AD Groups

Sudo access is controlled using files under `/etc/sudoers.d/`.

### Example: sudoers file

```bash
%LINUX-ADMINS ALL=(ALL) ALL
%LINUX-READONLY ALL=(ALL) NOPASSWD: /usr/bin/less, /usr/bin/cat
```

### Deploy Using Ansible

```yaml
- name: Deploy sudoers rules
  hosts: all_servers
  become: yes
  tasks:
    - name: Copy sudoers file
      copy:
        src: linux-rbac
        dest: /etc/sudoers.d/linux-rbac
        mode: '0440'
```

Now access is controlled centrally via AD group membership.

---

<br>
<br>

## Why This Approach Works in Enterprises

This setup:

* removes manual changes
* enforces consistency
* supports RBAC
* integrates cleanly with AD
* is fully auditable

If a server breaks, I do not debug manually. I **re-run the playbooks**.

---

<br>
<br>

## Final Note

This filesitory is built with one mindset:

> If I repeat the same command on multiple servers, it must be automated.

Ansible is not about YAML or syntax. It is about **control, consistency, and scale**.
