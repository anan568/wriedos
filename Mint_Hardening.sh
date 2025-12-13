#!/bin/bash

# Only look in locations where sensitive files exist
CRITICAL_DIRS=(
    "/home"
    "/root"
    "/etc/sudoers.d"
    "/etc/cron.d"
    "/etc/cron.daily"
    "/etc/cron.hourly"
    "/etc/cron.weekly"
)

# Explicitly check critical single files
CRITICAL_FILES=(
    "/etc/shadow"
    "/etc/gshadow"
    "/etc/sudoers"
)

# CONFIGURATION — EDIT THESE LISTS

AUTHORIZED_USERS=("c" "cguy")
AUTHORIZED_ADMINS=("")
hello_its_me="benjamin"

AUTHORIZED_PASS="Cyb3rPatr!0t$"

# UTILITIES

check_user_exists () { id "$1" &>/dev/null; return $?; }

# 1) LOCK ROOT ACCOUNT

echo "=== Locking root account ==="
sudo passwd -l root

# 2) ENUMERATE SYSTEM USERS

SYSTEM_USERS=($(awk -F: '$3 >= 1000 {print $1}' /etc/passwd))
EXPECTED_USERS=("${AUTHORIZED_USERS[@]}" "${AUTHORIZED_ADMINS[@]}")

echo
echo "Detected system users: ${SYSTEM_USERS[*]}"
echo

# 3) PROCESS ADMIN USERS

echo "=== Enforcing admin accounts ==="

for user in "${AUTHORIZED_ADMINS[@]}"; do
    if [[ "$user" == "$hello_its_me" ]]; then
        continue
    fi

    if check_user_exists "$user"; then
        echo "[OK] Admin $user exists"

        # ensure sudo group membership
        if ! id -nG "$user" | grep -qw sudo; then
            echo "  -> Adding $user to sudo group"
            sudo usermod -aG sudo "$user"
        fi

        # password aging
        sudo chage -M 90 -m 30 -W 7 "$user"
    else
        echo "[WARN] Expected admin $user missing"
    fi
done

echo

# 4) REMOVE UNAUTHORIZED ADMIN USERS

echo "=== Removing unauthorized admins ==="

CURRENT_ADMINS=($(getent group sudo | awk -F: '{print $4}' | tr ',' ' '))

for admin in "${CURRENT_ADMINS[@]}"; do
    if [[ "$admin" == "$hello_its_me" ]]; then
            continue
    fi
    if [[ ! " ${AUTHORIZED_ADMINS[*]} " =~ " ${admin} " ]]; then
        echo "[REMOVE] $admin is not an authorized admin"
        sudo gpasswd -d "$admin" sudo
    fi
done

echo

# 5) PROCESS AUTHORIZED NON-ADMIN USERS

echo "=== Processing authorized non-admin users ==="

for user in "${AUTHORIZED_USERS[@]}"; do
    if [[ "$user" == "$hello_its_me" ]]; then
            continue
    fi
    if check_user_exists "$user"; then
        echo "[OK] User $user exists"

        # enforce password
        echo "$user:$AUTHORIZED_PASS" | sudo chpasswd

        # password aging
        sudo chage -M 90 -m 30 -W 7 "$user"
    else
        echo "[WARN] Expected non-admin $user missing"
    fi
done

echo

# 6) FIND UNAUTHORIZED USERS

echo "=== Checking for unauthorized users ==="

for user in "${SYSTEM_USERS[@]}"; do
    if [[ "$user" == "$hello_its_me" ]]; then
            continue
    fi
    if [[ ! " ${EXPECTED_USERS[*]} " =~ " ${user} " ]]; then
        echo "[ALERT] Unauthorized user present: $user"
    fi
done

echo

# 7) FILE PERMISSION HARDENING

echo "=== Hardening /etc/passwd and /etc/shadow permissions ==="

sudo chmod 644 /etc/passwd
sudo chmod 600 /etc/shadow
sudo chown root:root /etc/passwd /etc/shadow

echo

