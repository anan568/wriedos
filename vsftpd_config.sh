#!/bin/bash
### MAKE sure to stop the service before running the script because this will configure then validate it and ensure it starts
## ALSO be sure to read the README so nothing conflicts with the scripts and brick the service


#exits on error/failure
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "===== ensure script is ran as root"
    exit 1 
fi

VSFTPD_CONFIG="/etc/vsftpd.conf"
BACKUP="/etc/vsftpd.conf.bak"
CERT_DIR=/etc/ssl/private
CERT_FILE="$CERT_DIR/vsftpd.pem"

echo "==== updating and installing just incase"
apt update
apt install vsftpd openssl -y

# making sure ftp is up and running 
systemctl enable vsftpd

# backing up vsftp configs
cp -p "$VSFTPD_CONFIG" "$BACKUP"
echo "==== backup created at $BACKUP"

if [[ ! -f "$CERT_FILE" ]]; then
    echo "====== Generating TLS certificate"
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:4096 \
        -keyout "$CERT_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=FTP Server"

    chmod 600 "$CERT_FILE"
fi

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
set_config "port_enable" "NO"
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

# ===== TLS HARDENING =====
set_config "ssl_enable" "YES"
set_config "rsa_cert_file" "$CERT_FILE"
set_config "rsa_private_key_file" "$CERT_FILE"
# Force encryption
set_config "force_local_logins_ssl" "YES"
set_config "force_local_data_ssl" "YES"
# Disable weak SSL
set_config "ssl_sslv2" "NO"
set_config "ssl_sslv3" "NO"
set_config "ssl_tlsv1" "NO"
set_config "ssl_tlsv1_1" "NO"
set_config "ssl_tlsv1_2" "YES"
# Strong ciphers
set_config "ssl_ciphers" "HIGH"
# Hide users
set_config "userlist_enable" "YES"
set_config "userlist_deny" "NO"
set_config "require_ssl_reuse" "NO"

echo "==== validating vsftpd configuration"
if vsftpd "$VSFTPD_CONFIG" &>/dev/null; then
    systemctl restart vsftpd
    echo "===== vsftpd started securely"
else
    echo "===== CRITICAL: config error, reverting"
    cp -p "$BACKUP" "$VSFTPD_CONFIG"
    systemctl restart vsftpd
    exit 1
fi

echo "===== configuring UFW firewall settings for ftp"
# main ftp control ports
ufw allow 21/tcp
# passive ftp port
ufw allow 40000:40100/tcp

if ! ufw status |grep -q "Status: active"; then
    ufw --force enable
fi

echo "====== vsftpd configurations complete"
