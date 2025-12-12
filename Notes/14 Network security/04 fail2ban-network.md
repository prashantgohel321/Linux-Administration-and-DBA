# nmap-defense.md

This file is a practical, hands‑on guide to defending systems against reconnaissance and scanning with **nmap** and similar tools. It covers how scanners work, how to detect and slow them down, how to tune firewalls and IDS to mitigate scanning, how to harden services so scanning yields minimal useful information, and how to respond operationally to active scans. Everything here is command-first and tested in real environments.

This is for sysadmins who must harden servers and networks against reconnaissance that precedes attacks.

---

# 1. Why nmap matters

nmap is the attacker’s first tool. It discovers hosts, open ports, services, versions, and sometimes operating systems. If you can reduce what nmap reveals or detect it early, you drastically reduce attackers’ ability to plan exploits.

Key goals:
- make scans slow and noisy so they are detectable
- minimize exposed surface area (open ports, banners, protocols)
- ensure detection (logging, IDS alerts)
- block and throttle suspicious sources

---

# 2. Types of scans and what they reveal

nmap has many modes; defenders must understand the common ones:

- **TCP SYN scan (-sS)**: fast, stealthy, sends SYN and reads response (SYN/ACK=open, RST=closed)
- **TCP Connect scan (-sT)**: completes full TCP handshake; noisier
- **UDP scan (-sU)**: slower; tests UDP services and ICMP unreachable
- **Service/version detection (-sV)**: probes services for banners and versions
- **OS detection (-O)**: fingerprinting based on TCP/IP stack behavior
- **Aggressive scan (-A)**: runs -sV -O -sC (default scripts)
- **Timing templates (-T0..T5)**: controls speed; T4/T5 are fast
- **Stealthy timing + fragmenting (--mtu, -f)**: evade simple IDS

Knowing these, defenders can tune responses and detection.

---

# 3. Reduce surface area — the primary defense

The most effective defense is limiting what is exposed.

1. **Close unused ports**. Services should not listen on any port not required.
   ```
   ss -tulnp
   systemctl disable --now unused-service
   ```
2. **Bind services to management interfaces only** (127.0.0.1 or internal NIC) when public access is unnecessary.
   Example for a web app that only needs a reverse proxy on public interface:
   - App listens on 127.0.0.1:8080
   - Nginx listens on public interface and proxies to 127.0.0.1:8080
3. **Use firewall rules to restrict access** to known IP ranges and management hosts.
   ```
   firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="203.0.113.0/24" service name="ssh" accept' --permanent
   firewall-cmd --reload
   ```
4. **Disable unnecessary protocols** (FTP, Telnet, SMBv1). Remove packages.
   ```
   yum remove vsftpd telnet-server -y
   ```

---

# 4. Hide or sanitize banners and versions

Service banners reveal software and version information. Remove or modify them:

- **SSH**: disable `DebianBanner` or set `Banner` to a minimal message in `/etc/ssh/sshd_config`.
  ```
  # /etc/ssh/sshd_config
  Debi anBanner no
  Banner /etc/issue.net
  ```
- **HTTP servers**: remove `Server` header and disable `ServerTokens` in Apache or `server_tokens off;` in Nginx.
  ```
  # nginx.conf
  server_tokens off;
  proxy_set_header X-Server "hidden";
  ```
- **FTP/SMTP/other**: configure software to minimize version strings or use a reverse proxy that rewrites headers.

After changes, restart services and test with nmap service detection:
```
nmap -sV -p 22,80,443 <ip>
```

---

# 5. Detecting scans — logging and IDS

Detection is how you turn recon into actionable intelligence.

### Host-based logging
- Enable and monitor `sshd` logs, web server logs, and connection logs. Fail2Ban can escalate repeated attempts.
```
# watch auth logs
tail -f /var/log/secure
# fail2ban status
a fail2ban-client status sshd
```

### Network IDS (Suricata/Zeek/snort)
- Deploy an IDS at the network edge. Suricata has rules to detect fast port scans and nmap signatures.
- Example: install Suricata and enable scan-detect rulesets (Emerging Threats or ET Open).

### Detect scanning patterns
- Rapid connection attempts across multiple ports from single IP
- Many different destination ports in a short time window
- SYN-only patterns (SYN scan)

### Use firewall logs
- Configure firewalld rich rules to log dropped packets and watch for patterns.
```
firewall-cmd --add-rich-rule='rule family="ipv4" source address="0.0.0.0/0" log prefix="FW-DROP:" level="info" drop' --permanent
```

Aggregate logs to SIEM/ELK and create rules for:
- >100 ports scanned by same IP in 60s
- >10 different TCP ports probed in 30s

---

# 6. Slow down scanners — make scanning expensive

If a scan takes longer, it's more likely to be noticed. Techniques:

### 1. Rate-limit and tarpit connections
- **Tarpit**: intentionally slow or hold TCP connections (e.g., `xt_TARPIT` in iptables) so scanners wait and exhaust resources.
- Example with nftables (simple drop delay concept):
```
# nftables rate limit example (pseudo)
nft add table inet filter
nft 'add chain inet filter input { type filter hook input priority 0; ct state established,related accept; tcp dport ssh limit rate 10/minute accept; tcp dport ssh drop }'
```

