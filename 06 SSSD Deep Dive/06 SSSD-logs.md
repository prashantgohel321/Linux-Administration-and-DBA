# SSSD-logs.md

In this file I am focusing only on SSSD logs. When authentication fails, most people look in the wrong place. SSSD creates multiple log files and each one serves a purpose. I want to understand exactly where to look, how to read logs, how to increase verbosity, and how to trace a failed login in real time.

---

## Where SSSD keeps its logs

All SSSD logs live under:
```
/var/log/sssd/
```

Inside this directory I will find several log files:

- `sssd.log` (main service log)
- `sssd_pam.log` (authentication related)
- `sssd_nss.log` (identity lookup)
- `sssd_{domain}.log` (domain-specific issues, ex: sssd_gohel.local.log)

These files are updated when SSSD runs and are the primary source of truth for diagnosing failures.

---

## The most important logs

### sssd_pam.log

This log shows authentication attempts, including why SSSD accepted or denied login. When a user fails login, I always check this file.

Tail the log in real-time:
```
tail -f /var/log/sssd/sssd_pam.log
```

Then try logging in from another terminal. I should see exactly what SSSD does.

### sssd_nss.log

This log shows identity lookup problems. If `id testuser1` fails, this is the log to check.

```
tail -f /var/log/sssd/sssd_nss.log
```

### domain-specific logs

```
tail -f /var/log/sssd/sssd_gohel.local.log
```

This log focuses on communication with Active Directory specifically.

---

## Log levels

By default SSSD logs at an informational level. When troubleshooting, I may want to increase verbosity.

In `/etc/sssd/sssd.conf` inside the domain section:
```
debug_level = 9
```

Higher values give more detail. Valid levels range from 0 to 9. Level 9 is extremely verbose.

After editing sssd.conf, restart:
```
systemctl restart sssd
```

---

## Checking service-wide log

The file `sssd.log` contains general startup, shutdown, and service initialization messages. If SSSD refuses to start, the reason is usually here.

```
tail -f /var/log/sssd/sssd.log
```

---

## Searching logs

Use grep to filter specific entries:
```
grep -i error /var/log/sssd/*.log
```

Or search for a specific username:
```
grep testuser1 /var/log/sssd/*.log
```

---

## Typical failures visible in logs

### KDC unreachable
Logs show failed Kerberos calls and DNS lookup errors. Usually means DNS is wrong.

### Account disabled
Logs show access denied because account is disabled in AD. This is expected behavior.

### Preauthentication failed
Usually wrong password or Kerberos mismatch.

### offline
If DC unreachable, logs mention offline authentication using cached credentials.

---

## Real-time troubleshooting workflow

1. Open two terminals
2. In first:
```
tail -f /var/log/sssd/sssd_pam.log
```
3. In second: try login or `su - testuser1`
4. Watch live output for deny/allow reasons

This is the fastest method to understand failures.

---

## When logs are empty

If logs show nothing, SSSD might not be running. Check:
```
systemctl status sssd
```

If SSSD is stopped, nothing will be logged. Start it and retry.

---

## Log cleanup

Over time logs grow large. For lab environments, I can remove old logs:
```
rm /var/log/sssd/*.log
systemctl restart sssd
```

For production, logrotate should manage them.

---

## What I achieve after this file

By understanding SSSD logs, I know exactly where authentication failures occur, how to trace identity problems, and how to capture errors in real time. This is essential for troubleshooting failed AD logins, PAM interactions, and Kerberos issues.