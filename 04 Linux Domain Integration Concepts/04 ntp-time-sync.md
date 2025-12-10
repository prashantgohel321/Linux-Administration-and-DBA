# ntp-time-sync.md

- In this file I am focusing on <mark><b>time synchronization</b></mark> between Rocky Linux and the Windows Domain Controller. Kerberos is extremely sensitive to time differences. Even a few minutes of drift causes authentication to fail. So before joining the domain, I must verify that Linux is using correct time sources.

---

<br>
<br>

## Why time matters in Kerberos

- Kerberos checks the time when I try to authenticate. If my system time and the Domain Controller’s time differ by more than a few minutes, Kerberos will reject the login request.

- This prevents someone from reusing old authentication messages, but it also means my system must have correct time sync before joining the domain.

---

<br>
<br>

## How Linux handles time

- Rocky Linux uses **`systemd-timesyncd`** or **`chronyd`** depending on configuration. Chrony is commonly used in enterprise environments. I can check which service is active and configure NTP servers.

To verify status:
```bash
timedatectl status
```

- This shows:
  - local time
  - RTC time
  - NTP status
  - synchronization state

---

<br>
<br>

## Set the Domain Controller as NT (Network Time Protocol) server

- I should make my Domain Controller the NTP server for my Linux system. The Domain Controller can sync with the internet if needed, but my Linux machine must sync time directly from the DC to avoid time issues.

- So if my Domain Controller is 192.168.100.10, I point chrony to that address.

<br>
<details>
<summary><b>NTP</b></summary>
<br>

- NTP keeps clocks in sync between systems on a network, so all machines share the correct and matching time.

</details>
<br>

---

<br>
<br>

## Editing chrony configuration

Chrony configuration file:
```bash
/etc/chrony.conf
```

I add or modify the server line:
```bash
server 192.168.100.10 iburst
```

I comment out other public NTP servers if they exist, because mixing sources sometimes causes unexpected behavior.

After editing, restart chrony:
```bash
systemctl restart chronyd
```

Ensure it is enabled:
```bash
systemctl enable chronyd
```

---

<br>
<br>

## Verify synchronization

- To confirm chrony is using the Domain Controller:
```bash
chronyc sources
```

- Expected output should show the Domain Controller with a reach value and state. If it shows "?" or unreachable, DNS or network might be wrong.

Also check:
```bash
chronyc tracking
```

- This provides detailed statistics about offset and drift.

---

<br>
<br>

## Testing time before join

- Before running any realm commands, I verify time:
```bash
timedatectl
```

- Look for "System clock synchronized: yes".

- If not synchronized, fix chrony before proceeding.

---

<br>
<br>

## Kerberos errors related to time

- When time is wrong, Kerberos fails with messages like:
  - "Clock skew too great"
  - "KDC unreachable" (sometimes misleading)
  - "Preauthentication failed"

- Whenever I see authentication failures, time is one of the first things to check.

---

<br>
<br>

## Forcing immediate sync

- If I need an immediate update:
```bash
chronyc makestep
```

- This forces the clock to step rather than slowly adjust.

---

<br>
<br>

## Alternative: timedatectl NTP settings

- Some systems use systemd-timesyncd. In that case:
```bash
timedatectl set-ntp true
```

- And configure NTP servers in:
```bash
/etc/systemd/timesyncd.conf
```

- But on Rocky Linux, chrony is normally preferred.

---

<br>
<br>

## Domain Controller time configuration

- The Domain Controller must have accurate time. By default, a Windows Domain Controller uses Windows Time Service (W32Time).

On the DC, check:
```
w32tm /query /status
```

- If the DC is not syncing externally, configure its upstream NTP sources, because if the DC drifts, everything fails.

---

<br>
<br>

## Practical workflow

1. Configure chrony to use DC as NTP server
2. Restart chrony
3. Verify chrony sources
4. Run chronyc tracking
5. Check timedatectl
6. Only after successful synchronization: run realm discover and realm join

---

<br>
<br>

## What I achieve after this file

- After understanding NTP and time synchronization, I know how to configure chrony, verify sync status, react to Kerberos time errors, and force synchronization. This prevents time-related authentication failures and ensures smooth domain joining and Kerberos operation.