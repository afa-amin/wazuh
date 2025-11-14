#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAZUH_RULES="/var/ossec/etc/rules"
WAZUH_AR_BIN="/var/ossec/active-response/bin"
WAZUH_BIN="/var/ossec/bin"

# Banner
clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        WAZUH SMART DEFENSE MODULE – INSTALLER            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# ============================================================
# Helper: check package
# ============================================================
check_pkg() {
    local pkg="$1"
    local reason="$2"

    if dpkg -l | grep -q "^ii  $pkg"; then
        echo -e "${GREEN}[OK] $pkg is installed.${NC}"
    else
        echo -e "${YELLOW}[WARN] $pkg is NOT installed.${NC}"
        echo -e "${YELLOW}→ RECOMMENDED: $reason${NC}"
    fi
}

# ============================================================
# STEP 1 — Check Wazuh Manager
# ============================================================
echo -e "${BLUE}Step 1: Checking Wazuh Manager...${NC}"

if ! systemctl list-units --type=service | grep -q "wazuh-manager.service"; then
    echo -e "${RED}[FATAL] Wazuh Manager service is NOT installed!${NC}"
    echo -e "${YELLOW}→ Please install Wazuh Manager first and rerun this script.${NC}"
    exit 1
fi

if ! systemctl is-active --quiet wazuh-manager; then
    echo -e "${RED}[FATAL] Wazuh Manager is installed but NOT running.${NC}"
    echo -e "${YELLOW}→ Please start it first: sudo systemctl start wazuh-manager${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Wazuh Manager is installed and running.${NC}"

# ============================================================
# STEP 2 — Check recommended dependencies
# ============================================================
echo -e "${BLUE}Step 2: Checking recommended dependencies...${NC}"

check_pkg "sendmail" "Required for Wazuh email alert delivery."
check_pkg "postfix"  "Useful for SMTP testing and mail relay."
check_pkg "ipset"    "Required for persistent firewall IP blocks."

echo -e "${YELLOW}[INFO] Missing packages will NOT stop installation.${NC}"
echo

# ============================================================
# STEP 3 — Deploy Module Files
# ============================================================
echo -e "${BLUE}Step 3: Deploying Smart Defense module...${NC}"

sudo mkdir -p "$WAZUH_RULES" "$WAZUH_AR_BIN" "$WAZUH_BIN"

# --- Copy Rules ---
echo -e "${BLUE}[COPY] Installing custom rule file...${NC}"
sudo cp "$MODULE_DIR/local_rules.xml" "$WAZUH_RULES/local_rules.xml"
echo -e "${GREEN}→ Installed: $WAZUH_RULES/local_rules.xml${NC}"

# --- Copy Active Response Scripts ---
echo -e "${BLUE}[COPY] Installing Active Response scripts...${NC}"

for f in "$MODULE_DIR/active-response/"*.sh; do
    filename=$(basename "$f")

    sudo cp "$f" "$WAZUH_AR_BIN/$filename"
    sudo chown root:wazuh "$WAZUH_AR_BIN/$filename"
    sudo chmod 750 "$WAZUH_AR_BIN/$filename"

    echo -e "${GREEN}→ Installed: $filename${NC}"
done

# --- Copy Tester Script ---
echo -e "${BLUE}[COPY] Installing tester script...${NC}"
sudo cp "$MODULE_DIR/wazuh-ar-tester.sh" "$WAZUH_BIN/"
sudo chmod 750 "$WAZUH_BIN/wazuh-ar-tester.sh"
echo -e "${GREEN}→ Installed: $WAZUH_BIN/wazuh-ar-tester.sh${NC}"

# ============================================================
# STEP 4 — Restart Wazuh
# ============================================================
echo -e "${BLUE}Step 4: Restarting Wazuh Manager...${NC}"
sudo systemctl restart wazuh-manager
sleep 2

if systemctl is-active --quiet wazuh-manager; then
    echo -e "${GREEN}[SUCCESS] Wazuh Manager restarted successfully.${NC}"
else
    echo -e "${RED}[ERROR] Wazuh Manager FAILED to restart.${NC}"
    exit 1
fi

# ============================================================
# DONE
# ============================================================
echo
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        INSTALLATION COMPLETED SUCCESSFULLY!              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

echo -e "${GREEN}Module: Wazuh Smart Defense v3.3${NC}"
echo -e "${GREEN}Status: Installed & Activated${NC}"
echo
echo -e "${YELLOW}You can test Active Response using:${NC}"
echo -e "   ${GREEN}sudo $WAZUH_BIN/wazuh-ar-tester.sh${NC}"
echo
