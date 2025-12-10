# ou-groups-accounts.md

- Relationship between Organizational Units, groups, and accounts inside Active Directory. Even though they sound related, each of them serves a different purpose. Understanding their roles is important before I begin creating users, joining computers, and applying policies.

---

- [ou-groups-accounts.md](#ou-groups-accountsmd)
  - [How Organizational Units, Groups, and Accounts Fit Together](#how-organizational-units-groups-and-accounts-fit-together)
  - [Accounts](#accounts)
    - [User accounts](#user-accounts)
    - [Computer accounts](#computer-accounts)
  - [Groups](#groups)
  - [Organizational Units (OUs)](#organizational-units-ous)
  - [Why Not Put Everything in One OU](#why-not-put-everything-in-one-ou)
  - [How They Work Together](#how-they-work-together)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)

<br>
<br>

## How Organizational Units, Groups, and Accounts Fit Together

- Active Directory is made of objects, and three of the most important object categories are <u><b>user accounts</b></u>, <u><b>computer accounts</b></u>, and <u><b>groups</b></u>. <mark><b>Organizational Units</b></mark> provide a structure to organise these objects. Without OUs, objects would all live in the same container and administration would become difficult.

- Accounts represent identities. Groups represent collections of identities. OUs represent logical areas in which accounts and groups are placed. Active Directory uses this structure to apply rules, permissions, and policies.

---

<br>
<br>

## Accounts

- An account is an object that represents either a user or a computer.

  ### User accounts
  - A user account represents a real person or a service identity. It stores authentication details such as password information and has attributes like display name and group membership. A user logs in using this account.

  ### Computer accounts
  - A computer account represents a domain-joined machine. When a machine joins the domain, the domain controller creates a computer account so the system can be authenticated before users log in.

  - Accounts are the smallest identity units in Active Directory. They are the objects that authentication and authorisation decisions are directly based on.

---

<br>
<br>

## Groups

- Groups are collections of accounts. Instead of granting permissions to each account individually, administrators assign permissions to groups and place accounts into those groups. This reduces administrative effort and prevents mistakes.

- There are different types of groups, but at a high level, groups let me define access rules that apply to multiple users or computers at once. When I remove a user from a group, that user loses all access related to that group. This avoids handling permissions one user at a time.

- Groups can also be used for administrative roles. For example, adding a user to a domain administrators group gives that user administrative capabilities across the domain.

---

<br>
<br>

## Organizational Units (OUs)

- An Organizational Unit is a container used to organise accounts and groups. OUs are not collections of permissions but collections of objects. The purpose is organisation and policy targeting.

- OUs allow administrators to apply different policies to different sets of objects. For example, all servers might be placed in one OU and receive server-specific security policies. All desktop computers might be placed in another OU and receive workstation policies.

- OUs also help separate administrative control. Administrators can delegate control of a particular OU without granting domain-wide authority.

---

<br>
<br>

## Why Not Put Everything in One OU

- If every object lived in a single container, applying different policies to different systems would be impossible. Security would suffer because every user and computer would receive the same configuration. OUs provide control, separation, and structure.

- Large organisations often build complex OU structures that reflect departments, geographical locations, server roles, or security classifications. Even in a small lab, using OUs teaches correct administrative practice.

---

<br>
<br>

## How They Work Together

- Accounts provide identity.
- Groups collect identities.
- OUs organise objects and allow policy application.

A domain controller authenticates accounts, checks group membership, and applies group policies based on which OU an account or computer belongs to.

For example, if a user account belongs to a certain group, the user may access a shared folder. If a computer resides in a particular OU, it might receive specific security policies.

---

<br>
<br>

## What I Achieve After This File

- By the end of this explanation I understand the functional relationship between accounts, groups, and OUs. Accounts represent identities, groups represent collections for access control, and OUs provide organisational structure and policy boundaries. This understanding will be important when I start promoting the domain controller, creating users, and applying authentication and security policies.