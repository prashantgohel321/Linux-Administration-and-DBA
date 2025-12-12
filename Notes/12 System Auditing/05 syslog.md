# syslog.md

This file is a practical, hands-on guide to **syslog on modern Linux**. It covers how the logging system works in practice, how to configure rsyslog and journald, how to forward logs securely to a central server, how to parse and filter logs, and how to troubleshoot real problems you will meet in a VMware lab or production environment.

Everything here is command-first: exact files to edit, concrete examples, and recovery steps. No vague theory — this is what you will actually type.

---

# 1. Overview — components and their roles

Most modern Linux systems use two logging components in parallel: `systemd-journald` (the journal) and a syslog daemon such as `rsyslog` or `syslog-ng`. The journal collects kernel and service logs; the syslog daemon persists them to text files and can forward logs to remote collectors.

Common components:
- `systemd-journald` — collects logs from the kernel, syslog, stdout/stderr of services and stores them binary under `/run/log/journal` or `/var/log/journal` when persistent.
- `rsyslog` — the most common syslog daemon on RHEL/Rocky. Reads journal via `imjournal` or `imuxsock`, writes to `/var/log/*`, and forwards to remote servers.
- `syslog-ng` — an alternative with rich parsing features.
- Central collectors — Graylog, ELK (Elasticsearch/Logstash/Kibana), Splunk, or a plain rsyslog server receiving via TLS/REL P or TCP.

You will usually configure `journald` to forward to `rsyslog`, and configure `rsyslog` to write and forward logs.

---

# 2. Persistent journal — enable and inspect

By default the journal is often volatile (stored in `/run/log/journal`). Make it persistent so logs survive reboot:

```
mkdir -p /var/log/journal
chown root:systemd-journal /var/log/journal
chmod 2755 /var/log/journal
systemctl restart systemd-journald
```

Check journal size and status:
```
journalctl --disk-usage
journalctl --verify
```

View journal logs:
```
journalctl -u sshd -f       # follow sshd
journalctl -b                # logs since boot
journalctl --since "2025-12-01" --until "2025-12-02"
```

Configure retention in `/etc/systemd/journald.conf` (common changes):
```
SystemMaxUse=500M
SystemKeepFree=200M
Storage=persistent
MaxRetentionSec=1month
```
Restart journald after edits:
```
systemctl restart systemd-journald
```

---

# 3. Rsyslog basics — where files live and main config

Rsyslog configuration:
- main file: `/etc/rsyslog.conf`
- drop-in configs: `/etc/rsyslog.d/*.conf`
- runtime state and spool: `/var/spool/rsyslog/` (depends on distro)

Simple rsyslog rule example that writes auth messages to a file:
```
# /etc/rsyslog.d/auth.conf
auth,authpriv.*    /var/log/secure
```

Reload rsyslog:
```
systemctl restart rsyslog
```
Check service status and last errors:
```
systemctl status rsyslog
journalctl -u rsyslog -f
```

---

# 4. Reading logs produced by rsyslog

Common file locations:
```
/var/log/messages    # general system messages (RHEL)
/var/log/secure      # authentication (sshd, sudo)
/var/log/cron        # cron jobs
/var/log/maillog     # mail
/var/log/boot.log    # boot messages
```

Tail multiple logs:
```
tail -F /var/log/secure /var/log/messages
```
Use `rsyslog` templates for custom logs — covered later.

---

# 5. Forwarding logs to a central server (securely)

Centralized logging is mandatory for investigations and scale. Use TLS and either RELP, TCP, or syslog over TLS. RELP is reliable for lost packets; TCP+TLS is common and supported widely.

## Server side (central collector) — rsyslog example

1. Create a TLS certificate (use your PKI or self-signed for lab):

```
# on collector
openssl req -new -x509 -days 3650 -nodes -out /etc/pki/tls/certs/rsyslog.pem -keyout /etc/pki/tls/private/rsyslog.key -subj "/CN=logcollector.example.local"
chmod 600 /etc/pki/tls/private/rsyslog.key
```

