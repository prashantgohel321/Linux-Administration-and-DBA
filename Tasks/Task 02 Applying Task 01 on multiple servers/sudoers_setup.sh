#!/bin/bash
set -e

ROLE="$1"

if [ -z "$ROLE" ]; then
  echo "Usage: sudoers_setup.sh <department>"
  exit 1
fi




# if [ "$ROLE" = "linuxadmin" ]; then

cat << 'EOF' > /etc/sudoers.d/linuxadmin
%linuxadmin      ALL=(ALL:ALL) NOPASSWD: ALL
EOF

echo "[+] Applied: linuxadmin full sudo"
chmod 440 /etc/sudoers.d/linuxadmin
visudo -cf /etc/sudoers.d/linuxadmin
# exit 0
# fi




DENY_FILE="/etc/sudoers.d/$ROLE"

cat << 'EOF' > "$DENY_FILE"
Cmnd_Alias SW_MGMT  = /bin/rpm, /usr/bin/dnf, /usr/bin/up2date
Cmnd_Alias STR_FS   = /sbin/fdisk, /sbin/sfdisk, /bin/mount, /bin/umount
Cmnd_Alias SYS_CTRL = /usr/sbin/reboot, /usr/sbin/shutdown
Cmnd_Alias NET_CFG  = /sbin/iptables, /sbin/ifconfig
Cmnd_Alias DELEG    = /usr/sbin/visudo, /usr/bin/chmod, /usr/bin/chown

Cmnd_Alias RW_DENY = SW_MGMT, STR_FS, SYS_CTRL, NET_CFG, DELEG
EOF




if [[ "$ROLE" = "lnx_devops"            ||
      "$ROLE" = "lnx_screenzaa"         ||
      "$ROLE" = "lnx_watchlistwarehouse"||
      "$ROLE" = "lnx_automation"        ||
      "$ROLE" = "lnx_security"          ||
      "$ROLE" = "lnx_saas_security"     ||
      "$ROLE" = "lnx_aiteam"            ||
      "$ROLE" = "lnx_nextaml" ]]; then

cat << EOF >> "$DENY_FILE"
%${ROLE} ALL=(ALL:ALL) NOPASSWD: ALL, !RW_DENY
EOF

chmod 440 "$DENY_FILE"
visudo -cf "$DENY_FILE"
echo "[+] Applied: $ROLE sudo with deny list"
exit 0

else

echo "[!] ERROR: Unknown ROLE → $ROLE"
exit 1

fi
