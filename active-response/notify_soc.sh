#!/bin/bash
set -euo pipefail

read -r INPUT || true
IP=$(printf '%s' "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print((d.get('parameters',{}).get('alert',{}) or d.get('parameters',{})).get('srcip',''))" 2>/dev/null || true)
RULE=$(printf '%s' "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('rule',{}).get('description',''))" 2>/dev/null || true)
LOG="/var/ossec/logs/active-responses.log"
SOC_LOG="/var/ossec/soc_alerts.log"

[ -n "$IP" ] || exit 1

ALERT="Wazuh Alert: ${RULE:-'Critical activity'} from $IP at $(date -u +'%Y-%m-%d %H:%M:%SZ')"
echo "$ALERT" >> "$SOC_LOG"
echo "$(date): [AR] SOC notified about IP $IP (rule: ${RULE})" >> "$LOG"

# example: logger to syslog
/usr/bin/logger -t wazuh-ar -p authpriv.crit "$ALERT"

# email alerts using notify_soc and sendmail
# if [ -n "${SENDMAIL_FROM:-}" ] && [ -n "${SENDMAIL_TO:-}" ]; then
#   {
#     printf 'From: %s\n' "$SENDMAIL_FROM"
#     printf 'To: %s\n' "$SENDMAIL_TO"
#     printf 'Subject: [Wazuh Alert] %s\n' "${RULE:-'Critical Activity'}"
#     printf 'Content-Type: text/plain; charset=UTF-8\n\n'
#     printf '%s\n' "$ALERT"
#   } | /usr/sbin/sendmail -t -f "$SENDMAIL_FROM" || true
# fi
