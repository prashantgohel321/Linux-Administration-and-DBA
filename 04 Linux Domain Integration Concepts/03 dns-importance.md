# dns-importance.md

- In this file I am focusing only on DNS from the Linux side when integrating with AD. Previously I learned that DNS is required by AD, but now I want to understand very practically why Linux must use the domain controller as its DNS server, how to configure DNS on Rocky Linux, how to test name resolution, and what commands to run when domain joining fails because of DNS.

---

- [dns-importance.md](#dns-importancemd)
  - [Why DNS is critical before joining Linux to AD](#why-dns-is-critical-before-joining-linux-to-ad)
  - [What DNS server Linux must use](#what-dns-server-linux-must-use)
  - [Editing DNS on Rocky Linux](#editing-dns-on-rocky-linux)
    - [Check current connection name](#check-current-connection-name)
    - [Set DNS](#set-dns)
    - [Disable automatic DNS from DHCP](#disable-automatic-dns-from-dhcp)
    - [Apply changes](#apply-changes)
  - [Testing name resolution before joining](#testing-name-resolution-before-joining)
  - [Testing SRV records](#testing-srv-records)
  - [Understanding domain discovery](#understanding-domain-discovery)
  - [Common DNS problems and fixes](#common-dns-problems-and-fixes)
    - [Linux still uses the wrong DNS](#linux-still-uses-the-wrong-dns)
    - [Cannot resolve hostname](#cannot-resolve-hostname)
    - [Cannot resolve SRV records](#cannot-resolve-srv-records)
    - [“Cannot contact any KDC” errors](#cannot-contact-any-kdc-errors)
  - [DNS and Kerberos](#dns-and-kerberos)
  - [DNS logs](#dns-logs)
  - [Practical workflow](#practical-workflow)
  - [What I achieve after this file](#what-i-achieve-after-this-file)


<br>
<br>

## Why DNS is critical before joining Linux to AD

- When I join Linux to AD, the Linux system must locate the Domain Controller. The Domain Controller publishes the Kerberos and LDAP service records in DNS. If Linux does not use the AD DNS server, the system does not see these records and cannot locate the KDC or LDAP endpoint.

- This means that even if realm is installed and the domain is reachable in theory, the join will fail because the system cannot find the right services.

---

<br>
<br>

## What DNS server Linux must use

- Linux must use the Domain Controller’s IP address as its DNS server. For example, if my Domain Controller has IP 192.168.100.10, then my **`/etc/resolv.conf`** should contain something like:

```bash
nameserver 192.168.100.10
```

- If I use a public DNS such as 8.8.8.8, it will never know anything about the internal gohel.local domain. The join fails immediately.

---

<br>
<br>

## Editing DNS on Rocky Linux

- Modern Linux systems sometimes manage **`/etc/resolv.conf`** automatically through NetworkManager. If I edit the file manually, it might be overwritten. So I need to update DNS using **`nmcli`**.

<br>
<details>
<summary><b>Q. nmcli</b></summary>
<br>

- **`nmcli`** is a command-line tool I use to control NetworkManager on Linux. With it, I can check my network status, create or edit connections, set IP addresses, change DNS, and bring interfaces up or down—all from the terminal.

- So basically, I use nmcli to manage network settings without opening any GUI.
</details>
<br>

### Check current connection name
```bash
nmcli connection show
```

- Suppose my connection name is "System eth0".

### Set DNS
```bash
nmcli connection modify "System eth0" ipv4.dns "192.168.100.10"
```

### Disable automatic DNS from DHCP
```bash
nmcli connection modify "System eth0" ipv4.ignore-auto-dns yes
```

### Apply changes
```bash
nmcli connection down "System eth0" && nmcli connection up "System eth0"
```

After reconnecting, I check:

```bash
cat /etc/resolv.conf
```

---

<br>
<br>

## Testing name resolution before joining

- I must verify that Linux can resolve the Domain Controller hostname.

```bash
dig prashantgohel.gohel.local
```

<br>
<details>
<summary><b>Q. dig command</b></summary>
<br>

- **`dig`** is a tool I use to query DNS. It lets me look up DNS records and see exactly what a domain resolves to (IP, MX, NS, etc.).

- So basically, I run dig when I want to check how DNS is responding, verify records, or troubleshoot name-resolution issues.

</details>
<br>

or

```bash
host prashantgohel.gohel.local
```

<br>
<details>
<summary><b>Q. Host command</b></summary>
<br>

- **`host`** is another tool I use to query DNS, but it gives quick, short answers. I use it when I just want <mark><b>to know the IP of a domain</b></mark> or the <mark><b>domain of an IP</b></mark> without extra detail.

</details>
<br>

If this works, DNS is good. If it fails, joining will fail.

---

<br>
<br>

## Testing SRV records

- AD publishes Kerberos and LDAP service records. To check SRV records:

```bash
dig _kerberos._tcp.gohel.local SRV
```

or

```bash
dig _ldap._tcp.gohel.local SRV
```

If these return answers pointing to the Domain Controller, then Kerberos services are discoverable.

---

<br>
<br>

## Understanding domain discovery

When I run:

```bash
realm discover gohel.local
```

realm uses DNS to find SRV records. If the command fails or shows no domain controllers, DNS is wrong.

---

<br>
<br>

## Common DNS problems and fixes

### Linux still uses the wrong DNS
- NetworkManager may override **`/etc/resolv.conf`**. Use **`nmcli`** to enforce the correct DNS.

### Cannot resolve hostname
- Check if forward zone is correct on the Domain Controller. Use DNS Manager on Windows to confirm A records exist.

### Cannot resolve SRV records
- Verify AD DS and DNS roles are properly installed and promotion completed.

### “Cannot contact any KDC” errors
- This often means DNS is not pointing to Domain Controller.

---

<br>
<br>

## DNS and Kerberos

- Kerberos relies entirely on DNS to locate the KDC. When I run:

```bash
kinit testuser1
```

- Kerberos internally uses DNS SRV records to locate the KDC. If DNS is wrong, Kerberos cannot locate it and the authentication fails.

---

<br>
<br>

## DNS logs

On Linux:
```bash
/var/log/messages
/var/log/secure
```

- These may contain DNS resolution failures.

- On Windows Domain Controller:
  - Event Viewer
  - DNS Server event logs

- I check these if name resolution is failing.

---

<br>
<br>

## Practical workflow

Before trying realm join, I do:
```bash
ping dc01.gohel.local
host dc01.gohel.local
```

Then test SRV records:
```bash
dig _ldap._tcp.gohel.local SRV
```

If all good, proceed:
```bash
realm discover gohel.local
```

Only after these succeed, I attempt:
```bash
realm join gohel.local -U Administrator

# -U tells the command which user account I’m using to join the domain (in this case, Administrator).
```



---

<br>
<br>

## What I achieve after this file

After understanding DNS importance, I know exactly why Linux must use the Domain Controller as DNS, how to configure it in nmcli, how to test name resolution and SRV records, and how to interpret failures. This prevents most domain join failures and saves time during troubleshooting.