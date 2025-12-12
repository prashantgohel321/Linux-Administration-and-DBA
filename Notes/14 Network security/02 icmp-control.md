# icmp-control.md

This file is a complete, practical guide to **controlling ICMP on Linux** using firewalld, nftables, sysctl, and SELinux where relevant. ICMP is not optional — it is a core part of IP networking. But attackers also misuse it for scanning, discovery, covert channels, and DDoS.

You will learn exactly which ICMP types to allow or block, how enterprises handle ICMP, how to test ICMP behavior, and how to troubleshoot failures.

---

# 1. What ICMP actually is (and why blocking it blindly breaks things)

ICMP (Internet Control Message Protocol) is not for data transfer — it carries diagnostic and control messages such as:
- **echo-request (type 8)** → ping request
- **echo-reply (type 0)** → ping response
- **destination-unreachable (type 3)** → routing errors
- **time-exceeded (type 11)** → traceroute
- **fragmentation-needed (type 3, code 4)** → Path MTU Discovery

If you block ICMP blindly:
- traceroute breaks
- MTU discovery fails → causing slow connections & packet loss
- VPNs and large-packet applications break
- diagnosing network problems becomes much harder

Enterprises rarely block all ICMP — they **limit or shape it**.

---

# 2. Common enterprise ICMP policies

Typical secure ICMP policy:
- allow **echo-request** from internal networks
- block or rate-limit echo-request from external networks
- allow **echo-reply** (safe)
- allow **time-exceeded**, **fragmentation-needed** (mandatory for routing)
- allow ICMPv6 essential messages (ICMPv6 is mandatory)

ICMPv6 *cannot* be fully blocked — it will break IPv6 entirely.

---

# 3. Checking current ICMP rules in firewalld

List all rules in active zone:
```
firewall-cmd --list-all
```
Check rich rules:
```
firewall-cmd --list-rich-rules
```

Check nftables rules (backend):
```
nft list ruleset | grep icmp
```

---

# 4. Allow or block ICMP using firewalld (rich rules)

### Block all ICMP echo-request (ping) from everywhere
```
firewall-cmd --add-rich-rule='rule protocol value="icmp" icmp-type name="echo-request" drop' --permanent
firewall-cmd --reload
```

### Allow ping only from internal subnet
```
firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" icmp-type name="echo-request" accept' --permanent
```

### Block ping from external networks but allow internal
```
firewall-cmd --add-rich-rule='rule family="ipv4" source address="0.0.0.0/0" icmp-type name="echo-request" drop' --permanent
firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" icmp-type name="echo-request" accept' --permanent
```

### Allow essential ICMP (do NOT block these)
```
firewall-cmd --add-rich-rule='rule protocol value="icmp" icmp-type name="destination-unreachable" accept' --permanent
firewall-cmd --add-rich-rule='rule protocol value="icmp" icmp-type name="time-exceeded" accept' --permanent
```

These are required for routing.

---

# 5. ICMP logging (detect scanning & reconnaissance)

### Log and drop ping requests
```
firewall-cmd --add-rich-rule='rule icmp-type name="echo-request" log prefix="ICMP-DROP:" level="info" drop' --permanent
```
Check logs:
```
journalctl -f | grep ICMP-DROP
```

This helps detect:
- ping sweeps
- recon before attacks
- misconfigured monitoring systems

---

# 6. Sysctl-based ICMP control (host-level stack)

firewalld controls packet filtering, but Linux kernel also has ICMP behavior settings.

### Block responding to pings
```
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all
```
Make persistent:
```
echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
sysctl -p
```

### Ignore broadcast ping (prevent Smurf attacks)
```
echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
```

### Rate-limit ICMP (prevent ICMP flood)
```
echo "net.ipv4.icmp_ratelimit = 100" >> /etc/sysctl.conf
sysctl -p
```

### Rate-limit ICMP error responses
```
echo "net.ipv4.icmp_ratemask = 88089" >> /etc/sysctl.conf
```

**Warning:**  
Blocking ICMP at sysctl level applies globally and bypasses firewalld granularity.
Use only when needed.

---

# 7. ICMPv6 control (separate from IPv4)

ICMPv6 is mandatory for IPv6 networking:
- Neighbor Discovery
- Router Advertisements
- SLAAC

Blocking ICMPv6 breaks IPv6 entirely.

Firewalld allows controlling specific ICMPv6 types:

### Block ICMPv6 echo-request
```
firewall-cmd --add-rich-rule='rule family="ipv6" icmp-type name="echo-request" drop' --permanent
```

### Allow essential ICMPv6
```
firewall-cmd --add-rich-rule='rule family="ipv6" icmp-type name="router-advertisement" accept' --permanent
firewall-cmd --add-rich-rule='rule family="ipv6" icmp-type name="neighbor-solicitation" accept' --permanent
firewall-cmd --add-rich-rule='rule family="ipv6" icmp-type name="neighbor-advertisement" accept' --permanent
```

---

# 8. Testing ICMP filtering

### Test ping
```
ping -c 3 <server-ip>
```

### Test from a specific source
```
ping -I eth0 <server-ip>
```

### Test traceroute (ICMP type 11: time-exceeded)
```
traceroute <server-ip>
```

If traceroute fails after first hop, you blocked ICMP time-exceeded.

### Test MTU Path Discovery
```
ping -M do -s 1472 <server-ip>
```
If this fails unexpectedly, **fragmentation-needed** ICMP messages are blocked.

---

# 9. Troubleshooting ICMP

### Problem: traceroute shows only one hop
Cause: ICMP type 11 blocked.
Fix:
```
firewall-cmd --add-rich-rule='rule protocol value="icmp" icmp-type name="time-exceeded" accept' --permanent
```

### Problem: VPN or SSH very slow
Cause: Path MTU discovery broken.
Fix:
```
firewall-cmd --add-rich-rule='rule protocol value="icmp" icmp-type name="fragmentation-needed" accept' --permanent
```

### Problem: Monitoring tools cannot ping server
Fix: allow internal ping
```
firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" icmp-type name="echo-request" accept' --permanent
```

### Problem: Server not responding to ping even though rule exists
Check sysctl:
```
cat /proc/sys/net/ipv4/icmp_echo_ignore_all
```
If it is `1`, the kernel blocks ping globally.

### Problem: Unexpected ICMP logs
Check:
```
journalctl -f | grep ICMP
```
Often caused by scanners or misconfigured monitoring systems.

---

# 10. Best practices for ICMP control

- Never block essential ICMP types (time-exceeded, fragmentation-needed).
- Allow ping from internal trusted networks.
- Block or rate-limit ping from public internet.
- Enable sysctl protections for broadcast ICMP.
- Do not fully block ICMPv6 — IPv6 requires it.
- Use rich rules for granular ICMP control.
- Always test after changing ICMP behavior.

---

# 11. Cheat sheet
```
# block ping
firewall-cmd --add-rich-rule='rule icmp-type name="echo-request" drop' --permanent

# allow internal ping
firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" icmp-type name="echo-request" accept' --permanent

# log ICMP before drop
firewall-cmd --add-rich-rule='rule icmp-type name="echo-request" log prefix="ICMP-DROP:" drop' --permanent

# sysctl block ping
echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
```

---

# What you achieve after this file

You will be able to fully understand, control, filter, log, allow, and troubleshoot all ICMP behavior on Linux using firewalld, sysctl, and nftables. You will also avoid the common mistakes that break routing, VPN, MTU discovery, and IPv6.

This is enterprise-grade ICMP control, not guesswork.