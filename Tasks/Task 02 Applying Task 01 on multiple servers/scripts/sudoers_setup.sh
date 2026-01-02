#!/bin/bash
set -e

ROLE="$1"

if [ -z "$ROLE" ]; then
  echo "Usage: sudoers_setup.sh <department>"
  exit 1
fi


TSS_ADMIN_USER="tssadmin"

if ! getent group admin >/dev/null; then
  groupadd admin
fi

if id "$TSS_ADMIN_USER" &>/dev/null; then
        if id -nG "$TSS_ADMIN_USER" | grep -qw wheel; then
                gpasswd -d "$TSS_ADMIN_USER" wheel
        fi


        if ! id -nG "$TSS_ADMIN_USER" | grep -qw admin; then
                usermod -aG admin "$TSS_ADMIN_USER"
        fi
fi



if [ ! -f /etc/sudoers.bkp ]; then
  mv /etc/sudoers /etc/sudoers.bkp
fi

cp /tmp/sudoers.template /etc/sudoers

DENY_FILE="/etc/sudoers.d/$ROLE"

if [[ "$ROLE" = "lnx_devops"            ||
      "$ROLE" = "lnx_screenzaa"         ||
      "$ROLE" = "lnx_watchlistwarehouse"||
      "$ROLE" = "lnx_automation"        ||
      "$ROLE" = "lnx_security"          ||
      "$ROLE" = "lnx_saas_security"     ||
      "$ROLE" = "lnx_aiteam"            ||
      "$ROLE" = "lnx_nextaml" ]]; then

  cat << EOF > "$DENY_FILE"
  %${ROLE} ALL=(ALL:ALL) NOPASSWD: /usr/bin/su - tssadmin
  EOF

  chmod 440 "$DENY_FILE"
  visudo -cf "$DENY_FILE"
  echo "[+] Applied: $ROLE sudo with deny list"
  exit 0

else

  echo "[!] ERROR: Unknown ROLE → $ROLE"
  exit 1

fi