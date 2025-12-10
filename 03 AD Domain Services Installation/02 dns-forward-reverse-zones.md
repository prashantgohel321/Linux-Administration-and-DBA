# dns-forwards-reverse-zones.md

- In this file I am configuring <mark><b>forward and reverse DNS zones</b></mark> on the newly promoted Domain Controller. AD depends on DNS to locate domain controllers and services. Although the promotion wizard already created the basic forward zone, I need to understand how it works, why reverse lookup zones matter, and how DNS actually resolves names and IPs inside an AD environment.

---

- [dns-forwards-reverse-zones.md](#dns-forwards-reverse-zonesmd)
  - [Why DNS Zones Exist in AD](#why-dns-zones-exist-in-ad)
  - [Forward Lookup Zones](#forward-lookup-zones)
  - [Reverse Lookup Zones](#reverse-lookup-zones)
  - [How Reverse Zones Are Named](#how-reverse-zones-are-named)
  - [Creating the Reverse Lookup Zone](#creating-the-reverse-lookup-zone)
  - [Dynamic Updates](#dynamic-updates)
  - [Testing Forward Resolution](#testing-forward-resolution)
  - [Testing Reverse Resolution](#testing-reverse-resolution)
  - [Why Linux Must Use This DNS](#why-linux-must-use-this-dns)
  - [What I Achieve After This File](#what-i-achieve-after-this-file)


<br>
<br>

## Why DNS Zones Exist in AD

- A DNS zone is a section of the DNS namespace that a DNS server is responsible for. When I create a domain such as `gohel.local`, the Domain Controller becomes the authoritative DNS server for that zone. This means it holds the DNS records that define how names inside that domain resolve to IP addresses.

- AD integrates tightly with DNS, so domain controllers automatically register service records, host records, and locator records. Without a working zone, none of this would function.

---

<br>
<br>

## Forward Lookup Zones

- A forward lookup zone resolves names to IP addresses. For example, when a client tries to contact `dc01.gohel.local`, the forward lookup zone contains an A record (address record) that points to the IP of the domain controller. The DNS server answers this lookup so the client knows where to connect.

- When I promoted the server to a Domain Controller, the promotion wizard automatically created a forward zone for `gohel.local`. This contains essential service (SRV) records that tell clients where Kerberos and LDAP services live. These records are essential for authentication.

---

<br>
<br>

## Reverse Lookup Zones

- A reverse lookup zone does the opposite of a forward zone. It resolves IP addresses back to host names. Reverse DNS is not required for AD authentication, but it provides useful functionality and improves troubleshooting.

- When diagnosing network problems, reverse lookups help confirm that the DNS server understands both the host name and the IP address. Some services also rely on reverse lookups for logging or validation. Having a reverse zone makes the environment more complete.

---

<br>
<br>

## How Reverse Zones Are Named

- Reverse lookup zones use a special naming format based on network addresses. For example, if my Domain Controller has the address `192.168.100.10`, the reverse zone name is something like:

```bash
100.168.192.in-addr.arpa
```

- This structure uses the IP network reversed. The DNS server uses these names to perform reverse lookup requests.

---

<br>
<br>

## Creating the Reverse Lookup Zone

- To create a reverse lookup zone, I open DNS Manager on the Domain Controller and choose New Zone. I select Primary Zone because this Domain Controller is authoritative. I then enter the network portion of the subnet. VMware NAT networks typically use private IP ranges such as 192.168.x.x, so I enter the appropriate network.

- After creation, I can add a PTR record that maps IP addresses to names. When a client registers itself dynamically, the PTR record is often created automatically.

---

<br>
<br>

## Dynamic Updates

- AD uses dynamic DNS updates to create and update DNS records automatically. When the Domain Controller starts, it registers its service records. When a client joins the domain, it registers forward and sometimes reverse records if permissions allow.

- Dynamic updates mean I do not need to manually create most DNS records. The DNS server and AD work together to keep the zone up to date.

---

<br>
<br>

## Testing Forward Resolution

- After the zones are configured, I test name resolution. From the Domain Controller, I run:

```bash
ping dc01.gohel.local
```

- This confirms that the DNS server resolves the hostname to the correct IP. If this fails, either the zone is incorrect or the DNS service is not running properly.

---

<br>
<br>

## Testing Reverse Resolution

- To test reverse resolution, I use:

```bash
ping -a <ip-address>
```

- If the reverse zone is configured correctly, the response displays the hostname. If it only shows the IP address, the reverse lookup is not working. This does not break AD, but fixing it improves diagnostics.

---

<br>
<br>

## Why Linux Must Use This DNS

- When I join Rocky Linux to the domain, Linux must use this DNS server for lookups. If Linux uses a public DNS such as 8.8.8.8, it will not find the domain controllers or Kerberos services. The join operation would fail.

- This is a common mistake. Most domain join issues are caused by incorrect DNS settings.

---

<br>
<br>

## What I Achieve After This File

- By configuring forward and reverse lookup zones, I ensure that AD has complete DNS functionality. The forward zone handles name resolution required for authentication, while the reverse zone improves diagnostics and keeps DNS information consistent. This prepares the environment for Linux domain integration, Kerberos authentication, and future troubleshooting.