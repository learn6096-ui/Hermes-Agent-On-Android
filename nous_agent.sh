#!/data/data/com.termux/files/usr/bin/bash

set -e

# Colors
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
RST='\033[0m'

clear

echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}                learning"
echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}         ☤ HERMES AGENT TERMUX INSTALLER ☤"
echo -e "${CYN}=====================================================${RST}"

echo -e "${YLW}Updating packages and handling prompts...${RST}"

# --- Termux Level Commands (Fixes the Y/N prompt from your image) ---
export DEBIAN_FRONTEND=noninteractive
pkg update -y -o Dpkg::Options::="--force-confold"
pkg upgrade -y -o Dpkg::Options::="--force-confold"
pkg install proot-distro -y

# Install Ubuntu (Check if already installed to avoid error)
if ! proot-distro list 2>/dev/null | grep -A2 "ubuntu" | grep -qi "installed"; then
    proot-distro install ubuntu
fi

# Use proot-distro login with -- to execute commands inside Ubuntu
proot-distro login ubuntu -- bash -c "
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -o Dpkg::Options::='--force-confold' > /dev/null 2>&1 || true

    # Install base dependencies
    apt-get install -y -o Dpkg::Options::='--force-confold' \
        software-properties-common \
        git curl build-essential nodejs npm \
        python3-dev libffi-dev libssl-dev pkg-config \
        ca-certificates > /dev/null 2>&1

    # Add deadsnakes PPA for Python 3.13
    add-apt-repository -y ppa:deadsnakes/ppa > /dev/null 2>&1
    apt-get update -qq

    # Install Python 3.13 with dev headers and venv
    apt-get install -y python3.13 python3.13-venv python3.13-dev > /dev/null 2>&1

    if [ ! -d \"hermes-agent\" ]; then
        git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git
    fi
    
    cd hermes-agent

    # Setup venv with Python 3.13
    python3.13 -m venv venv

    # Use venv/bin/pip directly to avoid activation issues in subshell
    venv/bin/pip install --upgrade pip > /dev/null 2>&1
    venv/bin/pip install -e .
"

echo -e "${CYN}===================================================${RST}"
echo -e "${GRN}     ✅ Hermes Agent installed successfully!"
echo -e "${CYN}===================================================${RST}"

echo "📖 Type 'proot-distro login ubuntu' to enter your environment"
echo "💡 Need help? Visit: https://github.com/learn6096-ui/Hermes-Agent-On-Android"

echo -e "${YLW}Run 'hermes setup' for onboarding${RST}"
echo -e "${YLW}Run 'hermes' to use${RST}"

echo " "
echo -e "${CYN}START FRESH HERMES AFTER CLOSING TERMUX${RST}"
echo " "
echo -e "${YLW}proot-distro login ubuntu${RST}"
echo " "
echo -e "${YLW}cd hermes-agent${RST}"
echo " "
echo -e "${YLW}source venv/bin/activate${RST}"
echo " "
echo -e "${CYN}hermes${RST}"