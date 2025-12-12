# ssh-port-change.md

This file provides a **complete, practical, real-world guide** on changing the SSH port on Linux securely. It covers firewall rules, SELinux configuration, testing without locking yourself out, and real attack-surface reasoning.

Changing your SSH port does **not** replace proper security (key authentication, rate limiting, firewall rules), but it reduces noise, automated attacks, and brute-force logs.

This guide ensures you do it safely and without losing access.

---

# 1. Why change the SSH port

By default, SSH listens on port **22**. Attackers constantly scan this port and attempt brute-force logins. Changing the SSH port does not stop targeted attacks, but it drastically reduces:
- log spam in `/var/log/secure`
- botnet brute-force attempts
- load on fail2ban and SSSD

Port changing is a **noise-reduction measure**, not a primary security control.

---

# 2. Important warnings before changing SSH port

If you do this incorrectly, you can lock yourself out of the server.  
Avoid that by following these rules:

1. **Keep your current SSH session open** until the new port is tested.
2. **Add firewall rules BEFORE restarting sshd**.
3. **Use console/VMware console access** when possible.
4. **Test new port in a second terminal** before closing the first session.
5. **Don’t disable port 22** until the new port works.

---

# 3. Step-by-step: safely changing SSH port

You will edit `/etc/ssh/sshd_config`.

### Open the configuration file
```
vi /etc/ssh/sshd_config
```

Find this line:
```
#Port 22
```
Uncomment and change it:
```
Port 2222
```
*(You can choose any unused port between 1024–65535)*

Save the file.

---

# 4. Apply firewall rules BEFORE restarting sshd

Check active zone:
```
firewall-cmd --get-active-zones
```
Example output:
```
public
  interfaces: ens160
```

### Add the new SSH port
```
firewall-cmd --zone=public --add-port=2222/tcp
```
### (Optional) Make it permanent
```
firewall-cmd --zone=public --add-port=2222/tcp --permanent
firewall-cmd --reload
```

### Do NOT remove port 22 yet
You must test port 2222 first.

---

# 5. SELinux configuration (mandatory when SELinux is enforcing)

Check SELinux mode:
```
sestatus
```

If mode is **Enforcing**, SSH will not start on port 2222 unless allowed.

### Add SELinux rule for new port
```
semanage port -a -t ssh_port_t -p tcp 2222
```
If port already exists:
```
semanage port -m -t ssh_port_t -p tcp 2222
```

### Verify
```
semanage port -l | grep ssh_port_t
```

Expected output:
```
ssh_port_t    tcp    22, 2222
```

---

# 6. Restart SSH safely

After firewall + SELinux configuration:
```
systemctl restart sshd
```
Check status:
```
systemctl status sshd
```
If it fails, immediately revert your changes.

---

# 7. Test new SSH port in a second terminal

From another window/machine:
```
ssh -p 2222 user@server_ip
```
If login works → safe to continue.
If it fails → do NOT close your original SSH session.

---

# 8. Removing old port (after verifying new port works)

Remove old rule:
```
firewall-cmd --zone=public --remove-service=ssh --permanent
# OR if defined as port
firewall-cmd --zone=public --remove-port=22/tcp --permanent

firewall-cmd --reload
```

Remove SELinux port association if needed:
```
semanage port -d -t ssh_port_t -p tcp 22
```

*(Optional — usually safe to leave 22 mapped)*

---

# 9. Logging and verification

Check journald for SSH activity:
```
journalctl -u sshd -f
```
Example entries after port change:
```
sshd[1205]: Server listening on 0.0.0.0 port 2222.
sshd[1205]: Server listening on :: port 2222.
```

Check firewall logs if you enabled rich rule logging.

---

# 10. Security considerations after changing SSH port

Changing port is not a replacement for real SSH hardening.  
You still must:
- enable fail2ban
- restrict SSH to specific IPs (preferred)
- disable password login (keys only)
- disable root SSH login
- enforce strong authentication methods (2FA, certificates)

Attackers targeting you will still find the new port using:
- full port scans
- banner fingerprinting
- machine-learning classifiers

But random brute-force noise will drop dramatically.

---

# 11. Troubleshooting

### Issue: SSH stops responding
Check sshd errors:
```
journalctl -u sshd -b
```

### Issue: Can't connect on new port
Check firewall:
```
firewall-cmd --list-ports --zone=public
```
Check SELinux:
```
semanage port -l | grep 2222
```
Check service listening:
```
ss -tulnp | grep 2222
```

### Issue: Locked out completely
Use VMware console access and revert config in `/etc/ssh/sshd_config`.

---

# 12. Cheat sheet
```
# edit config
vi /etc/ssh/sshd_config
Port 2222

# firewall
firewall-cmd --zone=public --add-port=2222/tcp --permanent
firewall-cmd --reload

# SELinux\semanage port -a -t ssh_port_t -p tcp 2222

# restart
systemctl restart sshd
ssh -p 2222 user@server
```

---

# What you achieve after this file

You will be able to change the SSH port **without breaking access**, fully handle firewall and SELinux rules, properly test your configuration, and understand the operational and security impact of the change.