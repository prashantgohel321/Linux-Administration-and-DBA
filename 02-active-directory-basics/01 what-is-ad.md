# what-is-ad.md

- In this file I am explaining what <mark><b>Active Directory</b></mark> actually is, in simple and precise terms, without assuming previous knowledge. Understanding Active Directory at the conceptual level is necessary before configuring anything.

---

- [what-is-ad.md](#what-is-admd)
  - [What Active Directory Is](#what-active-directory-is)
  - [Why Active Directory Exists](#why-active-directory-exists)
  - [How Active Directory Works](#how-active-directory-works)
  - [What Makes Active Directory Important](#what-makes-active-directory-important)
  - [Domain and Domain Controller](#domain-and-domain-controller)
  - [Forest and Trees (High Level before deeper details)](#forest-and-trees-high-level-before-deeper-details)
  - [Why I Need to Understand This](#why-i-need-to-understand-this)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## What Active Directory Is

- <mark><b>Active Directory</b></mark> is a directory service created by Microsoft. A directory service is <mark><b>a structured database</b></mark> that stores information about objects such as <u><b>users</b></u>, <u><b>computers</b></u>, <u><b>groups</b></u>, and <u><b>permissions</b></u>. The purpose of a directory service is to provide <mark><b>a centralised way to manage identities and access</b></mark> across a network.

- Active Directory runs on Windows Server and one or more servers host the directory database. When a user logs in to a computer joined to an Active Directory domain, the computer contacts the domain controller in order to authenticate the user and verify permissions.

![alt text](<../Diagrams/02_01_00 AD.png>)

---

<br>
<br>

## Why Active Directory Exists

- Before directory services, each computer stored its own user accounts locally. This created several problems. Each computer needed individual account management. Password changes had to be repeated on each system. There was no single authority to verify identities or apply consistent access rules. Organisations needed a central identity system that controls who can log in, what they can use, and how policies are enforced.

- Active Directory solves this by keeping user accounts, passwords, computers, and policies in one central location. Instead of configuring each computer separately, administrators control everything from the directory.

---

<br>
<br>

## How Active Directory Works

- Active Directory runs a database called the <mark><b>Active Directory Domain Services database</b></mark>. This database stores all directory objects. The domain controller hosts this database and provides authentication services. When a client requests authentication, the domain controller checks the user credentials against the directory and returns a response.

- <mark><b>Kerberos</b></mark> is used as the authentication protocol. Kerberos uses a ticket-based approach. Instead of sending passwords repeatedly, a client obtains a ticket that proves its identity to services. This strengthens security and reduces the risk of password exposure over the network.

---

<br>
<br>

## What Makes Active Directory Important

- Active Directory is not just user accounts. It provides central authentication, authorisation, policy enforcement, and resource management. Without it, each server and workstation would operate independently. In a large environment this would be unmanageable.

- Centralisation means administrators can add or remove users, enforce password policies, control computer settings, restrict access, and monitor activity from a single location.

---

<br>
<br>

## Domain and Domain Controller

- A <mark><b>domain</b></mark> in Active Directory is a logical boundary that <u><b>contains users and computers</b></u> under a single administrative control. 

- A <mark><b>domain controller</b></mark> is a server that holds <u><b>a copy of the directory database and handles authentication requests.</b></u> When a user logs in, the domain controller verifies the identity and provides authorisation information.

- Multiple domain controllers can exist in the same domain. They replicate the database to each other to provide redundancy and availability.

![alt text](<../Diagrams/02_01_01 DC.png>)

---

<br>
<br>

## Forest and Trees (High Level before deeper details)

- A <mark><b>forest</b></mark> is the highest level of Active Directory structure. It can contain one or more domains. A forest provides a security boundary. Domains inside a forest trust each other automatically unless configured differently. For a small lab, I will work with a single domain inside a single forest.

- Later I will look at forests and trees in more detail, but for now it is enough to understand that the forest contains domains and the domain contains objects such as users and computers.

---

<br>
<br>

## Why I Need to Understand This

If I do not understand the purpose and structure of Active Directory, the configuration steps can feel mechanical. When something fails, I will not know why. Understanding how the domain controller authenticates users, why Kerberos is important, and how the directory database works helps me troubleshoot problems and build a secure environment.

---

<br>
<br>

## What I Achieve After This File

By the end of this explanation, I have a clear idea of what Active Directory is, why it exists, how it stores objects, and which components are involved. This foundation prepares me for further topics such as domain creation, OU structure, group policy, and domain joining for Linux systems.
