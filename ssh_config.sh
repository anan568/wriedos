#!/bin/bash

#code exits if any failures
set -euo pipefail

#checks if being ran on root
if [[ $EUID -ne 0 ]]; then
    echo "====== Ensure to run this script as root"
    exit 1
fi

# defining the path creating a backup just incase
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak"

echo "====== Updating SSH"
apt update -y
apt install --only-upgrade -y openssh-server openssh-client

#checking to make sure its enabled and active
systemctl enable ssh
systemctl start ssh

# creating a backup
cp -p "$SSHD_CONFIG" "$BACKUP"
echo "==== Backup created at $BACKUP"

#function to safely set ssh configs
set_config() {
    local key="$1"
    local value="$2"

    if grep -qE "^#?\s*${key}\s+" "$SSHD_CONFIG"; then
        sed -i "s|^\s*#\?\s*${key}\s\+.*|${key} ${value}|" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

echo "======= applying SSH setting configurations"

# Authentication (PASSWORD-BASED, NO KEYS)
set_config "PermitRootLogin" "no"
set_config "PasswordAuthentication" "yes"
set_config "PubkeyAuthentication" "no"
set_config "PermitEmptyPasswords" "no"
set_config "ChallengeResponseAuthentication" "no"
set_config "UsePAM" "yes"
# Connection hardening
set_config "StrictModes" "yes"
set_config "MaxAuthTries" "3"
set_config "LoginGraceTime" "30"
set_config "ClientAliveInterval" "300"
set_config "ClientAliveCountMax" "2"
# Feature lockdown
set_config "X11Forwarding" "no"
set_config "AllowTcpForwarding" "no"
set_config "PrintMotd" "no"

#verifies and restarts to apply
echo "======== Checking validity of the configurations"
if sshd -t ; then
    systemctl restart ssh
    echo "=== ssh service restarted successfully"
else   
    echo "===== CRITICL: ssh config error was detected. reverting to backups"
    cp -p "$BACKUP" "$SSHD_CONFIG"
    systemctl restart ssh
    exit 1
fi

# setting up firewall config
echo "======= Configuring UFW firewall"
ufw allow ssh

if ! ufw status | grep -q  "Status: active"; then
    echo "===== Enabling UFW"
    ufw --force enable
else
    echo "==== UFW is enabled"
fi

#listing ssh group members
if getent group ssh &>/dev/null; then
    MEMBERS=$(getent group ssh | awk -F: '{print $3, $4}')
    if [[ -n "$MEMBERS" ]]; then
        echo "$MEMBERS"
    else
        echo "==== ssh group exists but has no members"
    fi
else
    echo "no 'ssh' group found in the group lists"
fi

echo "========= ssh configurations settings applied"