# 8) REMOVE UNAUTHORIZED SOFTWARE / HACKING TOOLS

echo "=== Removing unauthorized software ==="

sudo apt purge -y \
nmap wireshark netcat tcpdump zenmap nikto ophcrack john hydra \
apache2 nginx lighttpd telnetd telnet xinetd || true

sudo apt autoremove -y

echo

# 9) ENABLE UFW FIREWALL

echo "=== Enabling UFW firewall ==="

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

echo

# 11) FAILLOCK ACCOUNT LOCKOUT POLICY

echo "=== Configuring faillock lockout policy ==="

cat <<EOF | sudo tee /usr/share/pam-configs/faillock > /dev/null
Name: Lockout on failed logins
Default: yes
Priority: 0
Auth-Type: Primary
Auth:
[default=die] pam_faillock.so authfail deny=5 unlock_time=900
EOF

cat <<EOF | sudo tee /usr/share/pam-configs/faillock_reset > /dev/null
Name: Reset lockout on success
Default: yes
Priority: 0
Auth-Type: Additional
Auth:
required pam_faillock.so authsucc
EOF

cat <<EOF | sudo tee /usr/share/pam-configs/faillock_notify > /dev/null
Name: Notify on account lockout
Default: yes
Priority: 1024
Auth-Type: Primary
Auth:
requisite pam_faillock.so preauth
EOF

sudo pam-auth-update --package

echo

# 12) REMOVE nullok FROM PAM

echo "=== Removing nullok (disallow empty passwords) ==="

sudo sed -i 's/nullok//g' /etc/pam.d/common-auth

echo

# 13) AUTOMATIC DAILY UPDATES

echo "=== Configuring automatic daily updates ==="

sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

echo

echo "=== SYSTEM HARDENING COMPLETE ==="

# 14) KERNEL HARDENING
echo "=== Applying kernel hardening settings ==="

sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# KERNEL HARDENING

# --- Network Security ---
# Reverse path filtering (IP spoofing protection)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable ICMP redirects (prevent MITM attacks)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable IPv6 if not needed
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1

# --- System Hardening ---
# Enable ASLR (address space layout randomization)
kernel.randomize_va_space = 2

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Disable SysRq (unless you need it for debugging)
kernel.sysrq = 0

# Restrict dmesg to root only
kernel.dmesg_restrict = 1

# Disable core dumps
fs.suid_dumpable = 0
kernel.core_uses_pid = 1

# Disable uncommon network protocols
net.ipv4.conf.all.accept_local = 0
net.ipv4.conf.default.accept_local = 0

# Slow down TCP timestamp attacks
net.ipv4.tcp_timestamps = 0

# Harden BPF just in case
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden=2

#the stuff i found from aperture practice image
net.ipv4.tcp_rfc1337 = 1

######################################
EOF

# Apply changes
sudo sysctl -p

echo "=== Kernel hardening applied ==="

# World read-ables
echo "[+] Checking critical single files..."
for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -f "$FILE" ] && [ -r "$FILE" ]; then
        ls -l "$FILE"
    fi
done
echo ""


echo "======== Checking critical directories..."
for DIR in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        echo "[*] $DIR"
        find "$DIR" \
            -type f \
            -perm -o=r \
            -not -name "*.log" \
            -not -path "*/doc/*" \
            -not -path "*/man/*" \
            -not -path "*/examples/*" \
            -not -path "/home/*/.cache/*" \
            -not -path "/home/*/snap/*" \
            -not -path "/home/*/.mozilla/*" \
            -not -path "/home/*/.local/*" \
            -not -path "/home/*/.bashrc" \
            -not -path "/home/*/.profile" \
            -not -path "/home/*/.bash_logout" \
            -not -path "/home/*/.config/*" \
            -not -path "/home/*/.face" \
            2>/dev/null 
        echo "" 
    fi
done

#disable guest login
sudo sed -i 's/^#\?allow-guest.*/allow-guest=false/' /etc/lightdm/lightdm.conf 2>/dev/null

echo "[+] Scan complete."