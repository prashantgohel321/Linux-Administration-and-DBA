# fail2ban.md

This file is a complete, practical guide to **Fail2Ban** for Linux hardening. Fail2Ban is one of the fastest ways to block repeated brute-force or abusive connection attempts at the network level by parsing service logs and dynamically inserting firewall rules. This guide is hands-on: exact commands, configuration files, regex testing, interactions with firewalld/iptables/nftables, how to handle SSH/sshd+AD/SSSD interactions, tuning, monitoring, and recovery.

Everything here is written for a Rocky Linux / RHEL-like environment, but most commands work on Debian/Ubuntu with small differences noted.

---

# 1. What Fail2Ban does and when to use it

Fail2Ban monitors one or more log files for patterns that indicate abusive behaviour (failed SSH logins, repeated HTTP 401 responses, repeated SMTP auth failures), then automatically blocks offending IPs using firewall rules for a specified time. Use it to reduce noise from automated attacks and to protect exposed services when you cannot disable them.

Fail2Ban is not a replacement for proper authentication hardening (strong passwords, keys, MFA). It is a defensive layer that buys time and reduces noise.

---

# 2. Installing Fail2Ban

On Rocky/RHEL-compatible systems (EPEL required in some releases):

```
# as root or sudo
yum install epel-release -y      # if EPEL not already enabled
yum install fail2ban -y
# or on dnf systems
dnf install epel-release -y
dnf install fail2ban -y
```

On Debian/Ubuntu:

```
apt update
apt install fail2ban -y
```

After install, the service is `fail2ban` (systemd). Start and enable:

```
systemctl enable --now fail2ban
systemctl status fail2ban
```

Check default location of config files:
- `/etc/fail2ban/jail.conf` (do not edit directly)
- `/etc/fail2ban/jail.d/*.conf` (drop-in configs)
- `/etc/fail2ban/jail.local` (local overrides/preferences)
- filter definitions in `/etc/fail2ban/filter.d/*.conf`

---

# 3. Basic concepts and files

`jail` — association of a service, filter, and action. A jail defines which log file to watch, which filter (regex) to apply, ban time, find time, maxretry, and action to perform (iptables, firewalld, nftables).

`filter` — a set of regular expressions used to detect offending log lines. Filters live under `/etc/fail2ban/filter.d/`.

`action` — the command that enforces the block (e.g., insert an iptables rule or call `firewall-cmd`). Actions are defined in `/etc/fail2ban/action.d/`.

`bantime` — how long to ban an IP (seconds or using `m`/`h` suffixes). Use `-1` for permanent bans.

`findtime` — the time window in which `maxretry` failures count.

`maxretry` — how many matches trigger a ban within `findtime`.

---

# 4. Safe configuration workflow

1. Never edit `/etc/fail2ban/jail.conf` directly. Create `/etc/fail2ban/jail.local` or a file in `/etc/fail2ban/jail.d/` instead.
2. Start with a single, non-critical jail for testing (e.g., `sshd`), use short `bantime` and low `maxretry` to validate behavior.
3. Use `fail2ban-regex` to test filters before enabling a jail.
4. Monitor logs while testing.

Create a minimal `/etc/fail2ban/jail.d/local.conf` example:

```
[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/secure
maxretry = 5
bantime = 600
findtime = 600

# optional: use firewalld action if you use firewalld
banaction = firewallcmd-ipset
```

Reload fail2ban after edits:

```
systemctl reload fail2ban
```

---

# 5. SSH jail — the most important one

Fail2Ban includes a built-in `sshd` filter. Use it to reduce brute force attempts against SSH. Example tuned settings for production:

```
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/secure
maxretry = 6
findtime = 600     # 10 minutes
bantime = 3600     # 1 hour
banaction = firewallcmd-ipset   # for firewalld; use iptables-multiport on iptables
ignoreip = 127.0.0.1/8 ::1    # add admin office IPs or jump hosts here
```

Notes and tips:
- `ignoreip` should include your management networks and any jump hosts or VPNs.
- If you use SSH keys primarily, brute-force attacks will still attempt passwords; Fail2Ban will block the attacking IPs.
- When integrating with AD/SSSD: repeated failures from the same IP due to wrong passwords (e.g., user typed domain\user incorrectly) will still be caught. However, be careful with shared NAT IPs (e.g., cloud provider load balancers) — you may inadvertently block many users.

