#!/bin/bash
set -e

ROLE="$1"

if [ -z "$ROLE" ]; then
  echo "Usage: sudoers_setup.sh <ai|devops|admin>"
  exit 1
fi

echo "[+] Cleaning old sudoers files"
rm -f /etc/sudoers.d/linux-*

if [ "$ROLE" = "admin" ]; then
cat << EOF > /etc/sudoers.d/linux-admin
%Linux-Admin ALL=(ALL:ALL) ALL
EOF
fi

if [ "$ROLE" = "devops" ]; then
cat << EOF > /etc/sudoers.d/linux-devops
Cmnd_Alias RW_CMNDS = /usr/bin/systemctl, /usr/bin/journalctl

Cmnd_Alias SW_MGMT  = /bin/rpm, /usr/bin/dnf, /usr/bin/up2date
Cmnd_Alias STR_FS   = /sbin/fdisk, /sbin/sfdisk, /bin/mount, /bin/umount
Cmnd_Alias SYS_CTRL = /usr/sbin/reboot, /usr/sbin/shutdown
Cmnd_Alias NET_CFG  = /sbin/iptables, /sbin/ifconfig
Cmnd_Alias DELEG    = /usr/sbin/visudo, /usr/bin/chmod, /usr/bin/chown

Cmnd_Alias RW_DENY = SW_MGMT, STR_FS, SYS_CTRL, NET_CFG, DELEG

%Linux-ReadWrite ALL=(ALL:ALL) RW_CMNDS, !RW_DENY
EOF
fi

chmod 440 /etc/sudoers.d/*
visudo -cf /etc/sudoers.d/*

echo "[✓] Sudoers applied for role: $ROLE"
