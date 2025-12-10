# ad-tools-install.md

- In this file I am installing the administrative tools that allow me to manage AD after the Domain Controller promotion. When Windows Server is promoted to a Domain Controller, many tools are installed automatically, but some tools need to be confirmed or added explicitly depending on the configuration. Understanding which tools exist and what they do helps me manage users, groups, computers, DNS, and Group Policy effectively.

---

- [ad-tools-install.md](#ad-tools-installmd)
  - [What Administrative Tools Are](#what-administrative-tools-are)
  - [AD Users and Computers (ADUC)](#ad-users-and-computers-aduc)
  - [AD Administrative Center](#ad-administrative-center)
  - [DNS Manager](#dns-manager)
  - [Group Policy Management Console (GPMC)](#group-policy-management-console-gpmc)
  - [Server Manager](#server-manager)
  - [Windows PowerShell Modules](#windows-powershell-modules)
  - [Installing Tools Manually](#installing-tools-manually)
  - [Verifying Installation](#verifying-installation)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## What Administrative Tools Are

- Administrative tools are applications and management consoles that allow me to work with AD. These tools provide graphical interfaces or consoles for viewing directory objects, changing configuration, applying policies, managing DNS, and performing other essential tasks. Without these tools, I would be limited to command-line operations, which is possible but not ideal when learning.

- Administrative tools are installed through Windows Server features and include a collection of snap-ins, consoles, and utilities. When I install these tools on a Domain Controller, they are used locally on that server. They can also be installed on remote systems in enterprise environments.

---

<br>
<br>

## AD Users and Computers (ADUC)

- AD Users and Computers is the main tool for viewing and managing directory objects such as users, groups, and computers. I use ADUC to create new users, move accounts between OUs, reset passwords, and manage group membership.

- ADUC is installed automatically on a Domain Controller, but I still verify that it exists in the Start menu under Windows Administrative Tools.

---

<br>
<br>

## AD Administrative Center

- AD Administrative Center provides a modern interface for managing users and groups. It uses a friendlier layout and offers additional features such as fine-grained password policy management. While ADUC remains widely used, the Administrative Center is useful for more advanced management scenarios.

- This tool is also installed automatically on a Domain Controller.

---

<br>
<br>

## DNS Manager

- DNS Manager is the tool used to manage DNS zones, records, and server configuration. After promoting the Domain Controller and installing DNS, I use DNS Manager to verify that the correct forward and reverse lookup zones exist and that SRV records are present.

- DNS Manager lets me view and modify DNS records manually, although AD usually maintains the required records automatically.

---

<br>
<br>

## Group Policy Management Console (GPMC)

- Group Policy Management Console allows me to create and manage Group Policy Objects (GPOs). Group Policies control security settings, password policies, software installation, firewall configurations, and many other domain settings.

- GPMC is essential in enterprise environments because Group Policy is a central mechanism for enforcing configuration across hundreds or thousands of machines.

- If GPMC is not installed, I add it through Add Roles and Features in Server Manager.

---

<br>
<br>

## Server Manager

- Server Manager is a tool that helps manage server roles, features, and hardware resources. It provides a central place for viewing installed roles, checking status, and opening management tools.

- While Server Manager is not AD specific, it plays a major role in installing and managing AD DS and DNS roles.

---

<br>
<br>

## Windows PowerShell Modules

- AD includes PowerShell modules that provide command-line and scripting capabilities. Many tasks can be automated or performed using PowerShell commands. Even though I am using graphical tools, knowing that the PowerShell module exists is important because automation and scripting are common in real environments.

---

<br>
<br>

## Installing Tools Manually

- On a Domain Controller, most tools are installed automatically. If I need to install them manually, I go to Server Manager and choose Add Roles and Features. I then select Remote Server Administration Tools and check the tools I require.

- In enterprise environments, administrators often install these tools on management workstations rather than on the Domain Controller itself. For this lab, installing everything on the Domain Controller is acceptable.

---

<br>
<br>

## Verifying Installation

- After installation, I check the Windows Administrative Tools folder. I should see entries such as:
  - AD Users and Computers
  - AD Administrative Center
  - DNS
  - Group Policy Management

- I also verify that I can open these tools without errors.

---

<br>
<br>

## What I Achieve After This File

- By installing and confirming these tools, I have everything needed to manage the domain environment. I can create users, manage DNS, apply Group Policy, and observe how objects behave inside the directory. These tools are essential for every step that follows, including Linux integration and security configuration.