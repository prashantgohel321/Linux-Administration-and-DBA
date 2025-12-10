# basic-dns-in-ad.md

- Active Directory depends on DNS more than most people realise. Without correct DNS, authentication fails, domain joining fails, and services cannot locate domain controllers. Before configuring Active Directory, I need a clear understanding of how DNS fits into the overall picture.

---

- [basic-dns-in-ad.md](#basic-dns-in-admd)
  - [What DNS Is in General](#what-dns-is-in-general)
  - [Why Active Directory Needs DNS](#why-active-directory-needs-dns)
  - [Service Records (SRV Records)](#service-records-srv-records)
  - [Forward Lookup Zones](#forward-lookup-zones)
  - [Reverse Lookup Zones](#reverse-lookup-zones)
  - [Dynamic DNS Updates](#dynamic-dns-updates)
  - [DNS and Kerberos](#dns-and-kerberos)
  - [DNS and Domain Promotion](#dns-and-domain-promotion)
  - [Why Linux Must Use AD DNS](#why-linux-must-use-ad-dns)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## What DNS Is in General

- DNS stands for <mark><b>Domain Name System</b></mark>. It <u><b>translates human-readable names into IP addresses</b></u>. Computers communicate using IP addresses, not names. When I type a domain name, DNS resolves it into the corresponding IP so the computer knows where to connect.

- DNS functions like a phone book for the internet and internal networks. When a client needs to connect to a server, it asks DNS for the IP address associated with that server name.

---

<br>
<br>

## Why Active Directory Needs DNS

- Active Directory is built around logical names, service discovery, and directory queries. Clients constantly need to locate domain controllers, Kerberos services, LDAP services, and global catalog servers. These components are found using DNS records.

- If DNS is not working or not configured correctly, clients cannot locate the domain controller. This means authentication fails even if everything else is configured correctly.

- Active Directory automatically creates DNS records for services. For example, when I promote a Windows Server to a domain controller, DNS records are created to advertise Kerberos and LDAP services.

---

<br>
<br>

## Service Records (SRV Records)

- Active Directory uses special DNS records called SRV records. These records explain <mark><b>which server provides which service</b></mark>. For example, a DNS SRV record tells clients where the domain controller with the Kerberos service is located. Without SRV records, clients would not know which server to contact.

- An SRV record contains information such as the hostname of the server providing the service and the port number the service listens on. Active Directory clients rely on these records for domain functions.

---

<br>
<br>

## Forward Lookup Zones

- A forward lookup zone is a DNS zone that <mark><b>resolves names to IP addresses</b></mark>. When a client asks for the IP address of a domain controller, the DNS server looks in the forward zone to find the correct address. In an Active Directory environment, the forward zone usually matches the domain name, such as `gohel.local`.

- The forward zone stores host records and service records needed by Active Directory. Without this zone, clients cannot locate servers by name.

---

<br>
<br>

## Reverse Lookup Zones

- A reverse lookup zone <mark><b>resolves IP addresses to names</b></mark>. Reverse lookups are not mandatory for Active Directory to function, but having them improves diagnostics and logging.

- When performing troubleshooting or verifying network configuration, reverse lookups help confirm that the DNS server knows both the name and IP of a system.

---

<br>
<br>

## Dynamic DNS Updates

- Active Directory uses dynamic DNS updates to add and update DNS records automatically. When a domain controller is created, or when a computer joins the domain, it registers its own DNS information. This keeps DNS in sync with the directory.

- Dynamic updates reduce administrative work because records do not need to be created manually. However, they depend on proper DNS permissions and configuration.

---

<br>
<br>

## DNS and Kerberos

- Kerberos is the <mark><b>authentication protocol</b></mark> used by Active Directory. Kerberos requires the client and domain controller to locate each other reliably. DNS provides the discovery mechanism. If DNS cannot provide correct records, Kerberos authentication fails.

- This is why the first troubleshooting step in almost every Active Directory issue is checking DNS.

---

<br>
<br>

## DNS and Domain Promotion

- When I promote Windows Server to a domain controller, the wizard asks if I want to install DNS. In most cases, DNS should be installed on the domain controller because Active Directory relies on it.

- The domain controller hosting DNS becomes the authoritative DNS server for the domain. Linux systems that join the domain must use this DNS server. Using external DNS servers will cause authentication and domain joining problems.

---

<br>
<br>

## Why Linux Must Use AD DNS

- When a Linux system joins the domain, it must resolve domain controllers using the DNS server that holds the AD records. If Linux uses a public DNS server, such as a corporate router or internet DNS, it will not find the Active Directory services and the join will fail.

- This requirement is critical and often overlooked. During domain integration, I will explicitly set Linux DNS to point to the Active Directory DNS server.

---

<br>
<br>

## What I Achieve After This File

By the end of this explanation, I understand that DNS is a core dependency of Active Directory. The domain controller automatically creates DNS service records. Clients rely on DNS to locate services and authenticate. Correct DNS configuration must be in place before domain joining or Kerberos authentication will fail.