2. Configure rsyslog to accept TLS TCP on port 6514. Add `/etc/rsyslog.d/10-remote.conf`:

```
module(load="imtcp")
module(load="imptcp")    # if using RELP/ptcp
action(type="omfile" file="/var/log/remote/%HOSTNAME%/messages")
input(type="imtcp" port="6514" tls="on")
global(
  defaultNetstreamDriver="gtls"
  defaultNetstreamDriverCAFile="/etc/pki/tls/certs/ca-bundle.crt"
  defaultNetstreamDriverCertFile="/etc/pki/tls/certs/rsyslog.pem"
  defaultNetstreamDriverKeyFile="/etc/pki/tls/private/rsyslog.key"
)
```

Restart collector:
```
systemctl restart rsyslog
```

## Client side (send logs securely)

On each client add `/etc/rsyslog.d/50-remote.conf`:

```
# enable TLS omfwd
module(load="omfwd")
action(type="omfwd" target="logcollector.example.local" port="6514" protocol="tcp" StreamDriver="gtls" StreamDriverMode="1" StreamDriverAuthMode="x509/name" StreamDriverPermittedPeers="logcollector.example.local" Template="RSYSLOG_ForwardFormat")
```

Test forwarding by tailing collector logs and generating a message on client:
```
logger "test log to collector"
```
On collector: check `/var/log/remote/<client>/messages` or `journalctl -u rsyslog`.

Notes:
- Use valid CA and cert names in production. `StreamDriverAuthMode` can be `x509/name` to validate server hostname.
- For high reliability use RELP or `omrelp` module.

---

# 6. Rsyslog modules you will use frequently

- `imuxsock` — listens to the /dev/log socket (local syslog calls)
- `imjournal` — reads directly from the journal (better performance than imuxsock in some cases)
- `imfile` — read arbitrary text files (application logs)
- `imtcp` / `imudp` — listen for TCP/UDP syslog messages
- `omfwd` — forward messages to remote host
- `omrelp` — RELP forwarder for reliable delivery
- `omfile` — write to files with templating
- `mmnormalize` / `mmjsonparse` — parse message content

Load modules in `/etc/rsyslog.conf` or the drop-in config; for example:
```
module(load="imfile")
module(load="omfwd")
module(load="imjournal")
```

---

# 7. Parsing, templates and property-based filters

Rsyslog supports templates to control the output format and file path. Example template for remote storage by hostname and program:

```
template(name="PerHostPerProgram" type="string" string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")
*.* ?PerHostPerProgram
& stop
```

Property-based filters let you route messages based on fields.

Example: write only sshd messages to a file:

```
if $programname == 'sshd' then /var/log/sshd.log
& stop
```

Parsing complex messages (JSON) with `mmjsonparse`:
```
module(load="mmjsonparse")
if $msg contains '{' then mmjsonparse()
if $!app.name == 'myapp' then /var/log/myapp.log
```

---

# 8. Log file ownership and rotation interplay

Rsyslog creates files as defined by `create` templates, but rotation is usually handled by `logrotate`. Ensure logrotate configuration matches the file naming used by rsyslog. Example `/etc/logrotate.d/rsyslog`:

```
/var/log/remote/*/messages {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    sharedscripts
    postrotate
        /bin/kill -HUP `cat /var/run/rsyslogd.pid 2>/dev/null` 2>/dev/null || true
    endscript
}
```

If rsyslog keeps file descriptors open, prefer to use `copytruncate` or send HUP to rsyslog to reopen files.

---

# 9. Rate limiting and flood control

If a service floods logs (e.g., noisy cron job or brute-force SSH attempts), rsyslog can rate-limit using `$SystemLogRateLimitInterval` and `$SystemLogRateLimitBurst` in older syntax, or `ratelimit` directive in newer RainerScript.

Example rate limit in rsyslog.conf (legacy):
```
$SystemLogRateLimitInterval 10
$SystemLogRateLimitBurst 200
```

RainerScript example (modern):
```
module(load="imuxsock" SysSock.RateLimit.Interval="10" SysSock.RateLimit.Burst="200")
```

