#!/bin/bash
set -e

PROFILE="myprofile"

echo "[+] Creating custom authselect profile if not exists"

if [ ! -d /etc/authselect/custom/${PROFILE} ]; then
    authselect create-profile ${PROFILE} --base-on sssd
fi

echo "[+] Writing sshd PAM file into custom profile"

cat << EOF > /etc/authselect/custom/${PROFILE}/sshd
#%PAM-1.0

auth       sufficient   pam_sss.so
auth       substack     password-auth
auth       include      postlogin

account    required     pam_sepermit.so
account    required     pam_nologin.so
account    [success=1 default=ignore] pam_sss.so
account    requisite    pam_deny.so
account    include      password-auth

password   include      password-auth

session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_keyinit.so force revoke
session    required     pam_selinux.so open env_params
session    include      password-auth
session    include      postlogin
EOF

echo "[+] Selecting custom authselect profile"
authselect select custom/${PROFILE} --force

echo "[+] Applying authselect changes"
authselect apply-changes

echo "[+] Restarting services"
systemctl restart sssd sshd
systemctl enable --now oddjob-mkhomedir || true

echo "[✓] SSHD PAM + authselect configuration applied successfully"
