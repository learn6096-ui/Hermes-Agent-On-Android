#!/bin/bash

# Hermes Agent - One-line installer for Termux (Android)
# Usage: curl -fsSL https://your-raw-url/hermes_install.sh | bash

set -e

# Colors
GRN='\033[0;32m'
CYN='\033[0;36m'
YEL='\033[0;33m'
RST='\033[0m'

echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}                   learning"
echo -e "${CYN}=====================================================${RST}"

echo -e "${CYN}=====================================================${RST}"
echo -e "${GRN}        🚀 Installing Hermes Agent on Termux..."
echo -e "${CYN}=====================================================${RST}"

echo "📦 Repository: https://github.com/learn6096-ui/Hermes-Agent-On-Android"

# Fix apt prompts
export DEBIAN_FRONTEND=noninteractive

# Update packages
echo -e "${GRN}📦 Updating package lists...${RST}"
pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || pkg update -y

echo -e "${GRN}📦 Upgrading packages...${RST}"
pkg upgrade -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || pkg upgrade -y

# Install dependencies
echo -e "${GRN}📦 Installing dependencies...${RST}"
pkg install -y git python clang rust make pkg-config libffi openssl nodejs ripgrep ffmpeg

# PATCH: Fix psutil compatibility with Python 3.13 on Termux
# This removes the unsupported compiler flag -fno-openmp-implicit-rpath
echo -e "${GRN}🔧 Patching Python sysconfig for psutil compatibility...${RST}"
_file="$(find $PREFIX/lib/python3.* -name "_sysconfigdata*.py" 2>/dev/null | head -1)"
if [ -f "$_file" ]; then
    cp "$_file" "$_file.backup"
    sed -i 's|-fno-openmp-implicit-rpath||g' "$_file"
    rm -rf $PREFIX/lib/python3.*/__pycache__
    echo -e "${GRN}✅ Python patched successfully${RST}"
else
    echo -e "${YEL}⚠️ Python sysconfig file not found, continuing...${RST}"
fi

# Clone repository
echo -e "${GRN}📥 Cloning Hermes Agent...${RST}"
git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git || { echo -e "${YEL}❌ Git clone failed. Check your internet connection.${RST}"; exit 1; }

# Navigate to directory
cd hermes-agent

# Setup Python virtual environment
echo -e "${GRN}🐍 Setting up Python virtual environment...${RST}"
python -m venv venv
source venv/bin/activate

# Set Android API level
export ANDROID_API_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null || echo 24)"

# Upgrade pip tools
echo -e "${GRN}⬆️ Upgrading pip, setuptools, wheel...${RST}"
python -m pip install --upgrade pip setuptools wheel

# Install Hermes with Termux support
echo -e "${GRN}🔧 Installing Hermes Agent...${RST}"
python -m pip install -e '.[termux]' -c constraints-termux.txt

# Create global symlink
ln -sf "$PWD/venv/bin/hermes" "$PREFIX/bin/hermes"

echo "✅ Hermes Agent installed successfully!"
echo "🔥 Run 'hermes' or 'hermes setup' to start using it"
echo "📖 Type 'hermes --help' for more options"
echo ""
echo "💡 Need help? Visit: https://github.com/learn6096-ui/Hermes-Agent-On-Android"
echo ""
echo "🌐 Run 'hermes gateway' to run deply it"