Use Fail2Ban in addition to rate-limiting to block sources of repeated failed SSH attempts.

---

# 10. Secure transport and authentication options

Options for secure syslog transport:
- TLS over TCP (port 6514) with x509 certificates
- RELP for reliable delivery (omrelp + input-relp)
- syslog-ng with TLS and TLS verification

Certificate best practices:
- Use a CA-signed certificate in production. For lab, generate a CA and sign host certs.
- Keep private keys protected with `chmod 600` and restrict to root.
- Verify names — use `StreamDriverAuthMode="x509/name"` and `StreamDriverPermittedPeers` on rsyslog clients.

---

# 11. Forwarding structured logs (JSON, GELF) to ELK or Graylog

If your application emits JSON, configure rsyslog to parse JSON and then forward structured fields to Elasticsearch via `omelasticsearch` or to Graylog via GELF (`omgelf`).

Example parsing and forwarding:
```
module(load="mmjsonparse")
if $msg contains '{' then {
    action(type="mmjsonparse")
    action(type="omelasticsearch" server="elasticsearch.local" serverport="9200" template="json-template")
}
```

Make sure Elasticsearch index templates match the fields you forward.

---

# 12. Troubleshooting tips — common failure modes

1. **No logs reaching central server**
   - Verify network connectivity (`nc -vz collector 6514`).
   - Check rsyslog client config syntax: `rsyslogd -N1` (config test).  
   - Check server listening ports: `ss -lntp | grep 6514` and `journalctl -u rsyslog`.

2. **Logs arrive but broken formatting**
   - Mismatch in templates between sender and receiver. Use `RSYSLOG_ForwardFormat` or explicit templates. Test with `logger`.

3. **High CPU or log volume**
   - Turn on rate limiting, tune filters, use ipsets or network layer blocking for noisy sources.

4. **Permissions issues writing files**
   - Ensure rsyslog has write permission in directories. Use `mkdir -p /var/log/remote/host` and `chown syslog:syslog` if needed.

5. **TLS handshake failures**
   - Verify cert chain and clock sync. Check `journalctl -u rsyslog` for TLS errors.

6. **Duplicate logs**
   - If both imjournal and imuxsock are enabled, you may get duplicates. Use only one input: prefer `imjournal` for systemd environments.

---

# 13. Security and privacy considerations

- Avoid sending secrets in logs. Filter out sensitive fields at source when possible.
- Use TLS and authenticated transport. Do not expose syslog over UDP to untrusted networks.
- Protect logs at rest: restrict file permissions and use disk encryption for log storage if needed.
- Ensure central collector rotates and archives logs according to retention policy and legal requirements.

---

# 14. Example configurations — quick copy/paste

## Minimal local logging `/etc/rsyslog.d/10-local.conf`
```
module(load="imuxsock")
module(load="imklog")
*.info;mail.none;authpriv.none;cron.none                /var/log/messages
authpriv.*                                            /var/log/secure
mail.*                                                -/var/log/maillog
```

## Forward to TLS collector `/etc/rsyslog.d/50-remote.conf`
```
module(load="omfwd")
action(type="omfwd" Target="logcollector.example.local" Port="6514" Protocol="tcp" StreamDriver="gtls" StreamDriverMode="1" StreamDriverAuthMode="x509/name" StreamDriverPermittedPeers="logcollector.example.local")
```

## Read application log `/etc/rsyslog.d/20-myapp.conf`
```
module(load="imfile" PollingInterval="10")
input(type="imfile" File="/opt/myapp/logs/myapp.log" Tag="myapp" Severity="info" Facility="local7")
local7.*    /var/log/myapp.log
```

---

# 15. What you achieve after this file

You will be able to:
- enable persistent journaling and manage journal retention
- configure rsyslog to write, parse, and forward logs securely
- integrate system logs with centralized collectors (ELK, Graylog)
- parse JSON logs and forward structured data
- troubleshoot the most common logging issues
- implement rate limits and protect log pipelines from overload

This is the operational syslog playbook you will use daily for Linux administration and incident investigations.
