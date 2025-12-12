# ssh-banner.md

This file explains **how to implement, manage, and troubleshoot SSH login banners** in a practical, production-ready way. Banners are the short text messages shown to users before they authenticate. They are used for legal warnings, system identification, or operational notices (maintenance windows). This document contains exact commands, policy examples, safe deployment patterns, and common failure modes you will actually hit in the lab.

No fluff. Clear, step-by-step instructions and the exact commands you will run.

---

# 1. What an SSH banner is and when it appears

An SSH banner is a text file that the SSH server sends to the client **before** authentication completes. It is useful for:

- legal warning messages ("Unauthorized use prohibited")
- system identification and contact info
- temporary operational notices (maintenance, degraded services)

Important behavior notes:
- The banner is displayed to the client before any password or key check (pre-auth). This means it is visible to anyone connecting, authenticated or not.
- The banner is different from `/etc/motd` (message of the day) which is shown after login by PAM or shell startup scripts.
- Banner content must be plain text and should avoid very large sizes; some SSH clients may truncate long banners.

---

# 2. Where to put the banner file

Common, safe location:

```
/etc/issue.net
```

Or create an SSH-specific file:

```
/etc/ssh/ssh_banner
```

Requirements:
- readable by the `sshd` process (usually root). File ownership `root:root` and mode `644` is standard.
- plain ascii/utf-8 text. Avoid control characters (NUL, binary data) and Windows CRLF line endings — use `dos2unix` if needed.

Example file creation:

```
cat > /etc/ssh/ssh_banner <<'EOF'
Unauthorized access to this system is prohibited.
If you do not have permission, disconnect now.
Contact: itops@example.local
EOF
chmod 644 /etc/ssh/ssh_banner
chown root:root /etc/ssh/ssh_banner
```

---

# 3. Configure OpenSSH to use the banner

Edit `/etc/ssh/sshd_config` and set the `Banner` option to the full path of the banner file.

Exact commands:

```
# backup first
cp /etc/ssh/sshd_config /root/sshd_config.bak-$(date +%F-%T)
# set Banner option (use sed to replace or append if missing)
if grep -q "^Banner" /etc/ssh/sshd_config; then
  sed -i "s|^Banner.*|Banner /etc/ssh/ssh_banner|" /etc/ssh/sshd_config
else
  echo "Banner /etc/ssh/ssh_banner" >> /etc/ssh/sshd_config
fi
# reload sshd
systemctl reload sshd
```

On older or alternate systems where the service is named `sshd` or `ssh.service`, use `systemctl reload sshd` or `service sshd reload` accordingly.

---

# 4. Differences: Banner vs MOTD vs PAM messages

- `Banner` (`sshd_config`) — sent before authentication. Best for legal warnings and public notices. Always use this for pre-auth messages.
- `/etc/motd` — shown after login. Often managed by distribution tools (e.g., `update-motd` on Ubuntu). Not suitable for legal warnings that must appear before authentication.
- PAM `pam_motd` / `pam_issue` — PAM can call motd or issue files during session setup. PAM-based messages are post-auth unless you configure PAM differently.

If you need both pre-auth and post-auth messages, use `Banner` for pre-auth and `/etc/motd` (or PAM motd) for post-auth.

---

# 5. Dynamic banners and automation

You may need banners that change frequently (maintenance windows, security notices). Options:

1. **Update the banner file automatically** — write a small script that updates `/etc/ssh/ssh_banner` and reloads `sshd` if needed.

```
# simple update script
cat > /usr/local/bin/update-ssh-banner <<'EOF'
#!/bin/sh
cat > /etc/ssh/ssh_banner <<BEOF
Maintenance window: $(date --iso-8601=minutes)
Expected downtime: 30 minutes
Contact: itops@example.local
BEOF
chmod 644 /etc/ssh/ssh_banner
# reload sshd only if Banner path changed; updating file content is enough for many servers
systemctl reload sshd || true
EOF
chmod +x /usr/local/bin/update-ssh-banner
```

