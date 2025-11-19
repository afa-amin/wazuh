#!/bin/bash
set -euo pipefail

# ============================ COLORS ============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================ PATHS ==============================
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAZUH_ETC="/var/ossec/etc"
WAZUH_RULES="/var/ossec/etc/rules"
WAZUH_AR_BIN="/var/ossec/active-response/bin"
WAZUH_BIN="/var/ossec/bin"

clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        WAZUH SMART DEFENSE MODULE – INSTALLER            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# =================================================================
# STEP 0 — OS DETECTION AND PACKAGE INSTALLATION
# =================================================================
echo -e "${BLUE}Step 0: Operating System selection${NC}"
echo -e "${YELLOW}Select your Linux distribution:${NC}"
echo "1) Debian / Ubuntu"
echo "2) Arch Linux / Manjaro"
echo "3) RHEL / CentOS / Rocky / Alma"
echo

read -rp "Enter choice (1-3): " os_choice
echo

install_pkg() {
    local pkg="$1"
    echo -e "${BLUE}[PKG] Installing: $pkg${NC}"
    case "$os_choice" in
        1) sudo apt-get update -y && sudo apt-get install -y "$pkg" ;;
        2) sudo pacman -Sy --noconfirm "$pkg" ;;
        3) sudo yum install -y "$pkg" ;;
        *) echo -e "${RED}Invalid OS choice.${NC}"; exit 1;;
    esac
}

echo -e "${BLUE}Installing required dependencies...${NC}"

install_pkg iptables
install_pkg postfix
install_pkg sendmail
install_pkg ipset

echo -e "${GREEN}[OK] Dependencies installed.${NC}"
echo

# =================================================================
# STEP 1 — Verify Wazuh Manager
# =================================================================
echo -e "${BLUE}Step 1: Checking Wazuh Manager...${NC}"

if ! systemctl list-units | grep -q "wazuh-manager.service"; then
    echo -e "${RED}[FATAL] wazuh-manager is NOT installed.${NC}"
    exit 1
fi

if ! systemctl is-active --quiet wazuh-manager; then
    echo -e "${RED}[FATAL] Wazuh Manager installed but NOT running.${NC}"
    echo -e "${YELLOW}Start it with: sudo systemctl start wazuh-manager${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Wazuh Manager is installed & running.${NC}"
echo

# =================================================================
# STEP 2 — Create required directories
# =================================================================
echo -e "${BLUE}Step 2: Preparing directories...${NC}"
sudo mkdir -p "$WAZUH_RULES" "$WAZUH_AR_BIN" "$WAZUH_BIN"
echo -e "${GREEN}[OK] Directories ready.${NC}"
echo

# =================================================================
# STEP 3 — Deploy ossec.conf
# =================================================================
echo -e "${BLUE}Step 3: Installing ossec.conf...${NC}"

sudo cp "$MODULE_DIR/ossec.conf" "$WAZUH_ETC/ossec.conf"
sudo chown root:wazuh "$WAZUH_ETC/ossec.conf"
sudo chmod 640 "$WAZUH_ETC/ossec.conf"

echo -e "${GREEN}→ Installed: /var/ossec/etc/ossec.conf${NC}"
echo

# =================================================================
# STEP 4 — Deploy rule files
# =================================================================
echo -e "${BLUE}Step 4: Installing local rules...${NC}"

sudo cp "$MODULE_DIR/local_rules.xml" "$WAZUH_RULES/local_rules.xml"
sudo chown root:wazuh "$WAZUH_RULES/local_rules.xml"
sudo chmod 640 "$WAZUH_RULES/local_rules.xml"

echo -e "${GREEN}→ Installed: /var/ossec/etc/rules/local_rules.xml${NC}"
echo

# =================================================================
# STEP 5 — Deploy Active Response scripts
# =================================================================
echo -e "${BLUE}Step 5: Installing Active-Response scripts...${NC}"

for script in block-ip.py rate-limit.py quarantine_mail.sh notify_soc.sh; do
    src="$MODULE_DIR/active-response/$script"
    dst="$WAZUH_AR_BIN/$script"

    if [[ ! -f "$src" ]]; then
        echo -e "${RED}[ERROR] Missing file: $src${NC}"
        exit 1
    fi

    sudo cp "$src" "$dst"
    sudo chown root:wazuh "$dst"
    sudo chmod 750 "$dst"

    echo -e "${GREEN}→ Installed: $script${NC}"
done
echo

# =================================================================
# STEP 6 — Restart Wazuh Manager
# =================================================================
echo -e "${BLUE}Step 6: Restarting Wazuh Manager...${NC}"

sudo systemctl restart wazuh-manager
sleep 2

if systemctl is-active --quiet wazuh-manager; then
    echo -e "${GREEN}[SUCCESS] Wazuh restarted successfully.${NC}"
else
    echo -e "${RED}[ERROR] Wazuh Manager FAILED to restart.${NC}"
    exit 1
fi

# =================================================================
# DONE
# =================================================================
echo
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        INSTALLATION COMPLETED SUCCESSFULLY!              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Wazuh Smart Defense Module Installed!${NC}"
echo
