#!/bin/bash

set -e

APACHE_CONF="/etc/apache2/apache2.conf"
SEC_CONF="/etc/apache2/conf-available/security.conf"

echo "[+] Backing up configs"
cp "$APACHE_CONF" "$APACHE_CONF.bak"
cp "$SEC_CONF" "$SEC_CONF.bak"

echo "[+] Enabling required Apache modules"
a2enmod headers

echo "[+] Disabling risky Apache modules"
for mod in status autoindex proxy proxy_http proxy_fcgi dav dav_fs cgi; do
a2dismod "$mod" 2>/dev/null || true
done

echo "[+] Hardening security.conf"
sed -i 's/^ServerTokens.*/ServerTokens Prod/' "$SEC_CONF"
sed -i 's/^ServerSignature.*/ServerSignature Off/' "$SEC_CONF"

# Add missing directives safely
grep -q "^ServerTokens" "$SEC_CONF" || echo "ServerTokens Prod" >> "$SEC_CONF"
grep -q "^ServerSignature" "$SEC_CONF" || echo "ServerSignature Off" >> "$SEC_CONF"

echo "[+] Enabling common security headers"
HEADER_BLOCK=$(cat <<'EOF'
<IfModule mod_headers.c>
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "DENY"
Header always set X-XSS-Protection "1; mode=block"
</IfModule>
EOF
)

grep -q "X-Content-Type-Options" "$APACHE_CONF" || echo "$HEADER_BLOCK" >> "$APACHE_CONF"

echo "[+] Locking down directory permissions"
cat <<'EOF' >> "$APACHE_CONF"

<Directory />
AllowOverride None
Require all denied
</Directory>

<Directory /var/www/>
AllowOverride None
Require all granted
</Directory>
EOF

echo "[+] Disabling directory listings"
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' "$APACHE_CONF"

echo "[+] Ensuring Apache runs with least privilege"
sed -i 's/^User .*/User www-data/' "$APACHE_CONF"
sed -i 's/^Group .*/Group www-data/' "$APACHE_CONF"

echo "[+] Enabling firewall rules (UFW)"
ufw allow "Apache Full" || true #this will enable port 80 and 443 so disable either one if not required

echo "[+] Restarting Apache"
systemctl restart apache2
systemctl enable apache2

echo "[+] Apache hardening complete"