### 2. Use SYN cookies and kernel tuning
Enable SYN cookies and tune backlog to avoid resource exhaustion:
```
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
sysctl -w net.ipv4.tcp_syncookies=1
```

### 3. Use TCP wrappers and fail2ban to block aggressive scanners
Fail2Ban can ban IPs that probe many ports or cause many failures.

---

# 7. Block known scanners and blocklists

- Use threat intelligence feeds and blocklists (e.g., ipset) to drop traffic from known scanner networks and hosting providers used by attackers.
- Example: create an ipset and add to firewalld:
```
firewall-cmd --permanent --new-ipset=f2b-blacklist --type=hash:ip
firewall-cmd --permanent --ipset=f2b-blacklist --add-entry=198.51.100.23
firewall-cmd --reload
```
- Automate feed updates with scripts or services like CrowdSec.

---

# 8. Honeypots and deception

Deploy a low-interaction honeypot (Cowrie, Dionaea) to catch scanners and attackers and gather TTPs. Honeypots increase noise for attackers and can feed blocklists.

Ensure honeypot is isolated from production networks.

---

# 9. Responding to an active scan

When you detect a scan:
1. Record the source IP, ports scanned, and timestamps. Preserve logs in SIEM.  
2. Temporarily block the IP using firewall/ipset.  
   ```
   firewall-cmd --permanent --ipset=f2b-blacklist --add-entry=198.51.100.23
   firewall-cmd --reload
   ```
3. If the scan originates from a cloud provider, consider reporting abuse. Do not automatically escalate to blocking large cloud CIDRs without context.  
4. If scan targets many hosts, investigate for coordinated reconnaissance and apply network-level mitigations (edge ACLs).  
5. Optionally deploy tarpit for that IP to slow further reconnaissance.

---

# 10. Hardening network stack against fingerprinting

- Disable unnecessary protocol responses. For example, limit ICMP replies to avoid exposing TTL/DF behavior used by OS detection. But never block essential ICMP types needed for MTU discovery.
- Use consistent TCP/IP stack settings across hosts to reduce unique fingerprints. Kernel tuning in `/etc/sysctl.conf` can help standardize behavior.
- Keep system time and clocks consistent (NTP/chrony) to avoid timing-attack fingerprints.

---

# 11. Test your defenses — offensive testing methodology

You must test like an attacker but in a controlled manner:

1. **Internal testing** with nmap from a trusted host:
```
# quick discovery
nmap -sS -T4 -p- target
# service detection and scripts
nmap -sV -sC -p22,80,443 target
# UDP scan (slow)
nmap -sU -p 53,123 target
```
2. **External testing** from a separate network to emulate Internet scanning.  
3. **Measure logging**: ensure SIEM receives events for scans and triggers alerts.  
4. **Run scans with varied timing** to test detection for stealthy scans: `-T2` and fragmenting options. If stealthy scans are not detected, tune IDS rules and firewall logging.

---

# 12. Practical recipes (copy-paste)

### 1. Quick ipset block and reference in firewalld
```
# create ipset
ipset create badips hash:ip
ipset add badips 198.51.100.23
# make persistent and used by firewalld
firewall-cmd --permanent --new-ipset=badips --type=hash:ip
firewall-cmd --permanent --ipset=badips --add-entry=198.51.100.23
firewall-cmd --reload
```

### 2. Fail2Ban jail for portscan-like behavior (custom filter)
Create `/etc/fail2ban/filter.d/portscan.conf` with regex matching many connection attempts, then add jail config in `/etc/fail2ban/jail.d/portscan.local` with `maxretry` low and short `bantime`.

### 3. Suricata rule to detect SYN scan
```
alert tcp any any -> $HOME_NET any (msg:"SYN_SCAN_DETECT"; flags:S; threshold:type both, track by_src, count 30, seconds 60; sid:1000001; rev:1;)
```

---

# 13. Operational considerations and false positives

- Scanners from security researchers and monitoring services can trigger defenses. Maintain an `ignoreip`/whitelist for trusted scanners and monitoring hosts.  
- Tune thresholds to balance detection and false positives. Start conservative and tighten over time.  
- Automating blocking is powerful but risky; ensure you have recovery methods (console access, out-of-band management).

---

# 14. Summary checklist

- Close unused ports and bind services to internal interfaces.  
- Sanitize service banners and hide versions.  
- Log firewall drops and aggregate into SIEM.  
- Use IDS rules (Suricata/Snort/Zeek) to detect scans.  
- Use ipset and fail2ban/CrowdSec to block bad IPs and update feeds automatically.  
- Deploy honeypots for intelligence and deception.  
- Test defenses with nmap from trusted hosts and tune detection rules.

---

# What you achieve after this file

You will be able to detect, slow, and mitigate most reconnaissance attempts with a practical combination of system hardening, firewall tuning, logging/IDS, and operational playbooks. You will understand attacker tooling and how to make scanning expensive, noisy, and ineffective.
