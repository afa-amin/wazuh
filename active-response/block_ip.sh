#!/bin/bash
set -euo pipefail

# Paths (adjust if needed)
IPSET="/usr/sbin/ipset"
IPTABLES="/sbin/iptables"
LOGGER="/usr/bin/logger"
AT="/usr/bin/at"
LOG="/var/ossec/logs/active-responses.log"
PERSIST="/var/ossec/blocked_ips.db"   # persistent record of blocks

# read JSON from stdin
read -r INPUT || true

# Extract IP and ACTION robustly using python (safe) or jq if available
IP=$(printf '%s' "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print((d.get('parameters',{}).get('alert',{}) or d.get('parameters',{})).get('srcip',''))" 2>/dev/null || true)
ACTION=$(printf '%s' "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('parameters',{}).get('action','add'))" 2>/dev/null || true)

# basic validation (IPv4 first). Extend for IPv6 if needed.
is_ipv4() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  # ensure each octet <=255
  IFS='.' read -r a b c d <<< "$1"
  for x in $a $b $c $d; do
    (( x >= 0 && x <= 255 )) || return 1
  done
  return 0
}

[ -n "$IP" ] || exit 1
is_ipv4 "$IP" || { echo "$(date) Invalid IP: $IP" >> "$LOG"; exit 1; }

# ensure ipset exists
if ! $IPSET list wazuh_block &>/dev/null; then
  $IPSET create wazuh_block hash:ip family inet hashsize 1024 maxelem 65536 || true
  echo "$(date): Created ipset wazuh_block" >> "$LOG"
fi

if [ "$ACTION" = "add" ]; then
  echo "$(date): [AR] Blocking IP $IP" | tee -a "$LOG"
  $IPSET add wazuh_block "$IP" -exist
  # persist record with expiry (store epoch unblock time). default TTL: 3600s
  TTL=3600
  UNBLOCK_AT=$(( $(date +%s) + TTL ))
  mkdir -p "$(dirname "$PERSIST")"
  printf "%s %s\n" "$IP" "$UNBLOCK_AT" >> "$PERSIST"
  $LOGGER -t wazuh-ar "Blocked $IP via ipset (ttl=${TTL}s)"
  # schedule unblock using at (if available)
  if command -v at > /dev/null 2>&1; then
    echo "$IP" | at now + $((TTL/60)) minutes 2>/dev/null || true
    # Note: we'll rely on a small helper to process at job; alternative: systemd-run or a cleanup cron
  fi
elif [ "$ACTION" = "delete" ]; then
  echo "$(date): [AR] Unblocking IP $IP" | tee -a "$LOG"
  $IPSET del wazuh_block "$IP" 2>/dev/null || true
  # remove from persist
  if [ -f "$PERSIST" ]; then
    grep -v "^$IP " "$PERSIST" > "${PERSIST}.tmp" && mv "${PERSIST}.tmp" "$PERSIST" || true
  fi
  $LOGGER -t wazuh-ar "Unblocked $IP"
else
  echo "$(date): [AR] Unknown action $ACTION for IP $IP" >> "$LOG"
  exit 1
fi

