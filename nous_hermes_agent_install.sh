#!/data/data/com.termux/files/usr/bin/bash
#
# Nous Hermes Agent Installer for Android (Termux)
# Most robust installer — handles all edge cases
#
# Usage in Termux:
#   curl -fsSL https://raw.githubusercontent.com/learn6096-ui/Hermes-Agent-On-Android/main/nous_hermes_agent_install.sh | bash
#

set -e

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
INNER_SCRIPT="$HOME/.hermes_inner_install.sh"

cat > "$INNER_SCRIPT" << 'INNER_EOF'
#!/bin/bash
# NOTE: Do NOT use set -euo pipefail here.
# - `-u` causes unbound variable errors in proot environments
# - `pipefail` causes curl|gpg pipelines to fail prematurely
# We use explicit error checks instead for reliability.

export DEBIAN_FRONTEND=noninteractive
export TZ=UTC
export LC_ALL=C

echo ""
echo "═══════════════════════════════════════════"
echo "  Running inside Ubuntu proot environment"
echo "═══════════════════════════════════════════"
echo ""

# --- Helper: retry a command up to N times ---
retry() {
    local max_attempts=$1
    shift
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        echo "⚠️  Attempt $attempt/$max_attempts failed, retrying in 3s..."
        sleep 3
        attempt=$((attempt + 1))
    done
    echo "❌ Command failed after $max_attempts attempts: $*"
    return 1
}

# --- Update Ubuntu packages ---
echo "📦 [proot] Updating Ubuntu packages..."
apt-get update -y 2>&1 || {
    echo "⚠️  apt-get update failed, trying to fix sources..."
    # Fix potential sources.list issues in fresh proot
    echo "deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse" > /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse" >> /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse" >> /etc/apt/sources.list
    apt-get update -y 2>&1 || true
}
apt-get upgrade -y -o Dpkg::Options::="--force-confold" 2>&1 || true

# --- Install ca-certificates FIRST (required for HTTPS/GPG operations) ---
echo "📦 [proot] Installing ca-certificates..."
apt-get install -y ca-certificates curl 2>&1 || {
    echo "❌ Failed to install ca-certificates. Cannot proceed."
    exit 1
}

# --- Install core system dependencies (split into groups for better error visibility) ---
echo "📦 [proot] Installing core build tools..."
apt-get install -y -o Dpkg::Options::="--force-confold" \
    git wget build-essential pkg-config \
    libffi-dev libssl-dev 2>&1 || {
    echo "❌ Failed to install core build tools."
    exit 1
}

echo "📦 [proot] Installing additional tools..."
apt-get install -y -o Dpkg::Options::="--force-confold" \
    software-properties-common gpg lsb-release 2>&1 || {
    echo "⚠️  Some additional tools failed to install, continuing..."
}

# nodejs/npm are optional — not required for hermes-agent core
echo "📦 [proot] Installing nodejs (optional)..."
apt-get install -y nodejs npm 2>&1 || {
    echo "⚠️  nodejs/npm not available, skipping (not required for core)."
}

# --- Python 3.13 via deadsnakes PPA ---
echo "🐍 [proot] Setting up Python 3.13 from deadsnakes PPA..."

# Detect Ubuntu codename with robust fallback
CODENAME=""
if command -v lsb_release >/dev/null 2>&1; then
    CODENAME=$(lsb_release -cs 2>/dev/null)
fi
if [ -z "$CODENAME" ] && [ -f /etc/os-release ]; then
    CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
fi
# Fallback if codename not detected or not supported by deadsnakes
if [ -z "$CODENAME" ] || ! echo "$CODENAME" | grep -qE '^(focal|jammy|noble)$'; then
    CODENAME="noble"
fi
echo "   Detected codename: ${CODENAME}"

# Import deadsnakes GPG key (with retry for slow networks)
echo "🔑 [proot] Importing deadsnakes GPG key..."
GPG_OK=false
for attempt in 1 2 3; do
    if curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" -o /tmp/deadsnakes.gpg.asc 2>&1; then
        if gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg /tmp/deadsnakes.gpg.asc 2>&1; then
            GPG_OK=true
            rm -f /tmp/deadsnakes.gpg.asc
            break
        fi
    fi
    echo "   Attempt $attempt/3 failed, retrying..."
    sleep 2
