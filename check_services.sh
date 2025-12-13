#!/bin/bash

WHITELIST="good_services.txt"

if [[ ! -f "$WHITELIST" ]]; then
    echo "[-] Whitelist file not found: $WHITELIST"
    exit 1
fi

# Normalize whitelist: remove CR (\r) characters and trim spaces
mapfile -t WHITELIST_ARRAY < <(sed 's/\r$//' "$WHITELIST" | sed 's/[[:space:]]*$//')

echo "[+] Comparing running services against whitelist..."
echo "[+] Potentially bad services:"

systemctl list-units --type=service --state=running --no-legend \
| awk '{print $1}' \
| while IFS= read -r service; do
    BAD=true
    for w in "${WHITELIST_ARRAY[@]}"; do
        if [[ "$service" == "$w" ]]; then
            BAD=false
            break
        fi
    done
    if $BAD; then
        echo "  [BAD] $service"
    fi
done