---

# 6. Testing filters with fail2ban-regex

`fail2ban-regex` lets you test a filter against a sample logfile or with a manual string.

Example: test the sshd filter against current logs:

```
fail2ban-regex /var/log/secure /etc/fail2ban/filter.d/sshd.conf
```

Test a single line:

```
echo "sshd[10234]: Failed password for invalid user admin from 1.2.3.4 port 54611 ssh2" | fail2ban-regex - /etc/fail2ban/filter.d/sshd.conf
```

If `fail2ban-regex` reports matches, your filter works. If not, adjust the filter regex in `/etc/fail2ban/filter.d/`.

---

# 7. Actions and firewall backends (firewalld / iptables / nftables)

Fail2Ban can use different backends.

## Firewalld (recommended on RHEL/Rocky)
Use `banaction = firewallcmd-ipset` or `firewallcmd-rich-rules` for high performance and persistent bans:

```
# in jail config
action = firewallcmd-ipset
```
`firewallcmd-ipset` uses an ipset and single rich-rule to block multiple IPs efficiently.

## iptables
On systems using raw iptables, use `iptables-multiport`:

```
action = iptables-multiport
```

## nftables
If using nftables, use an action that calls nft (may require custom action). Newer Fail2Ban releases include nftables actions.

Important: ensure the action you choose matches the firewall manager you use. Mixing `firewalld` and direct `iptables` commands can lead to conflicts and non-persistent rules.

---

# 8. Persistent bans and ipset

Using ipset with firewalld or nftables makes banning thousands of IPs efficient. `firewallcmd-ipset` is the preferred action on RHEL-based systems that run firewalld.

Check ipsets:
```
firewall-cmd --permanent --get-ipsets
firewall-cmd --info-ipset f2b-sshd
```

To persist ipset across reboots ensure firewalld is correctly configured and the ipset is created by fail2ban or pre-created via firewalld config.

---

# 9. Throttle and rate-limit for services behind reverse proxies

For HTTP/HTTPS behind reverse proxies, use jails for `nginx-http-auth` or custom web filters. Be mindful of legitimate clients behind shared IPs or CDNs. For rate-limiting, prefer using the web server’s rate-limiting features (e.g., `limit_req` in nginx) in addition to Fail2Ban.

---

# 10. Logs and monitoring

Fail2Ban logs to:
- `/var/log/fail2ban.log`
- systemd journal (`journalctl -u fail2ban`)

To watch bans live:

```
tail -f /var/log/fail2ban.log
```

To see active jails and bans:

```
fail2ban-client status
fail2ban-client status sshd          # shows banned IPs and counts
```

To unban an IP manually:

```
fail2ban-client set sshd unbanip 1.2.3.4
```

To ban an IP manually:

```
fail2ban-client set sshd banip 1.2.3.4
```

---

# 11. Whitelisting and ignoreip

Always configure `ignoreip` to include your management IPs, VPNs, or office networks. `ignoreip` accepts space-separated addresses and CIDRs.

Example:

```
ignoreip = 127.0.0.1/8 10.0.0.0/8 203.0.113.4
```

If you use dynamic jump boxes with changing IPs, consider automating updates to `ignoreip` and reloading fail2ban.

---

# 12. Dealing with shared NAT or Cloud provider IPs

Be careful: blocking a cloud provider NAT IP can block many legitimate users. If you observe high false positives from a single shared IP, tune `findtime`/`maxretry` or block using temporary bans rather than permanent ones. Consider using `recidive` jail to escalate repeat offenders to longer bans.

---

# 13. Wildcards, regex and filter tuning

Filters are regex-based and live in `/etc/fail2ban/filter.d/*`. When modifying or creating filters:

1. Use `fail2ban-regex` to validate against existing logs.
2. Prefer anchored regex to avoid accidental matches.
3. Watch the logs for unexpected matches.

Example: a custom filter for an application that logs `AUTH FAIL` lines

```
# /etc/fail2ban/filter.d/myapp.conf
[Definition]
failregex = ^%(__prefix_line)sAUTH FAIL .* from <HOST>
ignoreregex =
```

