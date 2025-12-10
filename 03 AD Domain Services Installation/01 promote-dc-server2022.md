# promote-dc-server2022.md

- In this file I am promoting Windows Server 2022 to a Domain Controller. Before doing this, I must already have a clean Windows Server installation, correct networking, a static IP address, and a hostname chosen. Promoting a server to a Domain Controller is a critical step because it creates the AD Domain Services environment, configures DNS, and establishes the identity infrastructure for the entire network.

---

- [promote-dc-server2022.md](#promote-dc-server2022md)
  - [Understanding What It Means to Promote a Domain Controller](#understanding-what-it-means-to-promote-a-domain-controller)
  - [Preconditions Before Promotion](#preconditions-before-promotion)
  - [Setting Static IP Address](#setting-static-ip-address)
  - [Installing the AD DS Role](#installing-the-ad-ds-role)
  - [Starting the Domain Controller Promotion Wizard](#starting-the-domain-controller-promotion-wizard)
  - [Directory Services Restore Mode (DSRM) Password](#directory-services-restore-mode-dsrm-password)
  - [DNS Installation](#dns-installation)
  - [NetBIOS Domain Name](#netbios-domain-name)
  - [Paths and Database Locations](#paths-and-database-locations)
  - [Completing the Promotion](#completing-the-promotion)
  - [Logging in After Promotion](#logging-in-after-promotion)
  - [Verification After Promotion](#verification-after-promotion)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## Understanding What It Means to Promote a Domain Controller

- Promoting a server to a Domain Controller means <mark><b>installing the AD Domain Services role</b></mark> and configuring the server to host the directory database. Once promoted, the server becomes responsible for authentication, directory operations, Kerberos services, and DNS integration.

- A Domain Controller is not simply a Windows server with a role installed. It becomes the security authority for the domain. Every authentication request, user login, and computer join depends on the Domain Controller being available and functioning correctly.

---

<br>
<br>

## Preconditions Before Promotion

Before starting the promotion process, several requirements must already be met:

1. The server must have <u><b>a static IP</b></u> address. <u><b>DHCP should not be used</b></u> for a Domain Controller because IP changes break DNS and authentication.
2. The <u><b>hostname must be final</b></u>. Changing the hostname after promotion causes problems.
3. The server should be fully updated.
4. DNS should either be installed during promotion or planned correctly if using an external DNS.

If these conditions are not met, the promotion may proceed but problems will appear later, especially with DNS resolution and domain joining.

---

<br>
<br>

## Setting Static IP Address

- Open Network Connections, go to the adapter properties, select IPv4 settings, and configure the IP address manually. I assign:

  - IP address
  - Subnet mask
  - Default gateway (usually the NAT gateway in VMware)
  - Preferred DNS server (this will often be the same machine once DNS is installed)

At this stage, I temporarily set the Preferred DNS to the server’s own IP address. Later, DNS will run on this machine and handle name resolution.

---

<br>
<br>

## Installing the AD DS Role

- Open Server Manager and select "Add roles and features". I choose AD Domain Services. This installs the necessary components but does not yet make the server a Domain Controller. The promotion happens after the installation, using a separate configuration wizard.

- When the installation finishes, a notification appears asking to promote the server to a Domain Controller.

---

<br>
<br>

## Starting the Domain Controller Promotion Wizard

- Choose the option to add a new forest because this is the first Domain Controller in the environment. The wizard asks for a Root Domain Name. I choose a domain name such as:

```bash
gohel.local
```

- This name becomes the AD domain name and DNS namespace. Selecting this name requires careful thought because renaming a domain later is difficult and not recommended.

---

<br>
<br>

## Directory Services Restore Mode (DSRM) Password

- During promotion, the wizard requires a Directory Services Restore Mode password. This password allows emergency repair of the directory database if the system crashes or corruption occurs. I choose a secure password and store it safely. This is not a normal login password.

---

<br>
<br>

## DNS Installation

- The wizard asks whether to install DNS. In almost all cases, I install DNS on the Domain Controller because AD depends on it. DNS service records are automatically created and updated by AD when DNS runs locally.

- Installing DNS here ensures that clients and domain-joined machines can locate services without relying on external DNS servers that are unaware of internal domain records.

---

<br>
<br>

## NetBIOS Domain Name

- The wizard generates a NetBIOS name based on the domain name. For a domain called gohel.local, the NetBIOS name will be GOHEL. The NetBIOS name is a short label used for compatibility with older systems. It does not replace the DNS name, but it still exists for historical reasons.

---

<br>
<br>

## Paths and Database Locations

- The wizard asks where to store the NTDS database, logs, and SYSVOL folder. The default locations are normally acceptable for a lab environment. In a production environment, administrators may place these on separate disks for performance or reliability.

---

<br>
<br>

## Completing the Promotion

- Once all settings are confirmed, the wizard performs prerequisite checks. These checks verify that DNS and networking are correct. If errors appear, they must be resolved before continuing.

- After passing all checks, I start the promotion. The server will reboot automatically when the process finishes. After reboot, the server becomes a Domain Controller.

---

<br>
<br>

## Logging in After Promotion

- After reboot, the login screen shows the domain. I now have a domain Administrator account that is separate from the local Administrator account. The domain Administrator account manages the domain environment.

I log in using:

```bash
GOHEL\\Administrator
```

or

```bash
Administrator@gohel.local
```

The format depends on whether I use NetBIOS or UPN style.

---

<br>
<br>

## Verification After Promotion

After logging in, I check:
- Server Manager shows AD Domain Services installed.
- DNS Manager shows the domain DNS zone created.
- Event Viewer shows no major errors.

These steps confirm that the Domain Controller is functioning and ready.

---

<br>
<br>

## What I Achieve After This File

- By the end of this promotion, I have a fully functional Domain Controller with AD Domain Services and DNS installed. This server is now the central authentication authority for the network. Linux systems will rely on this Domain Controller for Kerberos authentication and domain integration in future steps.