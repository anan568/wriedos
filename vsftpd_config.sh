#!/bin/bash

#exits on error/failure
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "===== ensure script is ran as root"
    exit 1 
fi

VSFTPD_CONFIG="/etc/vsftpd.conf"
BACKUP="/etc/vsftpd.conf.bak"

echo "==== updating and installing just incase"
apt update
apt install vsftpd -y

# making sure ftp is up and running 
systemctl enable vsftpd
systemctl start vsftpd

# backing up vsftp configs
cp -p "$VSFTPD_CONFIG" "$BACKUP"
echo "==== backup created at $BACKUP"

# function to apply vsftpd configs
set_config() {
    local key="$1"
    local value="$2"

    if grep -qE "^#?\s*${key}=" "$VSFTPD_CONFIG"; then
        sed -i "s|^\s*#\?\s*${key}=.*|${key}=${value}|" "$VSFTPD_CONFIG"
    else
        echo "${key}=${value}" >> "$VSFTPD_CONFIG"
    fi
}

echo "===== applying ftp configurations settings"

# Disable anonymous access
set_config "anonymous_enable" "NO"
# Local users only
set_config "local_enable" "YES"
set_config "write_enable" "YES"
# Chroot users to their home directory
set_config "chroot_local_user" "YES"
set_config "allow_writeable_chroot" "YES"
# Restrict file permissions
set_config "local_umask" "022"
# Disable risky features
set_config "dirmessage_enable" "NO"
set_config "xferlog_enable" "YES"
set_config "connect_from_port_20" "NO"
# Logging
set_config "log_ftp_protocol" "YES"
set_config "vsftpd_log_file" "/var/log/vsftpd.log"
# Connection limits (brute-force mitigation)
set_config "max_clients" "10"
set_config "max_per_ip" "3"
set_config "pasv_enable" "YES"
set_config "pasv_min_port" "40000"
set_config "pasv_max_port" "40100"
# Banner
set_config "ftpd_banner" "Authorized access only."

systemctl restart vsftpd

echo "==== validating vsftpd configurations"
if systemctl is-active --quiet vsftpd; then
    echo "===== vsftpd configuration applied successfully"
else
    echo "===== Critical: vsftpd congfiguration errors detected. reverting to backups"
    cp -p "$BACKUP" "$VSFTPD_CONFIG"
    systemctl restart vsftpd
    exit 1
fi

echo "===== configuring UFW firewall settings for ftp"
# main ftp control ports
ufw allow 20/tcp
ufw allow 21/tcp
# passive ftp port
ufw allow 40000:40100/tcp

if ! ufw status |grep -q "Status: active"; then
    ufw --force enable
fi

echo "====== vsftpd configurations complete"
