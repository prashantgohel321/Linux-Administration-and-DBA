# ad-objects.md

- What an <mark><b>object</b></mark> is inside Active Directory, what kinds of objects exist, how they are stored, and why objects are the core building element of the directory. Without a clear understanding of objects, the structure of Active Directory can feel abstract.

---

- [ad-objects.md](#ad-objectsmd)
  - [What an Object Is in Active Directory](#what-an-object-is-in-active-directory)
  - [Why Active Directory Uses Objects](#why-active-directory-uses-objects)
  - [Types of Objects](#types-of-objects)
  - [User Objects](#user-objects)
  - [Computer Objects](#computer-objects)
  - [Group Objects](#group-objects)
  - [Organisational Units (OUs)](#organisational-units-ous)
  - [How Objects Are Stored in the Directory](#how-objects-are-stored-in-the-directory)
  - [Attributes](#attributes)
  - [Why I Need to Understand Objects](#why-i-need-to-understand-objects)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## What an Object Is in Active Directory

- An <mark><b>object</b></mark> in Active Directory is <u><b>a record inside the directory database</b></u> that represents something in the network. Each object contains attributes that describe it. For example, a user object has a username, password-related data, and personal information attributes. A computer object has a hostname and security identifiers.

- Active Directory stores all objects in a structured database and uses these objects to understand who exists in the organisation and what they are allowed to do.

---

<br>
<br>

## Why Active Directory Uses Objects

- A directory service needs a uniform way to store different entities. Instead of storing text entries or loose configuration files, Active Directory stores everything as objects with attributes. This approach gives consistency, searchability, and security. It also allows centralised control of identities and resources.

- Objects also support inheritance of permissions and policies. This means administrators can apply rules to many objects efficiently instead of setting permissions manually on each individual item.

---

<br>
<br>

## Types of Objects

Active Directory has different types of objects. The most common are:

- User objects
- Computer objects
- Group objects
- Organisational Units (OUs)

There are many others, but these form the core of identity and access management.

---

<br>
<br>

## User Objects

- A user object represents a real person or a service account. It stores authentication information and identity attributes. When a person logs in to a domain-joined machine, the domain controller checks the user object in the directory.

- User objects can belong to groups, can have policies applied to them, and can be given or denied access to resources. User objects also contain password and account status attributes that determine if an account is active, locked, or disabled.

---

<br>
<br>

## Computer Objects

- A computer object represents a workstation or server that is part of the domain. When a computer joins a domain, Active Directory creates a computer object for it. This allows the domain controller to authenticate the computer itself before authenticating users.

- Computer objects also have security identifiers and can be targeted with policies. This makes central management possible for hundreds or thousands of machines.

---

<br>
<br>

## Group Objects

- A group object is a collection of user objects or computer objects. Groups are important because access control is usually assigned to groups instead of individual users. This makes administration simpler and prevents duplicate configuration.

- For example, instead of granting access to every user one by one, I assign access to a group and place users into that group.

- There are different types of groups, and they can serve different roles in access control and policy application.

---

<br>
<br>

## Organisational Units (OUs)

- An Organisational Unit is a container object that holds users, computers, or groups. OUs help structure the directory logically, similar to how folders organise files. This allows administrators to apply policies differently in each OU.

- For example, I might create separate OUs for servers, workstations, and administrative accounts. Placing objects into the correct OU allows targeted Group Policy settings.

---

<br>
<br>

## How Objects Are Stored in the Directory

- Active Directory uses a database file called the <mark><b>NTDS</b></mark> database, stored on the domain controller. All objects are stored inside this database and replicated to other domain controllers. Each object has a unique identifier called a <mark><b>Security Identifier (SID)</b></mark>. The SID does not change even if the object name changes.

- Objects are organised within the domain under a hierarchical structure. This hierarchy starts at the domain root and continues downward into OUs and container objects.

---

<br>
<br>

## Attributes

- Every object has attributes. An attribute describes something about the object. For a user object, attributes include logon name, password information, email address, and group membership. For a computer object, attributes include hostname and operating system information.

- Attributes determine how the object behaves and how the domain controller interprets it. Administrators can modify attributes to grant access, restrict access, or change properties.

---

<br>
<br>

## Why I Need to Understand Objects

- When joining Linux to Active Directory, I will be working with user objects and computer objects. When configuring access, I will rely on group objects. When applying security settings, I will depend on OUs. Without understanding objects, it becomes difficult to troubleshoot authentication problems or design a secure directory structure.

---

<br>
<br>

## What I Achieve After This File

- By the end of this explanation, I have a clear understanding of what objects are in Active Directory, what types exist, and what role each type plays. This knowledge will help me in later steps such as joining computers to the domain, creating users, managing access, and applying Group Policy.