#!/bin/bash
### MAKE sure to stop the service before running the script because this will configure then validate it and ensure it starts
## ALSO be sure to read the README so nothing conflicts with the script and brick the service

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "===== make sure this is being ran as root"
    exit 1
fi

NGINX_CONF="/etc/nginx/nginx.conf"
DEFAULT_SITE="/etc/nginx/sites-available/default"
BACKUP_DIR="/etc/nginx/backup"

HARDENING_SNIPPET="/etc/nginx/snippets/security-headers.conf"
HARDENING_GLOBAL="/etc/nginx/conf.d/99-hardening.conf"

echo "==== ensuring nginx is installed"
apt update
apt install nginx -y

#enable nginx, but dont start because we will restart after validating it
systemctl enable nginx

echo "=== creating backup directory" 
mkdir -p "$BACKUP_DIR"

echo "==== backing up nginx config files"
cp -p "$NGINX_CONF" "$BACKUP_DIR/nginx.conf"
if [[ -f "$DEFAULT_SITE" ]]; then
    cp -p "$DEFAULT_SITE" "$BACKUP_DIR/default"
fi

echo "==== backups saved under $BACKUP_DIR"

echo "==== writing security headers snippet"
mkdir -p /etc/nginx/snippets
cat > "$HARDENING_SNIPPET" <<'EOF'
# Basic security headers, safe defaults
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-XSS-Protection "0" always;
# HSTS is ONLY safe when you already have HTTPS working everywhere.
# Uncomment after TLS is configured and verified:
# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
EOF

echo "====== Writing global hardening config"
cat > "$HARDENING_GLOBAL" <<'EOF'
# Hide nginx version
server_tokens off;
# timeouts to reduce abuse
client_body_timeout 10s;
client_header_timeout 10s;
send_timeout 10s;
keepalive_timeout 15s;
# Disable directory listing globally unless overridden
autoindex off;
EOF

echo "====== Ensuring nginx.conf includes /etc/nginx/conf.d/*.conf and snippets are available"
# ensures it contains the conf.d include.
if ! grep -qE 'include\s+/etc/nginx/conf\.d/\*\.conf;' "$NGINX_CONF"; then
  # Insert inside the http {} block right after it opens
  sed -i '0,/http\s*{/s/http\s*{/http {\n\tinclude \/etc\/nginx\/conf.d\/\*\.conf;/' "$NGINX_CONF"
fi

#echo "====== Updating default site with safe baseline"
# Update the this line according to the README
#server {
 #   listen 80 default_server;
 #   listen [::]:80 default_server;

 #   server_name _;

    # Basic hardening
 #   include $HARDENING_SNIPPET;

    # Rate limit per IP (bursty but controlled)
 #   limit_req zone=req_per_ip burst=20 nodelay;

    # Serve a basic static root by default (safe)
 #   root /var/www/html;
 #   index index.html index.htm;

 #   location / {
 #       try_files \$uri \$uri/ =404;
  #  }

    # Block access to hidden files (except .well-known for ACME/certbot)
 #   location ~ /\.(?!well-known) {
 #       deny all;
 #   }
#}
#EOF

echo "====== Testing nginx configuration"
if nginx -t; then
  echo "==== nginx config OK"
  systemctl restart nginx
else
  echo "===== CRITICAL: nginx config test failed. Reverting backups."
  cp -p "$BACKUP_DIR/nginx.conf" "$NGINX_CONF"
  if [[ -f "$BACKUP_DIR/default" ]]; then
    cp -p "$BACKUP_DIR/default" "$DEFAULT_SITE"
  fi
  exit 1
fi

echo "====== Configuring UFW for nginx http"
ufw allow 80/tcp

if ! ufw status | grep -q "Status: active"; then
  ufw --force enable
fi

echo "====== Nginx hardening complete"
echo "- This enables HTTP on port 80. TLS is not configured yet."
