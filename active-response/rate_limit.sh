#!/bin/bash
set -euo pipefail

IP="$2"
ACTION="$1"
IPTABLES="/sbin/iptables"
LOGGER="/usr/bin/logger"
LOG="/var/ossec/logs/active-responses.log"

[ -n "$IP" ] || { echo "No IP provided" >> "$LOG"; exit 1; }

# validate ipv4
if ! [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "$(date): [RATE_LIMIT] Invalid IP: $IP" >> "$LOG"
  exit 1
fi

LIMIT="5/sec"    # iptables limit module format
BURST="10"

if [[ "$ACTION" == "add" ]]; then
  echo "$(date): [RATE_LIMIT] Applying rate-limit to $IP" >> "$LOG"
  # remove previous duplicates if any
  $IPTABLES -D INPUT -s "$IP" -m limit --limit ${LIMIT} --limit-burst ${BURST} -j ACCEPT 2>/dev/null || true
  $IPTABLES -D INPUT -s "$IP" -j DROP 2>/dev/null || true
  # Insert ACCEPT matching limit, then DROP all
  $IPTABLES -I INPUT -s "$IP" -m limit --limit ${LIMIT} --limit-burst ${BURST} -j ACCEPT
  $IPTABLES -I INPUT -s "$IP" -j DROP
  $LOGGER -t wazuh-ar "Applied rate-limit to $IP ($LIMIT, burst=$BURST)"
elif [[ "$ACTION" == "delete" ]]; then
  echo "$(date): [RATE_LIMIT] Removing rate-limit for $IP" >> "$LOG"
  $IPTABLES -D INPUT -s "$IP" -m limit --limit ${LIMIT} --limit-burst ${BURST} -j ACCEPT 2>/dev/null || true
  $IPTABLES -D INPUT -s "$IP" -j DROP 2>/dev/null || true
  $LOGGER -t wazuh-ar "Removed rate-limit for $IP"
else
  echo "$(date): [RATE_LIMIT] Unknown action $ACTION for $IP" >> "$LOG"
  exit 1
fi
