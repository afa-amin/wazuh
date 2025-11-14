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
WAZUH_AR="/var/ossec/active-response"
WAZUH_BIN="/var/ossec/bin"

# Banner
clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     WAZUH SMART DEFENSE MODULE   -   INTELLIGENT INSTALLER      ║${NC}"
echo -e "${BLUE}║                                                                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Helper: ask yes/no
ask() {
    local prompt="$1"
    local default="${2:-}"
    local answer
    while true; do
        if [[ "$default" == "Y" ]]; then
            read -p "$prompt [Y/n]: " answer
            answer=${answer:-Y}
        elif [[ "$default" == "N" ]]; then
            read -p "$prompt [y/N]: " answer
            answer=${answer:-N}
        else
            read -p "$prompt [y/n]: " answer
        fi
        case "$answer" in
            [Yy]* ) echo "Y"; return 0;;
            [Nn]* ) echo "N"; return 1;;
            * ) echo -e "${YELLOW}Please answer y or n.${NC}";;
        esac
    done
}

# Helper: install package
install_pkg() {
    local pkg="$1"
    local reason="$2"
    if ! command -v "$pkg" &> /dev/null && ! dpkg -l | grep -q "$pkg" &> /dev/null; then
        echo -e "${YELLOW}[INFO] $pkg is not installed.${NC}"
        echo -e "${YELLOW}→ $reason${NC}"
        if [[ $(ask "Do you want to install $pkg now?" "Y") == "Y" ]]; then
            echo -e "${BLUE}[INSTALL] Installing $pkg...${NC}"
            sudo apt update -qq && sudo apt install -y "$pkg" || {
                echo -e "${RED}[ERROR] Failed to install $pkg. Please install manually.${NC}"
                return 1
            }
            echo -e "${GREEN}[SUCCESS] $pkg installed.${NC}"
        else
            echo -e "${RED}[SKIP] $pkg skipped. Module may not work fully.${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}[OK] $pkg is already installed.${NC}"
    fi
    return 0
}

# === STEP 1: Check Wazuh Manager ===
echo -e "${BLUE}Step 1: Checking Wazuh Manager...${NC}"
if ! systemctl is-active --quiet wazuh-manager; then
    echo -e "${RED}[ERROR] Wazuh Manager is not running or not installed.${NC}"
    echo -e "${YELLOW}→ This module requires Wazuh Manager v4.7+ to be installed and running.${NC}"
    if [[ $(ask "Do you want to install Wazuh Manager now?" "N") == "Y" ]]; then
        echo -e "${BLUE}[INSTALL] Installing Wazuh Manager...${NC}"
        curl -sO https://packages.wazuh.com/4.x/install.sh && sudo bash install.sh || {
            echo -e "${RED}[FATAL] Wazuh installation failed. Aborting.${NC}"
            exit 1
        }
    else
        echo -e "${RED}[FATAL] Cannot proceed without Wazuh Manager.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}[OK] Wazuh Manager is running.${NC}"
fi

# === STEP 2: Check Dependencies ===
echo -e "${BLUE}Step 2: Checking required dependencies...${NC}"

# sendmail (for email alerts)
install_pkg "sendmail" "sendmail is required for real-time email alerts via Wazuh email_alerts."

# postfix (for SMTP server simulation in testing)
install_pkg "postfix" "postfix is required to simulate SMTP server for testing SMTP rules."

# ipset (for persistent IP blocking)
install_pkg "ipset" "ipset is required for firewall-drop with persistence across reboots."

# python3 (for JSON parsing in notify_soc.sh)
if ! command -v python3 &> /dev/null; then
    install_pkg "python3" "python3 is required for JSON parsing in notify_soc.sh."
fi

# === STEP 3: Copy Files ===
echo -e "${BLUE}Step 3: Deploying module files...${NC}"

sudo mkdir -p "$WAZUH_RULES" "$WAZUH_AR/bin" "$WAZUH_BIN"

echo -e "${BLUE}[COPY] Deploying custom rules...${NC}"
sudo cp "$MODULE_DIR/local_rules.xml" "$WAZUH_RULES/local_rules.xml" && \
echo -e "${GREEN}→ $WAZUH_RULES/local_rules.xml${NC}"

echo -e "${BLUE}[COPY] Deploying Active Response scripts...${NC}"
sudo cp -r "$MODULE_DIR/active-response/"* "$WAZUH_AR/" && \
sudo chown -R root:wazuh "$WAZUH_AR/bin/" && \
sudo chmod 750 "$WAZUH_AR/bin/"*.sh && \
echo -e "${GREEN}→ Active Response scripts deployed${NC}"

echo -e "${BLUE}[COPY] Deploying test script...${NC}"
sudo cp "$MODULE_DIR/wazuh-ar-tester.sh" "$WAZUH_BIN/" && \
sudo chmod 750 "$WAZUH_BIN/wazuh-ar-tester.sh" && \
echo -e "${GREEN}→ $WAZUH_BIN/wazuh-ar-tester.sh${NC}"

# === STEP 4: Restart Wazuh ===
echo -e "${BLUE}Step 4: Restarting Wazuh Manager...${NC}"
sudo systemctl restart wazuh-manager
sleep 3
if systemctl is-active --quiet wazuh-manager; then
    echo -e "${GREEN}[SUCCESS] Wazuh Manager restarted successfully.${NC}"
else
    echo -e "${RED}[ERROR] Wazuh Manager failed to restart.${NC}"
    exit 1
fi

# === FINAL MESSAGE ===
echo
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                INSTALLATION COMPLETED SUCCESSFULLY!                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Module: Wazuh Smart Defense v3.3${NC}"
echo -e "${GREEN}Status: Fully Installed and Active${NC}"
echo
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "   1. Test Active Response: ${GREEN}sudo $WAZUH_BIN/wazuh-ar-tester.sh${NC}"
echo -e "   2. View alerts: ${GREEN}tail -f /var/ossec/logs/alerts/alerts.log${NC}"
echo -e "   3. Check email: Configure <email_to> in /var/ossec/etc/ossec.conf${NC}"
echo
echo -e "${BLUE}Thank you for using Wazuh Smart Defense!${NC}"
