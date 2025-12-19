#!/bin/bash

#code exits if any failures
set -euo pipefail

#checks if being ran on root
if [[ $EUID -ne 0 ]]; then
    echo "Ensure to run this script as root"
    exit 1
fi

# defining the path creating a backup just incase
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak"

echo "Updating SSH"
apt update -y
apt install --only-upgrade -y openssh-server openssh-client

# creating a backup
cp -p "$SSHD_CONFIG" "$BACKUP"
echo "[+] Backup created at $BACKUP"
set_config() {
    local key="$1"
    local value="$2"

    if grep -qE "^#?\s*${key}\s+" "$SSHD_CONFIG"; then
        sed -i "s/^#\?\s*${key}\s\+.*/${key} ${value}/" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

echo "applying SSH setting configurations"

set_config "PermitRootLogin" "no"
set_config "PasswordAuthentication" "yes"
set_config "PermitEmptyPasswords" "no"
set_config "Protocol" "2"
set_config "ChallengeResponseAuthentication" "no"
set_config "StrictModes" "yes"
set_config "MaxAuthTries" "3"
set_config "UsePAM" "yes"
set_config "X11Forwarding" "no"
set_config "PrintMotd" "no"
set_config "ClientAliveInterval" "300"
set_config "ClientAliveCountMax" "2"
set_config "AllowTcpForwarding" "no"
set_config "LoginGraceTime" "30"


echo "Checking validity of the configurations"
sshd -t

#verifies and restarts to apply
systemctl restart ssh || echo "Config error, check $SSHD_CONFIG"

echo "ssh configurations settings applied"