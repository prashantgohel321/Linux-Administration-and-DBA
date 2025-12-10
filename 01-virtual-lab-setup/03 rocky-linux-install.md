# rocky-linux-install.md

- In this file I am installing Rocky Linux as a virtual machine inside VMware Workstation. The purpose of this Rocky Linux system is <mark><b>to eventually join it to the Windows Active Directory domain</b></mark> and learn Linux authentication, PAM, Kerberos, and security hardening. Before joining it to the domain, I need a clean installation with proper virtual hardware settings. I also need to understand what each installation choice means and why I am choosing it.

---

## Understanding What Rocky Linux Is

- Rocky Linux is an enterprise Linux distribution built from <u><b>Red Hat Enterprise Linux</b></u> sources. It is fully compatible with <u><b>RHEL</b></u>, which means it uses the same <u><b>package structure</b></u>, <u><b>system management approach</b></u>, <u><b>SELinux support</b></u>, and <u><b>enterprise security</b></u> concepts. Because of its enterprise focus, it is suitable for real-world Linux administration practice. It gives me a stable, long-term environment for learning domain integration and server security.

- Rocky Linux **uses systemd**, **supports SELinux** by default, and <mark><b>includes</b></mark> modern tools for authentication such as <mark><b>SSSD</b></mark> and <mark><b>Kerberos</b></mark> integration. These capabilities make it ideal for connecting to Active Directory.

---

## Creating the Virtual Machine in VMware

- To begin, I create a new virtual machine in VMware Workstation and select the Rocky Linux ISO as the installation media. VMware detects it as a Linux operating system and prepares a suitable configuration. Before installation starts, I must configure the virtual hardware carefully.

---

## Virtual Hardware Configuration

### Firmware (BIOS or UEFI)
- Rocky Linux supports both BIOS and UEFI. Firmware is the low-level software that activates hardware when the VM powers on. BIOS is an older approach that uses the Master Boot Record to load the boot loader. UEFI is modern and uses the GUID Partition Table. For this lab, UEFI is appropriate because it matches modern standards and avoids legacy limitations.

### CPU Allocation
- I assign one or two virtual CPUs. Rocky Linux is lightweight, but authentication services and security tools may need processing resources. Assigning two CPUs provides a smoother experience.

### Memory (RAM)
- I allocate at least two to four gigabytes of memory. This gives enough space for system processes and authentication services later. Low memory causes slow performance when installing packages or running security tools.

### Virtual Disk
- I create a virtual disk of around thirty to forty gigabytes. Rocky Linux installation and package updates require disk space. Using thin provisioning means the disk grows as needed instead of occupying the full size from the start.

### Network Adapter Type
VMware offers several network modes when creating a VM:

- Bridged networking connects the VM as if it is a physical machine on the actual network.
- NAT networking places the VM behind a virtual router inside VMware, allowing internet access while isolating the VM from the external network.
- Host-only networking isolates the VM so it only communicates with the host and other host-only VMs.
- Custom networks allow advanced virtual networking setups.

For this lab, NAT is the practical choice. NAT ensures that Windows Server and Rocky Linux are on the same internal network and can reach each other for domain integration. It also provides internet access for package installation without exposing my lab to the real network.

---

## Booting the Installer

- After configuring the hardware, I start the VM. The Rocky Linux installer loads from the ISO. The first screen allows me to choose Install Rocky Linux. I continue to the installation summary.

---

## Installation Summary and Settings

- The installer shows several sections that I must configure before installation begins.

### Language and keyboard
- I select English or my preferred language. This affects system messages and keyboard layouts.

### Installation destination
- The installer shows the virtual disk. I select automatic partitioning unless I have a specific need for custom layout. Automatic partitioning creates suitable partitions, including the root file system and EFI partition when using UEFI.

### Software selection
- For this lab, choosing minimal installation provides a clean system and encourages learning core Linux commands. Minimal installation avoids unnecessary packages and reduces system overhead. If I prefer a graphical interface, I can choose Server with GUI, but minimal installation teaches more.

### Root password and user account
- I create a root password and optionally create a normal user. Having a normal user is helpful for daily operations, but root is necessary for system configuration.

---

## Installing the System

- Once I confirm installation settings, the system begins installing packages. After installation completes, I reboot the VM and the system starts normally. If UEFI was used, the EFI System Partition holds the boot information and allows the system to start without relying on legacy BIOS methods.

---

## First Login and Basic Verification

- After reboot, I log in either as root or the user I created. I verify that the network is active by using commands such as:

```bash
ip addr
```

- This command shows network interfaces and assigned IP addresses. Rocky Linux should have an IP from the NAT network. I also check internet access using:

```bash
ping rocky-linux.org
```

- `Ping` tests basic network connectivity. If the `ping` works, the network adapter is correctly configured.

---

## Installing VMware Tools (Open VM Tools)

- Rocky Linux uses open-vm-tools rather than proprietary VMware Tools. Open-vm-tools provides integration with VMware features such as improved display, shared clipboard, and proper virtual hardware support. To install open-vm-tools I use:

```bash
dnf install open-vm-tools
```

- After installation, I enable and start the relevant services. This ensures smooth operation inside VMware.

---

## System Updates

- Before any domain integration, I update the system. Updating ensures security patches and recent versions of packages are installed. To update the system, I run:

```bash
dnf update
```

- After updates are applied, I reboot to ensure the system runs with updated components.

---

## Preparing for Domain Integration

- I do not join the domain here. Joining requires proper hostname configuration, DNS setup, and later Kerberos configuration. These steps will be written in separate files. At this point, I have a clean Rocky Linux system ready for domain operations.

---

## What I Achieve After This File

- By the end of this installation, I have a Rocky Linux virtual machine running in VMware Workstation with UEFI, NAT networking, open-vm-tools installed, and basic system updates applied. This system is ready for authentication and security experiments that follow in later files.