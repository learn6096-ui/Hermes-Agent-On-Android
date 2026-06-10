#!/data/data/com.termux/files/usr/bin/bash
#
# Nous Hermes Agent Installer for Android (Termux)
# Most robust installer — handles all edge cases
#
# Usage in Termux:
#   curl -fsSL https://raw.githubusercontent.com/learn6096-ui/Hermes-Agent-On-Android/main/nous_hermes_agent_install.sh | bash
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
RST='\033[0m'

clear

echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}         ☤ HERMES AGENT TERMUX INSTALLER ☤"
echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}       Fixed & Modernized | learn6096-ui"
echo -e "${CYN}=====================================================${RST}"
echo ""

# --- Termux Level Setup ---
export DEBIAN_FRONTEND=noninteractive
export TZ=UTC

# Prevent Android from killing Termux while installing
termux-wake-lock 2>/dev/null || true

# === STEP 1: Update Termux ===
echo -e "${YLW}[1/5] 📦 Updating Termux packages...${RST}"
if ! yes | pkg update -y 2>&1; then
    echo -e "${YLW}⚠️  pkg update had issues, trying fix...${RST}"
    apt --fix-broken install -y 2>&1 || true
    yes | pkg update -y 2>&1 || true
fi

echo -e "${YLW}      📦 Upgrading Termux packages...${RST}"
yes | pkg upgrade -y 2>&1 || true

# === STEP 2: Install proot-distro ===
echo -e "${YLW}[2/5] 🔧 Installing proot-distro...${RST}"
if ! pkg install proot-distro -y 2>&1; then
    echo -e "${RED}❌ Failed to install proot-distro${RST}"
    exit 1
fi

# === STEP 3: Install Ubuntu in proot ===
echo -e "${YLW}[3/5] 🐧 Setting up Ubuntu in proot...${RST}"
if ! proot-distro list 2>/dev/null | grep -q "ubuntu"; then
    echo -e "${YLW}      Downloading Ubuntu (this takes 2-5 minutes)...${RST}"
    if ! proot-distro install ubuntu; then
        echo -e "${RED}❌ Failed to install Ubuntu${RST}"
        exit 1
    fi
    echo -e "${GRN}      ✅ Ubuntu installed${RST}"
else
    echo -e "${GRN}      ✅ Ubuntu already installed${RST}"
fi

# === STEP 4: Write inner script to $HOME (accessible from proot) ===
echo -e "${YLW}[4/5] 📝 Preparing installation script...${RST}"

# IMPORTANT: Write to $HOME, NOT mktemp. $HOME is shared between Termux and proot.
# mktemp creates files in $PREFIX/tmp which is NOT accessible inside proot without --shared-tmp.
INNER_SCRIPT="$HOME/.hermes_inner_install.sh"

cat > "$INNER_SCRIPT" << 'INNER_EOF'
#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export TZ=UTC

echo ""
echo "═══════════════════════════════════════════"
echo "  Running inside Ubuntu proot environment"
echo "═══════════════════════════════════════════"
echo ""

# --- Update Ubuntu packages ---
echo "📦 [proot] Updating Ubuntu packages..."
apt-get update -qq 2>&1
apt-get upgrade -y -o Dpkg::Options::="--force-confold" > /dev/null 2>&1 || true

# --- Install system dependencies ---
echo "📦 [proot] Installing system dependencies..."
apt-get install -y -o Dpkg::Options::="--force-confold" \
    software-properties-common gpg lsb-release \
    git curl wget build-essential \
    nodejs npm \
    libffi-dev libssl-dev pkg-config \
    ca-certificates > /dev/null 2>&1

# --- Python 3.13 via deadsnakes PPA ---
# IMPORTANT: We use manual apt-key + sources.list instead of add-apt-repository
# because add-apt-repository is interactive and hangs in proot/non-interactive shells
echo "🐍 [proot] Setting up Python 3.13 from deadsnakes PPA..."

CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")

# Manually import the deadsnakes GPG key
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 > /dev/null 2>&1 || true

# Manually add the deadsnakes source list
echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/deadsnakes.list

apt-get update -qq 2>&1

