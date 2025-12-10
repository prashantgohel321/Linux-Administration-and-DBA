# services-section.md

In this file I am explaining the **services section** inside `sssd.conf`. This section defines which internal SSSD services are enabled, what they do, and how they interact with other components such as NSS, PAM, SSH, and sudo. Many people overlook this section, but one missing service can break authentication or identity lookup.

---

## What the services section looks like

In the top `[sssd]` section of `sssd.conf` I normally see:
```
[sssd]
services = nss, pam
```

Sometimes more services are enabled depending on features:
```
services = nss, pam, sudo, ssh
```

This tells SSSD which internal subsystems to start.

---

## Why services matter

Each SSSD service handles a specific function:
- `nss` resolves users and groups (id, getent)
- `pam` performs authentication via pam_sss.so
- `sudo` provides sudo rules from AD (optional)
- `ssh` retrieves SSH public keys from directory (optional)

If a service is missing, that functionality fails.

---

## nss service

`nss` is responsible for mapping AD users and groups into Linux identities.

If `nss` is missing:
- `id testuser1` fails
- `/etc/passwd` local lookup still works, but AD users are invisible

Check with:
```
bin/getent passwd testuser1
```

If nothing shows, NSS integration is broken.

---

## pam service

`pam` handles authentication requests via PAM. When a user executes SSH or `su` or logs into console, PAM calls `pam_sss.so`, which calls SSSD `pam` service.

If `pam` is missing:
- AD users cannot authenticate
- `id` might still work (NSS ok), but logins fail

This is a common troubleshooting scenario.

---

## sudo service (optional)

If I want sudo policies to come from AD:
```
sudo_provider = ad
```

And enable service:
```
services = nss, pam, sudo
```

This allows the server to fetch sudo rules via SSSD instead of local `/etc/sudoers`. This is a powerful enterprise feature but not required in small lab setups.

If sudo is misconfigured and I enable this without proper AD configuration, sudo might stop working until fixed.

---

## ssh service (optional)

For retrieving SSH public keys stored in LDAP/AD:
```
services = nss, pam, ssh
```

Then configure:
```
ssh_provider = ad
```

This allows central management of SSH keys in AD.

---

## Understanding service dependencies

- For AD logins, `nss` and `pam` are mandatory
- Without `nss`, identity lookup fails
- Without `pam`, authentication fails
- `sudo` and `ssh` are optional

This mapping helps isolate failures quickly.

---

## Check running services

SSSD runs a process per service. I can verify using:
```
ps aux | grep sssd
```

I should see separate processes for each enabled service, like:
```
sssd[nss]
sssd[pam]
```

If a service is missing, it might not be enabled or SSSD failed to load it.

---

## Restarting and validating services

After editing `sssd.conf`:
```
systemctl restart sssd
```

Then check status:
```
systemctl status sssd
```

If SSSD refuses to start, check logs:
```
tail -f /var/log/sssd/sssd.log
```

---

## Troubleshooting

### Identity works but authentication fails
- `pam` might be missing
- PAM stack might not include pam_sss.so
- Kerberos might be broken underneath

### Authentication works but `id testuser1` fails
- `nss` missing
- `sss` missing from /etc/nsswitch.conf

### sudo rules not working
- sudo service not enabled

---

## Complete practical checklist

1. Ensure `services = nss, pam`
2. Restart SSSD
3. `id testuser1` (tests nss)
4. `su - testuser1` (tests pam)
5. For sudo integration, enable sudo and test
6. For ssh key integration, enable ssh and test

If any of these commands fail, focus on the missing or failing service.

---

## What I achieve after this file

By understanding the services section, I know which SSSD subsystems are required for AD logins, which are optional, and how to verify each one. When AD authentication breaks, I know how to check the right component instead of guessing.