# SSSD-caching.md

In this file I am focusing only on how SSSD caching works, why it exists, how to inspect it, how to clear it, and how caching affects authentication. Caching causes many confusing situations during troubleshooting because an issue might appear fixed in AD but Linux still behaves based on old cached information. So I need a practical, command-based understanding.

---

## Why SSSD caches data

SSSD caches user and group information and sometimes credentials. It does this for two main reasons:

1. Performance. Querying AD repeatedly would slow down login and system commands like `id`.
2. Offline logins. If the Domain Controller becomes unreachable, users can still log in if they logged in recently.

Caching is a core feature, not a side effect.

---

## What gets cached

SSSD caches:
- user information (UID, GID, group membership)
- group information
- authentication data (when cache_credentials is enabled)

This means that even if AD changes, Linux might still show the old values until the cache expires.

---

## Where SSSD cache lives

Cache files live in:
```
/var/lib/sss/db/
```

These files are binary and should not be edited manually.

---

## Cache timeouts

Cache expiration is controlled by domain section options in `sssd.conf`:
```
entry_cache_timeout = 5400
```

This value is in seconds (5400 = 1.5 hours). After this time, SSSD refreshes its data. For testing, I might reduce this value.

---

## cache_credentials

```
cache_credentials = true
```

If enabled, SSSD stores credentials so users can log in even if AD is offline. If disabled, offline logins fail.

For realistic enterprise setups, this is normally enabled.

---

## Checking cached information

The `sssctl` tool lets me inspect cached entries.

### List cached users
```
sssctl cache-status
```

### Show details about a user
```
sssctl user-show testuser1
```

This can show cached information even if AD is unreachable.

---

## Clearing SSSD cache

When troubleshooting, clearing cache is often necessary. If AD changed group membership or password and Linux still shows old information, I clear cache.

Clear all caches:
```
sssctl cache-remove -o
```

Then restart SSSD:
```
systemctl restart sssd
```

This forces SSSD to query AD again.

---

## Example: user removed from AD

If a user was deleted or disabled in AD, Linux might still allow login briefly due to cached data. After cache timeout or manual clearing, access will be denied.

This is expected behavior when `cache_credentials = true`.

---

## Example: group membership updated in AD

If I add a user to a group in AD, Linux may not show the change immediately:
```
id testuser1
```

Still shows old groups until cache refresh. Clearing cache forces immediate update.

---

## Offline login scenario

If `cache_credentials=true`, the user can log in while DC is down. But ONLY if the user logged in before when the DC was available. A first-time login requires DC.

So:
- first login needs DC
- later logins may work offline if credential caching is enabled

---

## Logs related to caching

SSSD logs contain messages about caching in:
```
/var/log/sssd/sssd_cache.log
```

Also relevant messages appear in:
- `sssd_nss.log`
- `sssd_pam.log`

---

## Testing caching behavior in practice

1. log in as AD user
2. disconnect from network (simulate DC down)
3. try logging again

If successful, caching is working. If not, either caching disabled or SSSD misconfigured.

---

## What can go wrong

### Stale cache
Linux shows old information after AD changes.
Fix: clear cache.

### Offline login fails
Possible cause: caching disabled or user never logged in before.

### Authentication succeeds but groups outdated
Cache needs refresh.

---

## Recommended troubleshooting workflow

1. `sssctl user-show <user>`
2. `getent passwd <user>`
3. clear cache
```
sssctl cache-remove -o
systemctl restart sssd
```
4. test again

---

## What I achieve after this file

I understand exactly how caching works, why it exists, how to inspect cached entries, how to clear cache, and how caching affects authentication and user/group visibility. This helps prevent confusion during troubleshooting and explains why changes in AD may not appear immediately on Linux.