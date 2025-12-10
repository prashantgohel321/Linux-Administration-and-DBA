# create-test-users.md

- In this file I am creating test users inside AD after the domain controller is fully operational. Creating test users helps verify that authentication, DNS, and domain services are functioning correctly. These accounts will also be used later when I join Linux to the domain and test login scenarios.

---

- [create-test-users.md](#create-test-usersmd)
  - [Why Create Test Users](#why-create-test-users)
  - [Using AD Users and Computers](#using-ad-users-and-computers)
  - [Choosing Where to Create Users](#choosing-where-to-create-users)
  - [Creating a New OU](#creating-a-new-ou)
  - [Creating a Test User](#creating-a-test-user)
  - [Password Settings](#password-settings)
  - [Testing Login Using the Test User](#testing-login-using-the-test-user)
  - [Creating Multiple Test Users](#creating-multiple-test-users)
  - [Using Groups](#using-groups)
  - [Why I Need Test Accounts Before Joining Linux](#why-i-need-test-accounts-before-joining-linux)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## Why Create Test Users

- AD is designed to manage users and their access. Before joining other machines to the domain, I need at least a few accounts to test authentication, group membership, and basic login behaviour. Creating test accounts ensures that the directory is working and that AD is storing and handling identity information properly.

- Test users allow me to validate:
  - password authentication
  - account lockout behaviour
  - group membership
  - login to domain-joined systems
  - future Linux authentication

---

<br>
<br>

## Using AD Users and Computers

- To create test users, I open the tool called AD Users and Computers (ADUC). This tool allows me to view and manage directory objects. ADUC is installed automatically when I promote the server to a Domain Controller.

- I navigate through the Start menu or Server Manager to open ADUC. Once open, I can browse the domain and its default containers.

---

<br>
<br>

## Choosing Where to Create Users

- AD places new objects into default containers such as Users or Computers. However, best practice is to create a dedicated Organizational Unit (OU) for users instead of using the default Users container. This gives better organisation and prepares for applying group policies to users later.

- I can create a new OU called "TestUsers". This OU will hold the accounts that I am creating for testing.

---

<br>
<br>

## Creating a New OU

- Inside ADUC, I right-click the domain name and choose New → Organizational Unit. I name it "TestUsers". This creates a container specifically for storing user accounts.

- Creating separate OUs keeps the directory organised and allows targeted policies. Even in a simple lab, correct structure matters.

---

<br>
<br>

## Creating a Test User

- Inside the TestUsers OU, I right-click and choose New → User. I enter user details such as first name and user logon name. The user logon name becomes part of the identity that users type when logging in. For example, I can create a user named:

```bash
Test User1
User logon name: testuser1
```

- After entering the user name, the wizard asks for a password.

---

<br>
<br>

## Password Settings

- By default, AD enforces password policies. When creating a new user, I must enter a password that meets the policy requirements. I also choose whether the user must change the password at next logon. For a test account, I usually allow the account to use a defined password and not require immediate change, as this simplifies testing.

---

<br>
<br>

## Testing Login Using the Test User

- After creating the user, I verify that authentication works. I can log out of the Domain Controller and log in using:

```bash
testuser1@gohel.local
```

or the NetBIOS format:

```
GOHEL\testuser1
```

- If the login succeeds, the account is working and the Domain Controller is handling authentication correctly.

---

<br>
<br>

## Creating Multiple Test Users

- To test group membership and policies later, I create multiple test users. Having more than one account helps simulate real scenarios and test permission differences.

- For example:
  - testuser1
  - testuser2

Each can be used to test different group assignments.

---

<br>
<br>

## Using Groups

- Once I have test users, I can create a security group and add users to it. This allows me to test access control based on group membership. For example, I can create a group called "LinuxUsers" and assign users to this group later when configuring Linux authentication.

---

<br>
<br>

## Why I Need Test Accounts Before Joining Linux

- Linux integration depends on verifying that AD authentication works. If I cannot authenticate a test user inside a Windows environment, Linux domain joining will also fail. By verifying domain accounts first, I remove unnecessary troubleshooting steps later.

---

<br>
<br>

## What I Achieve After This File

- By the end of this process, I have:
  - at least one test user
  - a proper OU for storing accounts
  - the ability to authenticate using domain accounts

- These accounts prepare me for testing login behaviour from Linux systems and verifying that the Domain Controller handles authentication correctly.