done

if [ "$GPG_OK" = false ]; then
    echo "⚠️  Could not import deadsnakes GPG key, trying without verification..."
    # Create a trusted.gpg.d entry anyway, or skip PPA entirely
fi

# Add the deadsnakes source list
echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/deadsnakes.list
apt-get update -y 2>&1 || {
    echo "⚠️  apt-get update with deadsnakes failed, trying without PPA..."
    rm -f /etc/apt/sources.list.d/deadsnakes.list
    apt-get update -y 2>&1 || true
}

# Try Python 3.13, fall back to system python3 if unavailable
PYTHON_CMD="python3"
if apt-get install -y python3.13 python3.13-venv python3.13-dev 2>&1; then
    PYTHON_CMD="python3.13"
    # Set as default python3
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 2>/dev/null || true
    update-alternatives --set python3 /usr/bin/python3.13 2>/dev/null || true
    # Create python symlink if missing
    if [ ! -f /usr/bin/python ]; then
        ln -sf /usr/bin/python3.13 /usr/bin/python 2>/dev/null || true
    fi
    echo "✅ [proot] Python 3.13 installed successfully"
else
    echo "⚠️  [proot] Python 3.13 not available for ${CODENAME}, using system python3"
    apt-get install -y python3 python3-pip python3-venv python3-dev 2>&1 || {
        echo "❌ Failed to install any Python version. Cannot proceed."
        exit 1
    }
    echo "✅ [proot] System python3 ready: $(python3 --version 2>&1)"
fi

# Verify Python is actually working
if ! $PYTHON_CMD --version 2>&1; then
    echo "❌ Python command '${PYTHON_CMD}' not working. Cannot proceed."
    exit 1
fi

REPO_DIR="$HOME/hermes-agent"

# --- Clone or update repository (with retry) ---
if [ -d "$REPO_DIR/.git" ]; then
    echo "🔄 [proot] Updating existing hermes-agent repository..."
    cd "$REPO_DIR"
    git fetch origin 2>/dev/null || true
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    git reset --hard origin/main 2>/dev/null || git reset --hard origin/master 2>/dev/null || true
else
    echo "📥 [proot] Cloning Hermes Agent repository..."
    rm -rf "$REPO_DIR" 2>/dev/null || true
    if ! retry 3 git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/NousResearch/hermes-agent.git "$REPO_DIR"; then
        echo "❌ Failed to clone repository after 3 attempts."
        echo "   Check your internet connection and try again."
        exit 1
    fi
    cd "$REPO_DIR"
fi

# --- Setup Python venv (with fallback for missing ensurepip) ---
echo "🐍 [proot] Creating virtual environment with ${PYTHON_CMD}..."
if [ -d "venv" ]; then
    rm -rf venv
fi

if ! $PYTHON_CMD -m venv venv 2>&1; then
    echo "⚠️  venv creation failed, trying --without-pip..."
    if ! $PYTHON_CMD -m venv --without-pip venv 2>&1; then
        echo "❌ Failed to create virtual environment."
        exit 1
    fi
    # Manually bootstrap pip
    echo "⬆️  [proot] Bootstrapping pip manually..."
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    venv/bin/python /tmp/get-pip.py 2>&1
    rm -f /tmp/get-pip.py
fi

echo "⬆️  [proot] Upgrading pip, setuptools, wheel..."
venv/bin/pip install --upgrade pip setuptools wheel 2>&1 || {
    echo "⚠️  pip upgrade had issues, continuing with current version..."
}

echo "🔧 [proot] Installing Hermes Agent (this can take 5-10 minutes)..."
# Try full extras first, fall back to base
if ! venv/bin/pip install -e ".[all]" 2>&1; then
    echo "⚠️  Full extras install failed, trying base install..."
    if ! venv/bin/pip install -e "." 2>&1; then
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
echo "  🐍 Python: $($PYTHON_CMD --version 2>&1)"
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
    termux-wake-unlock 2>/dev/null || true
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