`%(__prefix_line)s` helps match fail2ban log prefixes and keep patterns robust.

---

# 14. Recidive jail — punish repeat offenders across time

Fail2Ban ships a `recidive` jail to catch IPs that keep getting banned across many jails. Example configuration for long-term escalation:

```
[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
action = iptables-allports[name=recidive]
bantime = 604800    # 1 week
findtime = 86400    # 1 day
maxretry = 5
```

This uses the fail2ban log itself as input and bans IPs that were banned multiple times in a day.

---

# 15. Fail2Ban and SSSD/AD specifics

When using AD (SSSD), failed SSH attempts may originate from real users or from attackers. Fail2Ban works the same way: it blocks IPs not usernames. A few caveats:

- Shared NAT addresses in your network or remote office may cause collateral bans. Whitelist known office IPs in `ignoreip`.
- If AD agent or Kerberos misconfiguration generates many errors from your own DC IPs, whitelist DC IPs to avoid self-ban.
- Use `banaction` that works with your firewall manager (firewallcmd-ipset for firewalld). Avoid direct iptables action on firewalld-managed systems unless you know what you're doing.

---

# 16. Performance and scaling

Fail2Ban is single-host oriented and performs well for typical use. For very large fleets or heavy traffic, consider:
- using ipset for efficiency (firewallcmd-ipset)
- centralizing detection in a log pipeline (SIEM) and pushing blocks to edge firewalls for high-volume attacks
- tuning `bantime`, `findtime`, and `maxretry` so bans are effective but not excessive

---

# 17. Integration with logging/alerting and SIEM

Forward `/var/log/fail2ban.log` and `/var/log/secure` to your central syslog/SIEM. Configure alerts for repeated recidive events and high hit rates. This helps identify large-scale attacks and misconfigurations.

---

# 18. Advanced topics

## Docker/containers
When running services in containers, ensure Fail2Ban has access to host logs or use per-container logging drivers. Banning container IPs is usually ineffective (containers share host IP). Instead, ban at the host ingress or orchestrator level.

## IPv6
Fail2Ban supports IPv6 if your filters and actions do. Use `ip6tables` and ensure actions handle IPv6 addresses.

## Custom actions
You can create actions under `/etc/fail2ban/action.d/` that call external scripts or API endpoints (e.g., to update a cloud firewall). Be careful with permissions and performance.

---

# 19. Troubleshooting common issues

1. **Fail2Ban not starting**: check configuration syntax and journal (`journalctl -u fail2ban`). Run `fail2ban-client -v start` for verbose output.
2. **Filter not matching**: run `fail2ban-regex` against the log file and review sample lines. Adjust regex and retest.
3. **Bans not applied**: confirm `banaction` is compatible with the firewall and that fail2ban has permission to run firewall-cmd or iptables. Check `fail2ban.log` for action errors.
4. **IP not unbanned**: check bantime and `fail2ban-client set <jail> unbanip <IP>` to unban manually.
5. **Conflicts with firewalld**: use the firewalld actions (`firewallcmd-*`) and prefer ipset-based actions for performance.

---

# 20. Useful commands summary

```
systemctl status fail2ban
systemctl restart fail2ban
fail2ban-client status
fail2ban-client status sshd
fail2ban-client set sshd banip 1.2.3.4
fail2ban-client set sshd unbanip 1.2.3.4
fail2ban-regex /var/log/secure /etc/fail2ban/filter.d/sshd.conf
tail -f /var/log/fail2ban.log /var/log/secure
```

---

# 21. Example production-ready jail file

Create `/etc/fail2ban/jail.d/sshd.local`:

```
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/secure
maxretry = 6
findtime = 600
bantime = 3600
banaction = firewallcmd-ipset
ignoreip = 127.0.0.1/8 ::1 203.0.113.10/32 10.0.0.0/8
```

Reload and test.

---

# 22. What you achieve after this file

You now have a hands-on, production-focused Fail2Ban guide: how to install, configure, test, tune, and troubleshoot it for SSH and other services, including how to integrate with firewalld and SSSD/AD. This is the operational recipe you can use in your VMware lab and in production with confidence.
