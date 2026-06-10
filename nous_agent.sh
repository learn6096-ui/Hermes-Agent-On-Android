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
    git curl wget build-essential \
    nodejs npm \
    python3-dev libffi-dev libssl-dev pkg-config \
    ca-certificates > /dev/null 2>&1

# --- Python 3.13 via deadsnakes PPA (manual method - no interactive prompts) ---
echo "🐍 [proot] Setting up Python 3.13..."

CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")

# Manually add deadsnakes PPA key + source (avoids interactive add-apt-repository)
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
if [ ! -d "$HOME/hermes-agent/.git" ]; then
    rm -rf "$HOME/hermes-agent" 2>/dev/null || true
    git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent"
else
    echo "   Repository already exists, updating..."
    cd "$HOME/hermes-agent"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
fi

cd "$HOME/hermes-agent"

echo "🐍 [proot] Creating virtual environment..."
rm -rf venv 2>/dev/null || true
$PYTHON_CMD -m venv venv

echo "⬆️  [proot] Upgrading pip..."
venv/bin/pip install --upgrade pip setuptools wheel > /dev/null 2>&1

echo "🔧 [proot] Installing Hermes Agent (this takes 5-10 minutes)..."
venv/bin/pip install -e "." || { echo "❌ Failed to install Hermes Agent"; exit 1; }

echo ""
echo "✅ Hermes Agent installed inside Ubuntu!"
echo "🐍 Python: $($PYTHON_CMD --version)"
INNER_EOF

chmod +x "$INNER_SCRIPT"

# --- Step 5: Run the inner script inside proot ---
echo -e "${YLW}[5/5] Running installation inside Ubuntu proot...${RST}"
echo -e "${YLW}   (This may take 5-15 minutes depending on your connection)${RST}"
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
echo -e "${GRN}     ✅ Hermes Agent installed successfully!"
echo -e "${CYN}===================================================${RST}"

echo ""
echo -e "${YLW}🚀 To use Hermes Agent:${RST}"
echo ""
echo -e "${CYN}   proot-distro login ubuntu${RST}"
echo -e "${CYN}   cd hermes-agent && source venv/bin/activate${RST}"
echo -e "${CYN}   hermes setup   # first-time only${RST}"
echo -e "${CYN}   hermes          # start using${RST}"
echo ""
echo -e "${GRN}💡 Need help? Visit: https://github.com/learn6096-ui/Hermes-Agent-On-Android${RST}"