2. **Use configuration management** (Ansible/Chef) to deploy the banner across hosts.
3. **Do not** try to run a program for pre-auth banners via PAM; `pam_exec` runs during session phase (post-auth) and cannot reliably send pre-auth banners.

---

# 6. Legal banner template (example)

Use this template if you intend to show a legal warning. Adapt to your organisation’s policies and legal advice.

```
WARNING: This system is for authorized use only.
By connecting you agree to monitoring and logging of your session.
Unauthorized access is prohibited and may be subject to criminal prosecution.
If you are not authorized, disconnect immediately.
Contact: security@example.local
```

Place the above in `/etc/ssh/ssh_banner` and reload sshd.

---

# 7. Testing the banner

From a client machine, connect and observe the pre-auth output:

```
ssh -o PreferredAuthentications=keyboard-interactive -o PubkeyAuthentication=no user@host
```

The banner should appear before the password prompt. For automated verification, use `ssh -v` to see server messages.

Example test commands:

```
# verbose connect
ssh -vvv user@server 2>&1 | sed -n '1,50p'

# simulate client that shows only preauth stream
printf "\n" | ssh -o BatchMode=no -o PreferredAuthentications=password -o PubkeyAuthentication=no user@server
```

If you do not see the banner:
- Verify `Banner` is present in `/etc/ssh/sshd_config`.
- Verify the banner file path is correct and readable by root.
- Check `sshd` logs: `journalctl -u sshd -f` or `tail -f /var/log/secure`.

---

# 8. Common problems and fixes

Problem: Banner not shown to some clients
- Some clients may suppress banners or have settings that hide pre-auth text. Test with OpenSSH client.
- Old Windows SSH clients or GUI tools sometimes do not display the banner.

Problem: Banner shows weird characters or blank lines
- Likely caused by CRLF line endings (Windows). Fix with `dos2unix /etc/ssh/ssh_banner`.
- Ensure file encoding is UTF-8 without BOM.

Problem: Banner contains sensitive information
- Remember banner is shown pre-auth; do not include secrets, internal IPs, or detailed system internals.

Problem: Banner is extremely long and truncated
- Keep banners short. Clients or the transport may truncate large payloads.

Problem: Banner causes SSHD to fail reload
- If `sshd_config` syntax is incorrect, `systemctl reload sshd` will fail.
- Check syntax: `sshd -t` will validate configuration.

---

# 9. SELinux and file contexts (RHEL/Rocky)

If SELinux is enforcing, ensure the banner file has the correct file context, otherwise `sshd` may not be able to read it.

Check context:

```
ls -Z /etc/ssh/ssh_banner
```

If needed, set the context similar to other readable system files:

```
semanage fcontext -a -t ssh_home_t '/etc/ssh/ssh_banner'  # example type; adjust if necessary
restorecon -v /etc/ssh/ssh_banner
```

If `semanage` not installed, install the policycoreutils-python-utils package or use `chcon` as a quick test.

---

# 10. Audit and compliance considerations

- Store a copy of deployed banners in version control as part of your configuration management.
- If banners include legal text required by compliance, store the approved text and change history.
- Monitor SSH connections and failed attempts via `auditd` or the central logging system; do not rely on the banner itself to enforce policy.

---

# 11. Quick reference commands

Create banner and enable it:

```
cat > /etc/ssh/ssh_banner <<'EOF'
Unauthorized use prohibited. Disconnect now.
EOF
chmod 644 /etc/ssh/ssh_banner
sed -i '/^Banner/d' /etc/ssh/sshd_config || true
echo 'Banner /etc/ssh/ssh_banner' >> /etc/ssh/sshd_config
sshd -t && systemctl reload sshd
```

Validate sshd config:

```
sshd -t
journalctl -u sshd -f
```

Test from client:

```
ssh -vvv user@server 2>&1 | sed -n '1,80p'
```

---

# What you achieve after this file

You now know exactly how to implement, test, and maintain SSH banners safely. You understand the difference between pre-auth banners and post-auth messages, how to automate banner updates, how to avoid common pitfalls (line endings, SELinux, client differences), and how to deploy banners consistently across a fleet.

This file gives you a practical, production-ready recipe for SSH banners in your VMware lab and beyond.
