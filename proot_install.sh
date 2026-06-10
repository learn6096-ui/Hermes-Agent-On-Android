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
echo -e "${GRN}                   learning"
echo -e "${CYN}=====================================================${RST}"

echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}         HERMES AGENT TERMUX INSTALLER"
echo -e "${CYN}=====================================================${RST}"

export DEBIAN_FRONTEND=noninteractive

# --- Step 1: Update Termux ---
echo -e "${YLW}[1/5] Updating Termux packages...${RST}"
yes | pkg update -y 2>&1 || true
yes | pkg upgrade -y 2>&1 || true

# --- Step 2: Install proot-distro ---
echo -e "${YLW}[2/5] Installing proot-distro...${RST}"
pkg install proot-distro -y 2>&1 || { echo -e "${RED}❌ Failed to install proot-distro${RST}"; exit 1; }

# --- Step 3: Install Ubuntu ---
echo -e "${YLW}[3/5] Setting up Ubuntu in proot...${RST}"
if ! proot-distro list 2>/dev/null | grep -q "ubuntu"; then
    echo -e "${YLW}   Downloading Ubuntu (this may take 2-5 minutes)...${RST}"
    proot-distro install ubuntu || { echo -e "${RED}❌ Failed to install Ubuntu${RST}"; exit 1; }
else
    echo -e "${GRN}   Ubuntu already installed ✅${RST}"
fi

# --- Step 4: Write inner install script to HOME (shared with proot) ---
echo -e "${YLW}[4/5] Preparing installation script...${RST}"
INNER_SCRIPT="$HOME/.hermes_inner_install.sh"

cat > "$INNER_SCRIPT" << 'INNER_EOF'
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
export TZ=UTC

echo "📦 [proot] Updating Ubuntu packages..."
apt-get update -qq 2>&1
apt-get upgrade -y -o Dpkg::Options::="--force-confold" > /dev/null 2>&1 || true

echo "📦 [proot] Installing base dependencies..."
apt-get install -y -o Dpkg::Options::="--force-confold" \
    software-properties-common gpg \
    git curl build-essential nodejs npm \
    libffi-dev libssl-dev pkg-config \
    ca-certificates > /dev/null 2>&1

# --- Python 3.13 via deadsnakes PPA (manual - no interactive prompts) ---
echo "🐍 [proot] Setting up Python 3.13..."

CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 > /dev/null 2>&1 || true
echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/deadsnakes.list
apt-get update -qq 2>&1

PYTHON_CMD="python3"
if apt-get install -y python3.13 python3.13-venv python3.13-dev > /dev/null 2>&1; then
    PYTHON_CMD="python3.13"
    echo "✅ [proot] Python 3.13 installed"
else
    echo "⚠️ [proot] Python 3.13 not available, using system python3"
    apt-get install -y python3 python3-pip python3-venv python3-dev > /dev/null 2>&1
fi

echo "📥 [proot] Cloning Hermes Agent..."
rm -rf "$HOME/hermes-agent" 2>/dev/null || true
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent"
cd "$HOME/hermes-agent"

echo "🐍 [proot] Creating virtual environment..."
$PYTHON_CMD -m venv venv

echo "⬆️  [proot] Upgrading pip..."
venv/bin/pip install --upgrade pip setuptools wheel > /dev/null 2>&1

echo "🔧 [proot] Installing Hermes Agent..."
venv/bin/pip install -e "." || { echo "❌ Failed to install Hermes Agent"; exit 1; }

echo ""
echo "✅ Hermes Agent installed inside Ubuntu!"
INNER_EOF

chmod +x "$INNER_SCRIPT"

# --- Step 5: Run inside proot ---
echo -e "${YLW}[5/5] Running installation inside Ubuntu proot...${RST}"
echo -e "${YLW}   (This may take 5-15 minutes)${RST}"
echo ""

proot-distro login ubuntu --shared-tmp -- /bin/bash "$INNER_SCRIPT"
INSTALL_STATUS=$?

rm -f "$INNER_SCRIPT" 2>/dev/null

if [ $INSTALL_STATUS -ne 0 ]; then
    echo -e "${RED}❌ Installation inside Ubuntu failed${RST}"
    exit 1
fi

echo ""
echo -e "${CYN}===================================================${RST}"
echo -e "${GRN}      ✅ Hermes Agent installed successfully!"
echo -e "${CYN}===================================================${RST}"

echo ""
echo -e "${CYN} 🔥 Run 'hermes' or 'hermes setup' to start using it${RST}"
echo -e "${CYN} 🌐 Run 'hermes gateway' to deploy it${RST}"
echo ""
echo -e "${GRN}💡 Need help? Visit: https://github.com/learn6096-ui/Hermes-Agent-On-Android${RST}"