# Try Python 3.13, fall back to system python3 if unavailable
PYTHON_CMD="python3"
if apt-get install -y python3.13 python3.13-venv python3.13-dev > /dev/null 2>&1; then
    PYTHON_CMD="python3.13"
    # Set as default python3
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 2>/dev/null || true
    update-alternatives --set python3 /usr/bin/python3.13 2>/dev/null || true
    # Create python symlink
    [ ! -f /usr/bin/python ] && ln -sf /usr/bin/python3.13 /usr/bin/python
    echo "✅ [proot] Python 3.13 installed successfully"
else
    echo "⚠️  [proot] Python 3.13 not available for ${CODENAME}, using system python3"
    apt-get install -y python3 python3-pip python3-venv python3-dev > /dev/null 2>&1 || true
    echo "✅ [proot] System python3 ready: $(python3 --version)"
fi

REPO_DIR="$HOME/hermes-agent"

# --- Clone or update repository ---
if [ -d "$REPO_DIR/.git" ]; then
    echo "🔄 [proot] Updating existing hermes-agent repository..."
    cd "$REPO_DIR"
    git fetch origin 2>/dev/null || true
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    git reset --hard origin/main 2>/dev/null || git reset --hard origin/master 2>/dev/null || true
else
    echo "📥 [proot] Cloning Hermes Agent repository..."
    rm -rf "$REPO_DIR" 2>/dev/null || true
    git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/NousResearch/hermes-agent.git "$REPO_DIR"
    cd "$REPO_DIR"
fi

# --- Setup Python venv ---
echo "🐍 [proot] Creating virtual environment with ${PYTHON_CMD}..."
[ -d "venv" ] && rm -rf venv
$PYTHON_CMD -m venv venv

echo "⬆️  [proot] Upgrading pip, setuptools, wheel..."
venv/bin/pip install --upgrade pip setuptools wheel > /dev/null 2>&1

echo "🔧 [proot] Installing Hermes Agent (this can take 5-10 minutes)..."
# Try full extras first, fall back to base
if ! venv/bin/pip install -e ".[all]" > /dev/null 2>&1; then
    echo "⚠️  Full extras install failed, trying base install..."
    if ! venv/bin/pip install -e "."; then
        echo "❌ Failed to install Hermes Agent"
        exit 1
    fi
fi

# --- Create launcher script ---
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/hermes" << 'LAUNCHER_EOF'
#!/bin/bash
cd "$HOME/hermes-agent"
source venv/bin/activate
exec hermes "$@"
LAUNCHER_EOF
chmod +x "$HOME/.local/bin/hermes"

# Ensure PATH includes ~/.local/bin
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Hermes Agent installed successfully!"
echo "  🐍 Python: $($PYTHON_CMD --version)"
echo "═══════════════════════════════════════════"
INNER_EOF

chmod +x "$INNER_SCRIPT"

# === STEP 5: Run inner script inside Ubuntu proot ===
echo -e "${YLW}[5/5] 🚀 Running installation inside Ubuntu...${RST}"
echo -e "${YLW}      (This may take 5-15 minutes depending on your connection)${RST}"
echo ""

# CRITICAL: Use --shared-tmp so the script file is accessible inside proot
if ! proot-distro login ubuntu --shared-tmp -- /bin/bash "$INNER_SCRIPT"; then
    echo -e "${RED}❌ Installation inside Ubuntu failed${RST}"
    echo -e "${YLW}💡 Try running again, or check your internet connection${RST}"
    rm -f "$INNER_SCRIPT" 2>/dev/null
    exit 1
fi

# Cleanup
rm -f "$INNER_SCRIPT" 2>/dev/null

# Release wake lock
termux-wake-unlock 2>/dev/null || true

echo ""
echo -e "${CYN}===================================================${RST}"
echo -e "${GRN}     ✅ Hermes Agent installed successfully!"
echo -e "${CYN}===================================================${RST}"
echo ""
echo -e "${YLW}🚀 Quick Start:${RST}"
echo -e "${CYN}   proot-distro login ubuntu${RST}"
echo -e "${CYN}   hermes setup      # Run first-time setup${RST}"
echo -e "${CYN}   hermes            # Start chatting${RST}"
echo ""
echo -e "${YLW}📖 Manual path (if hermes command not found):${RST}"
echo -e "${CYN}   proot-distro login ubuntu${RST}"
echo -e "${CYN}   cd hermes-agent && source venv/bin/activate${RST}"
echo -e "${CYN}   hermes${RST}"
echo ""
echo -e "${GRN}💡 Need help? Visit: https://github.com/learn6096-ui/Hermes-Agent-On-Android${RST}"
