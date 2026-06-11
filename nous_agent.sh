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
echo -e "${GRN}         ☤ HERMES AGENT TERMUX INSTALLER ☤"
echo -e "${CYN}=====================================================${RST}"

export DEBIAN_FRONTEND=noninteractive

# Prevent Android from killing Termux while installing
termux-wake-lock 2>/dev/null || true

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
# NOTE: Do NOT use set -e here. Proot environments have many
# non-critical commands that may fail. We use explicit checks instead.

export DEBIAN_FRONTEND=noninteractive
export TZ=UTC
export LC_ALL=C

echo "📦 [proot] Updating Ubuntu packages..."
apt-get update -y 2>&1 || {
    echo "⚠️  apt-get update failed, trying to fix sources..."
    echo "deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse" > /etc/apt/sources.list
    echo "deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse" >> /etc/apt/sources.list
    apt-get update -y 2>&1 || true
}
apt-get upgrade -y -o Dpkg::Options::="--force-confold" 2>&1 || true

# Install ca-certificates FIRST (needed for HTTPS/GPG)
echo "📦 [proot] Installing ca-certificates..."
apt-get install -y ca-certificates curl 2>&1 || {
    echo "❌ Failed to install ca-certificates."
    exit 1
}

echo "📦 [proot] Installing base dependencies..."
apt-get install -y -o Dpkg::Options::="--force-confold" \
    git wget build-essential pkg-config \
    libffi-dev libssl-dev 2>&1 || {
    echo "❌ Failed to install core build tools."
    exit 1
}

# Install optional tools (non-critical)
apt-get install -y software-properties-common gpg lsb-release 2>&1 || true
apt-get install -y nodejs npm 2>&1 || echo "⚠️  nodejs/npm skipped (optional)."

# --- Python 3.13 via deadsnakes PPA ---
echo "🐍 [proot] Setting up Python 3.13..."

CODENAME=""
if command -v lsb_release >/dev/null 2>&1; then
    CODENAME=$(lsb_release -cs 2>/dev/null)
fi
if [ -z "$CODENAME" ] && [ -f /etc/os-release ]; then
    CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
fi
if [ -z "$CODENAME" ] || ! echo "$CODENAME" | grep -qE '^(focal|jammy|noble)$'; then
    CODENAME="noble"
fi
echo "   Detected codename: ${CODENAME}"

# Import deadsnakes GPG key (with retry)
GPG_OK=false
for attempt in 1 2 3; do
    if curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" -o /tmp/deadsnakes.gpg.asc 2>&1; then
        if gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg /tmp/deadsnakes.gpg.asc 2>&1; then
            GPG_OK=true
            rm -f /tmp/deadsnakes.gpg.asc
            break
        fi
    fi
    echo "   GPG import attempt $attempt/3 failed, retrying..."
    sleep 2
done

echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/deadsnakes.list
apt-get update -y 2>&1 || {
    echo "⚠️  apt-get update with deadsnakes failed, removing PPA..."
    rm -f /etc/apt/sources.list.d/deadsnakes.list
    apt-get update -y 2>&1 || true
}

PYTHON_CMD="python3"
if apt-get install -y python3.13 python3.13-venv python3.13-dev 2>&1; then
    PYTHON_CMD="python3.13"
    echo "✅ [proot] Python 3.13 installed"
else
    echo "⚠️ [proot] Python 3.13 not available, using system python3"
    apt-get install -y python3 python3-pip python3-venv python3-dev 2>&1 || {
        echo "❌ Failed to install Python."
        exit 1
    }
fi

if ! $PYTHON_CMD --version 2>&1; then
    echo "❌ Python not working."
    exit 1
fi

echo "📥 [proot] Cloning Hermes Agent..."
if [ ! -d "$HOME/hermes-agent/.git" ]; then
    rm -rf "$HOME/hermes-agent" 2>/dev/null || true
    CLONE_OK=false
    for attempt in 1 2 3; do
        if git clone --depth 1 --recurse-submodules --shallow-submodules \
            https://github.com/NousResearch/hermes-agent.git "$HOME/hermes-agent" 2>&1; then
            CLONE_OK=true
            break
        fi
        echo "   Clone attempt $attempt/3 failed, retrying..."
        rm -rf "$HOME/hermes-agent" 2>/dev/null || true
        sleep 3
    done
    if [ "$CLONE_OK" = false ]; then
        echo "❌ Failed to clone repository."
        exit 1
    fi
else
    echo "   Repository already exists, updating..."
    cd "$HOME/hermes-agent"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
fi

cd "$HOME/hermes-agent"

# Create venv (with fallback for missing ensurepip)
echo "🐍 [proot] Creating virtual environment..."
rm -rf venv 2>/dev/null || true
if ! $PYTHON_CMD -m venv venv 2>&1; then
    echo "⚠️  venv failed, trying --without-pip..."
    if ! $PYTHON_CMD -m venv --without-pip venv 2>&1; then
        echo "❌ Failed to create virtual environment."
        exit 1
    fi
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    venv/bin/python /tmp/get-pip.py 2>&1
    rm -f /tmp/get-pip.py
fi

echo "⬆️  [proot] Upgrading pip..."
venv/bin/pip install --upgrade pip setuptools wheel 2>&1 || true

echo "🔧 [proot] Installing Hermes Agent (this takes 5-10 minutes)..."
if ! venv/bin/pip install -e ".[all]" 2>&1; then
    echo "⚠️  Full extras failed, trying base install..."
    if ! venv/bin/pip install -e "." 2>&1; then
        echo "❌ Failed to install Hermes Agent"
        exit 1
    fi
fi

echo ""
echo "✅ Hermes Agent installed inside Ubuntu!"
echo "🐍 Python: $($PYTHON_CMD --version 2>&1)"
INNER_EOF

chmod +x "$INNER_SCRIPT"

# --- Step 5: Run the inner script inside proot ---
echo -e "${YLW}[5/5] Running installation inside Ubuntu proot...${RST}"
echo -e "${YLW}   (This may take 5-15 minutes depending on your connection)${RST}"
echo ""

if ! proot-distro login ubuntu --shared-tmp -- /bin/bash "$INNER_SCRIPT"; then
    echo -e "${RED}❌ Installation inside Ubuntu failed${RST}"
    echo -e "${YLW}💡 Try running again, or check your internet connection${RST}"
    rm -f "$INNER_SCRIPT" 2>/dev/null
    termux-wake-unlock 2>/dev/null || true
    exit 1
fi

rm -f "$INNER_SCRIPT" 2>/dev/null

# Release wake lock
termux-wake-unlock 2>/dev/null || true

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