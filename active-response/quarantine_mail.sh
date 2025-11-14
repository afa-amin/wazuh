#!/bin/bash
set -euo pipefail

read -r INPUT || true
IP=$(printf '%s' "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print((d.get('parameters',{}).get('alert',{}) or d.get('parameters',{})).get('srcip',''))" 2>/dev/null || true)
[ -n "$IP" ] || exit 1

QUARANTINE_DIR="/var/ossec/quarantine"
LOG="/var/ossec/logs/active-responses.log"
mkdir -p "$QUARANTINE_DIR"

FNAME="quarantine_${IP}_$(date +%s).log"
echo "IP: $IP" > "$QUARANTINE_DIR/$FNAME"
echo "Time: $(date -u +'%Y-%m-%d %H:%M:%SZ')" >> "$QUARANTINE_DIR/$FNAME"
echo "Reason: Suspicious mail activity (rule triggered)" >> "$QUARANTINE_DIR/$FNAME"

echo "$(date): [AR] Email activity from $IP quarantined -> $QUARANTINE_DIR/$FNAME" >> "$LOG"
/usr/bin/logger -t wazuh-ar "Quarantined mail activity from $IP"
